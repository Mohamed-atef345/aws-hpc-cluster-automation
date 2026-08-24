output "instance_id" {
  value = aws_instance.main.id
}

output "instance_arn" {
  value = aws_instance.main.arn
}

output "private_ip" {
  value = aws_instance.main.private_ip
}

output "private_dns" {
  value = aws_instance.main.private_dns
}

output "node_name" {
  value = var.node_name
}

output "node_role" {
  value = var.node_role
}

output "scratch_volume_id" {
  value = try(aws_ebs_volume.scratch[0].id, null)
}