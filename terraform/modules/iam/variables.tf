variable "name_prefix" {
  description = "Prefix used for IAM role and instance-profile names"
  type        = string
}

variable "freeipa_secret_arns" {
  description = "Secrets Manager ARNs readable by the FreeIPA instance"
  type        = list(string)
  default     = []
}

variable "controller_secret_arns" {
  description = "Secrets Manager ARNs readable by the Slurm controller"
  type        = list(string)
  default     = []
}
