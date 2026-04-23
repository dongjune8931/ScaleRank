output "grafana_namespace" {
  description = "Kubernetes namespace where monitoring stack is installed"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}
