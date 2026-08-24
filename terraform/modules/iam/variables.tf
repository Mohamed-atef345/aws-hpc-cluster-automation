variable "name_prefix" {
  description = "Prefix used for IAM role and instance-profile names"
  type        = string
}

variable "secret_arns_by_role" {
  description = "Secrets Manager ARNs readable by each EC2 node role"
  type        = map(list(string))
  default     = {}

  validation {
    condition = alltrue([
      for role in keys(var.secret_arns_by_role) :
      contains(["freeipa", "controller", "login", "compute"], role)
    ])
    error_message = "secret_arns_by_role keys must be freeipa, controller, login, or compute."
  }
}
