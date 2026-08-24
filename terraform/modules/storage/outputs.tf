output "file_system_id" {
  value = aws_efs_file_system.main.id
}

output "file_system_arn" {
  value = aws_efs_file_system.main.arn
}

output "mount_target_id" {
  value = aws_efs_mount_target.mount_target.id
}

output "home_access_point_id" {
  value = aws_efs_access_point.home.id
}

output "shared_access_point_id" {
  value = aws_efs_access_point.shared.id
}

output "dns_name" {
  value = aws_efs_file_system.main.dns_name
}