locals {
  common_tags = {
    Project   = var.name_prefix
    Owner     = var.owner
    ManagedBy = "terraform"
    Scope     = "identity"
  }
}
