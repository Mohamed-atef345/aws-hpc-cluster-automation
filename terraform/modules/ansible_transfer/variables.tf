variable "project_name" {
  description = "Project name used to build the Ansible transfer bucket name"
  type        = string
}

variable "aws_region" {
  description = "AWS region in which the Ansible transfer bucket is created"
  type        = string
}

variable "object_expiration_days" {
  description = "Number of days after which abandoned Ansible transfer objects expire"
  type        = number
  default     = 1

  validation {
    condition     = var.object_expiration_days >= 1
    error_message = "object_expiration_days must be at least 1."
  }
}
