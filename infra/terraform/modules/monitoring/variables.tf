variable "project_name" {
  description = "Project name used as a prefix for all resources"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}
