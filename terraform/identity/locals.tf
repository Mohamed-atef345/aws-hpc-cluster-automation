locals {
  common_tags = {
    Project   = var.name_prefix
    Owner     = var.owner
    ManagedBy = "terraform"
    Scope     = "identity"
  }

  freeipa_secret_arns = [
    "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}/freeipa/*",
  ]

  controller_secret_arns = [
    "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}/slurm/*",
  ]
}
