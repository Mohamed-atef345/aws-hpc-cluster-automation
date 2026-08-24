locals {
  security_groups = {
    cluster_client = {
      description = "Shared security group for cluster clients"
    }
    freeipa = {
      description = "Security group for the FreeIPA server"
    }
    controller = {
      description = "Security group for the Slurm controller"
    }
    login = {
      description = "Security group for the login node"
    }
    compute = {
      description = "Security group for Slurm compute nodes"
    }
    efs = {
      description = "Security group for the EFS mount target"
    }
  }

  ingress_rules = {
    freeipa_dns_tcp = {
      description = "DNS over TCP from cluster clients"
      target_sg   = "freeipa"
      source_sg   = "cluster_client"
      protocol    = "tcp"
      from_port   = 53
      to_port     = 53
    }
    freeipa_dns_udp = {
      description = "DNS over UDP from cluster clients"
      target_sg   = "freeipa"
      source_sg   = "cluster_client"
      protocol    = "udp"
      from_port   = 53
      to_port     = 53
    }
    freeipa_http = {
      description = "FreeIPA HTTP from cluster clients"
      target_sg   = "freeipa"
      source_sg   = "cluster_client"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
    }
    freeipa_kerberos_tcp = {
      description = "Kerberos over TCP from cluster clients"
      target_sg   = "freeipa"
      source_sg   = "cluster_client"
      protocol    = "tcp"
      from_port   = 88
      to_port     = 88
    }
    freeipa_kerberos_udp = {
      description = "Kerberos over UDP from cluster clients"
      target_sg   = "freeipa"
      source_sg   = "cluster_client"
      protocol    = "udp"
      from_port   = 88
      to_port     = 88
    }
    freeipa_ldap = {
      description = "LDAP from cluster clients"
      target_sg   = "freeipa"
      source_sg   = "cluster_client"
      protocol    = "tcp"
      from_port   = 389
      to_port     = 389
    }
    freeipa_https = {
      description = "FreeIPA HTTPS from cluster clients"
      target_sg   = "freeipa"
      source_sg   = "cluster_client"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
    }
    freeipa_kpasswd_tcp = {
      description = "Kerberos password service over TCP"
      target_sg   = "freeipa"
      source_sg   = "cluster_client"
      protocol    = "tcp"
      from_port   = 464
      to_port     = 464
    }
    freeipa_kpasswd_udp = {
      description = "Kerberos password service over UDP"
      target_sg   = "freeipa"
      source_sg   = "cluster_client"
      protocol    = "udp"
      from_port   = 464
      to_port     = 464
    }
    freeipa_ldaps = {
      description = "LDAPS from cluster clients"
      target_sg   = "freeipa"
      source_sg   = "cluster_client"
      protocol    = "tcp"
      from_port   = 636
      to_port     = 636
    }
    slurm_controller = {
      description = "Slurm controller from cluster clients"
      target_sg   = "controller"
      source_sg   = "cluster_client"
      protocol    = "tcp"
      from_port   = 6817
      to_port     = 6817
    }
    slurm_compute = {
      description = "Slurm daemon traffic from controller"
      target_sg   = "compute"
      source_sg   = "controller"
      protocol    = "tcp"
      from_port   = 6818
      to_port     = 6818
    }
    efs_nfs = {
      description = "NFS from cluster clients"
      target_sg   = "efs"
      source_sg   = "cluster_client"
      protocol    = "tcp"
      from_port   = 2049
      to_port     = 2049
    }
  }
}
