locals {
  secrets = {
    freeipa_credentials = {
      name        = "${var.name_prefix}/freeipa/credentials"
      description = "FreeIPA bootstrap administrator and Directory Manager credentials"
      role        = "freeipa"
    }
    munge_key = {
      name        = "${var.name_prefix}/slurm/munge"
      description = "Shared MUNGE authentication key for Slurm nodes"
      role        = "slurm"
    }
    slurmdbd_credentials = {
      name        = "${var.name_prefix}/slurm/database"
      description = "SlurmDBD database credentials"
      role        = "controller"
    }
  }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = local.secrets

  name                    = each.value.name
  description             = each.value.description
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.common_tags, {
    Name = each.value.name
    Role = each.value.role
  })
}
