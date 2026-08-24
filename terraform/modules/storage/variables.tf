variable "project_name" {
  type = string
}

variable "availability_zone" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "encrypted" {
  type = bool
}

variable "efs_security_group_id" {
  type = string
}

variable "performance_mode" {
  type = string
}

variable "throughput_mode" {
  type = string
}