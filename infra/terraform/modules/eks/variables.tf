variable "project_name" {
  description = "Project name used as a prefix for all resources"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS node groups (single AZ)"
  type        = list(string)
}

variable "cluster_subnet_ids" {
  description = "List of subnet IDs (2 AZs) for EKS control plane ENI placement"
  type        = list(string)
}
