variable "project_name" {
  description = "Project name used as a prefix for all resources"
  type        = string
  default     = "scalerank"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "scalerank-eks"
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "scalerank"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "bastion_key_pair_name" {
  description = "Name of existing EC2 key pair for bastion host SSH access"
  type        = string
}
