variable "node_name" {
  type = string
}

variable "node_role" {
  type = string
  validation {
    condition     = contains(["freeipa", "controller", "login", "compute"], var.node_role)
    error_message = "node_role must be one of: freeipa, controller, login, compute."
  }
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "private_ip" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "iam_instance_profile_name" {
  type = string
}

variable "root_volume_type" {
  type = string
}

variable "scratch_volume_type" {
  type = string
}

variable "root_volume_size" {
  type = number
}

variable "scratch_volume_size" {
  type    = number
  default = null
}

variable "user_data" {
  type    = string
  default = null
}

variable "common_tags" {
  type = map(string)
}
