locals {
  common_tags = {
    Project   = var.project_name
    Owner     = var.owner
    ManagedBy = "terraform"
  }

  freeipa_domain = lower(var.freeipa_domain)
  freeipa_realm  = upper(var.freeipa_domain)

  fixed_nodes = {
    ipa01 = {
      role                = "freeipa"
      instance_type       = var.freeipa_instance_type
      private_ip          = cidrhost(var.private_subnet_cidr, 10)
      scratch_volume_size = null
    }

    ctl01 = {
      role                = "controller"
      instance_type       = var.controller_instance_type
      private_ip          = cidrhost(var.private_subnet_cidr, 20)
      scratch_volume_size = null
    }

    login01 = {
      role                = "login"
      instance_type       = var.login_instance_type
      private_ip          = cidrhost(var.private_subnet_cidr, 30)
      scratch_volume_size = null
    }
  }

  compute_nodes = {
    for index in range(var.compute_count) :
    format("compute%02d", index + 1) => {
      role                = "compute"
      instance_type       = var.compute_instance_type
      private_ip          = cidrhost(var.private_subnet_cidr, 100 + index)
      scratch_volume_size = var.compute_scratch_volume_size
    }
  }

  nodes = merge(local.fixed_nodes, local.compute_nodes)
}
