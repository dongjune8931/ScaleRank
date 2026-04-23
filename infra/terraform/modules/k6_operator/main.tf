# ──────────────────────────────────────────────────────────────────────────────
# Namespace
# ──────────────────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "k6_operator" {
  metadata {
    name = "k6-operator"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "project"                      = var.project_name
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Helm Release – k6 Operator
# ──────────────────────────────────────────────────────────────────────────────
resource "helm_release" "k6_operator" {
  name       = "k6-operator"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "k6-operator"
  namespace  = kubernetes_namespace.k6_operator.metadata[0].name
  version    = "3.9.0"

  depends_on = [kubernetes_namespace.k6_operator]
}
