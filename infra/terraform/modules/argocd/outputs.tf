output "argocd_namespace" {
  description = "Kubernetes namespace where ArgoCD is installed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}
