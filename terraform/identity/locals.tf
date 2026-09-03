locals {
  common_tags = {
    Project   = var.name_prefix
    Owner     = var.owner
    ManagedBy = "terraform"
    Scope     = "identity"
  }

  ansible_transfer_bucket_name = lower(
    "${replace(var.name_prefix, "_", "-")}-ansible-transfer-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  )
  ansible_transfer_bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${local.ansible_transfer_bucket_name}"
}
