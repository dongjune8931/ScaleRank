variable "project_name" {
  description = "Project name used as a prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the bastion host will be created"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for the bastion host"
  type        = string
}

variable "key_pair_name" {
  description = "Name of existing EC2 key pair for SSH access"
  type        = string
}
