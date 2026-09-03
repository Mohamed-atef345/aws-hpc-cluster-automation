output "github_terraform_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions through OIDC"
  value       = aws_iam_role.github_terraform.arn
}

output "github_secrets_bootstrap_role_arn" {
  description = "IAM role ARN assumed by the one-time GitHub secret bootstrap workflow"
  value       = aws_iam_role.github_secrets_bootstrap.arn
}

output "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN"
  value       = data.aws_iam_openid_connect_provider.github.arn
}

output "instance_profile_names" {
  description = "EC2 instance-profile names keyed by cluster role"
  value       = module.iam.instance_profile_names
}

output "instance_role_arns" {
  description = "EC2 IAM role ARNs keyed by cluster role"
  value       = module.iam.instance_role_arns
}

output "secret_arns" {
  description = "Secrets Manager ARNs keyed by secret purpose"
  value       = module.secrets.secret_arns
}

output "secret_names" {
  description = "Secrets Manager names keyed by secret purpose"
  value       = module.secrets.secret_names
}
