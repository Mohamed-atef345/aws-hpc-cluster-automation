variable "project_name" {
  description = "Project name used for resource names and tags"
  type        = string
  default     = "HPCSlurmFreeIPA"
}

variable "owner" {
  description = "Owner value applied to AWS resource tags"
  type        = string
  default     = "mohamed-atef"
}

variable "aws_region" {
  description = "AWS region in which to deploy the cluster"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Single Availability Zone used by the lab cluster"
  type        = string
  default     = "us-east-1a"
}

variable "vpc_cidr" {
  description = "CIDR block for the HPC VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the NAT gateway public subnet"
  type        = string
  default     = "10.20.0.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for all HPC cluster nodes"
  type        = string
  default     = "10.20.10.0/24"
}

variable "freeipa_instance_type" {
  description = "EC2 instance type for the FreeIPA server"
  type        = string
  default     = "t3.medium"
}

variable "controller_instance_type" {
  description = "EC2 instance type for the Slurm controller"
  type        = string
  default     = "t3.medium"
}

variable "login_instance_type" {
  description = "EC2 instance type for the login node"
  type        = string
  default     = "t3.small"
}

variable "compute_instance_type" {
  description = "EC2 instance type for Slurm compute nodes"
  type        = string
  default     = "t3.small"
}

variable "compute_count" {
  description = "Number of Slurm compute nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.compute_count >= 1 && var.compute_count <= 2
    error_message = "compute_count must be either 1 or 2."
  }
}

variable "root_volume_type" {
  description = "EBS type used for EC2 root volumes"
  type        = string
  default     = "gp3"
}

variable "root_volume_size" {
  description = "EC2 root-volume size in GiB"
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 10
    error_message = "root_volume_size must be at least 10 GiB."
  }
}

variable "freeipa_domain" {
  description = "Private DNS domain managed by FreeIPA"
  type        = string
  default     = "hpc.test"
}

variable "enable_dns_hostnames" {
  type    = bool
  default = true
}

variable "enable_dns_support" {
  type    = bool
  default = true
}

variable "performance_mode" {
  type    = string
  default = "generalPurpose"
}

variable "throughput_mode" {
  type    = string
  default = "bursting"
}

variable "encrypted" {
  type    = bool
  default = true
}

variable "ami_id" {
  description = "Pinned Rocky Linux 9 AMI ID"
  type        = string
  default     = "ami-07f1ef003bc5de2b1"
}

variable "compute_scratch_volume_size" {
  description = "Scratch volume size for each compute node"
  type        = number
  default     = 20
}

variable "scratch_volume_type" {
  description = "EBS volume type for compute scratch storage"
  type        = string
  default     = "gp3"
}
