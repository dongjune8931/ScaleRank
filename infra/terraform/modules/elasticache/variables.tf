variable "project_name" {
  description = "Project name used as a prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ElastiCache cluster will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ElastiCache subnet group"
  type        = list(string)
}

variable "node_security_group_id" {
  description = "EKS node security group ID allowed to access Redis"
  type        = string
}
