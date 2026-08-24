output "security_group_ids" {
  value = { for k, sg in aws_security_group.this : k => sg.id }
}

output "cluster_client_security_group_id" {
  value = aws_security_group.this["cluster_client"].id
}

output "freeipa_security_group_id" {
  value = aws_security_group.this["freeipa"].id
}

output "controller_security_group_id" {
  value = aws_security_group.this["controller"].id
}

output "login_security_group_id" {
  value = aws_security_group.this["login"].id
}

output "compute_security_group_id" {
  value = aws_security_group.this["compute"].id
}

output "efs_security_group_id" {
  value = aws_security_group.this["efs"].id
}
