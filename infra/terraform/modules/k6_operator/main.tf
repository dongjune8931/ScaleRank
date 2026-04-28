# ──────────────────────────────────────────────────────────────────────────────
# Namespace – pre-created with Helm ownership metadata to avoid conflicts
# ──────────────────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "k6_operator" {
  metadata {
    name = "k6-operator"
    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }
    annotations = {
      "meta.helm.sh/release-name"      = "k6-operator"
      "meta.helm.sh/release-namespace" = "k6-operator"
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
  timeout    = 600

  set {
    name  = "authProxy.image.registry"
    value = "registry.k8s.io"
  }

  depends_on = [kubernetes_namespace.k6_operator]
}
