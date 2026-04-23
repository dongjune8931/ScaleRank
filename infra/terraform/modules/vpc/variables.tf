variable "project_name" {
  description = "Project name used as a prefix for all resources"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name for subnet discovery tags"
  type        = string
}
