output "secret_arns" {
  description = "Secrets Manager ARNs keyed by secret purpose"
  value = {
    for name, secret in aws_secretsmanager_secret.this :
    name => secret.arn
  }
}

output "secret_names" {
  description = "Secrets Manager names keyed by secret purpose"
  value = {
    for name, secret in aws_secretsmanager_secret.this :
    name => secret.name
  }
}
