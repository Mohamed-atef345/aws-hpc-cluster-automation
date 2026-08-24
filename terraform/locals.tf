locals {

  common_tags = {
    Project   = var.project_name
    Owner     = var.owner
    ManagedBy = "terraform"
  }

  freeipa_domain = lower(var.freeipa_domain)
  freeipa_realm  = upper(var.freeipa_domain)

  node_names = {
    freeipa    = "ipa01"
    controller = "ctl01"
    login      = "login01"
  }

  private_ips = {
    freeipa    = "10.20.10.10"
    controller = "10.20.10.20"
    login      = "10.20.10.30"
  }
}
