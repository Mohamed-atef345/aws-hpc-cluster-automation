output "instance_profile_names" {
  description = "EC2 instance-profile names keyed by node role"

  value = {
    for role, profile in aws_iam_instance_profile.instance :
    role => profile.name
  }
}

output "instance_profile_arns" {
  description = "EC2 instance-profile ARNs keyed by node role"

  value = {
    for role, profile in aws_iam_instance_profile.instance :
    role => profile.arn
  }
}

output "instance_role_names" {
  description = "EC2 IAM role names keyed by node role"

  value = {
    for role, instance_role in aws_iam_role.instance :
    role => instance_role.name
  }
}

output "instance_role_arns" {
  description = "EC2 IAM role ARNs keyed by node role"

  value = {
    for role, instance_role in aws_iam_role.instance :
    role => instance_role.arn
  }
}
