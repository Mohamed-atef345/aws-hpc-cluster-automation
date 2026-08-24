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