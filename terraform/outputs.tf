output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_id" {
  value = module.network.private_subnet_id
}

output "public_subnet_id" {
  value = module.network.public_subnet_id
}

output "nat_gateway_id" {
  value = module.network.nat_gateway_id
}

output "efs_file_system_id" {
  value = module.storage.file_system_id
}

output "efs_dns_name" {
  value = module.storage.dns_name
}

output "efs_home_access_point_id" {
  value = module.storage.home_access_point_id
}

output "efs_shared_access_point_id" {
  value = module.storage.shared_access_point_id
}

output "node_instance_ids" {
  value = {
    for name, node in module.ec2_nodes :
    name => node.instance_id
  }
}

output "node_private_ips" {
  value = {
    for name, node in module.ec2_nodes :
    name => node.private_ip
  }
}

output "node_roles" {
  value = {
    for name, node in module.ec2_nodes :
    name => node.node_role
  }
}