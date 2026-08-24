variable "aws_region" {
  description = "AWS region used by the project"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix used for project IAM resources"
  type        = string
  default     = "HPCSlurmFreeIPA"
}

variable "owner" {
  description = "Owner tag applied to identity resources"
  type        = string
  default     = "mohamed-atef"
}

variable "github_oidc_subject" {
  description = "Exact GitHub Actions OIDC sub claim allowed to deploy"
  type        = string

  validation {
    condition = (
      startswith(var.github_oidc_subject, "repo:") &&
      !strcontains(var.github_oidc_subject, "*") &&
      !strcontains(var.github_oidc_subject, "?")
    )
    error_message = "github_oidc_subject must be an exact repo subject and cannot contain wildcards"
  }
}

variable "state_bucket_name" {
  description = "S3 bucket containing the main Terraform state"
  type        = string
  default     = "terraform-backend-bucket-017777088168-us-east-1-an"
}

variable "state_key" {
  description = "S3 key containing the main Terraform state"
  type        = string
  default     = "slurm-cluster-freeipa/dev/terraform.tfstate"
}

variable "identity_state_key" {
  description = "S3 key containing the persistent identity Terraform state"
  type        = string
  default     = "slurm-cluster-freeipa/identity/terraform.tfstate"
}
