variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}


variable "srun_port_min" {
  description = "Beginning of the optional Slurm srun port range"
  type        = number
  default     = 60001
}

variable "srun_port_max" {
  description = "End of the optional Slurm srun port range"
  type        = number
  default     = 60010
}