# ──────────────────────────────────────────────────────────────────────────────
# Namespace
# ──────────────────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "project"                      = var.project_name
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Helm Release – ArgoCD
# ──────────────────────────────────────────────────────────────────────────────
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.4.4"

  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# ──────────────────────────────────────────────────────────────────────────────
# Ingress – ArgoCD Server via ALB
# ──────────────────────────────────────────────────────────────────────────────
resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd-server-ingress"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                    = "alb"
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/backend-protocol"     = "HTTPS"
      "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\":80}]"
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/healthz"
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTPS"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}
