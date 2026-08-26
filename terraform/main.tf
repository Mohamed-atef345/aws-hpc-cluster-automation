data "terraform_remote_state" "identity" {
  backend = "s3"

  config = {
    bucket = "terraform-backend-bucket-017777088168-us-east-1-an"
    key    = "slurm-cluster-freeipa/identity/terraform.tfstate"
    region = var.aws_region
  }
}

data "aws_ami" "rocky" {
  owners = ["792107900819"]

  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
}

module "network" {
  source = "./modules/network"

  project_name         = local.common_tags.Project
  vpc_cidr             = var.vpc_cidr
  availability_zone    = var.availability_zone
  private_subnet_cidr  = var.private_subnet_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
}


module "security" {
  source = "./modules/security"

  project_name = local.common_tags.Project
  vpc_id       = module.network.vpc_id
}


module "storage" {
  source = "./modules/storage"

  project_name          = local.common_tags.Project
  availability_zone     = var.availability_zone
  private_subnet_id     = module.network.private_subnet_id
  efs_security_group_id = module.security.efs_security_group_id
  encrypted             = var.encrypted
  performance_mode      = var.performance_mode
  throughput_mode       = var.throughput_mode
}


module "ansible_transfer" {
  source = "./modules/ansible_transfer"

  project_name = local.common_tags.Project
  aws_region   = var.aws_region
}


module "ec2_nodes" {
  source   = "./modules/ec2_node"
  for_each = local.nodes

  node_name           = each.key
  node_role           = each.value.role
  ami_id              = data.aws_ami.rocky.id
  instance_type       = each.value.instance_type
  scratch_volume_type = var.scratch_volume_type

  subnet_id  = module.network.private_subnet_id
  private_ip = each.value.private_ip

  security_group_ids = [
    module.security.cluster_client_security_group_id,
    module.security.security_group_ids[each.value.role],
  ]

  iam_instance_profile_name = data.terraform_remote_state.identity.outputs.instance_profile_names[each.value.role]

  root_volume_type    = var.root_volume_type
  root_volume_size    = var.root_volume_size
  scratch_volume_size = each.value.scratch_volume_size

  user_data = templatefile(
    "${path.module}/modules/ec2_node/scripts/bootstrap.sh.tftpl",
    {
      aws_region = var.aws_region
    }
  )

  common_tags = local.common_tags

  depends_on = [module.network]
}
