# ──────────────────────────────────────────────────────────────────────────────
# Namespace
# ──────────────────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "project"                      = var.project_name
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# 1. kube-prometheus-stack (Prometheus + Grafana + AlertManager)
# ──────────────────────────────────────────────────────────────────────────────
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "61.3.2"

  values = [
    yamlencode({
      grafana = {
        adminPassword = var.grafana_admin_password
        persistence = {
          enabled = false
        }
      }
      prometheus = {
        prometheusSpec = {
          retention = "7d"
          storageSpec = {}
          remoteWriteReceivers = {
            enabled = true
          }
        }
      }
      alertmanager = {
        alertmanagerSpec = {
          storage = {}
        }
      }
      prometheusOperator = {
        admissionWebhooks = {
          enabled = true
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# ──────────────────────────────────────────────────────────────────────────────
# 2. OpenTelemetry Collector
# ──────────────────────────────────────────────────────────────────────────────
resource "helm_release" "opentelemetry_collector" {
  name       = "opentelemetry-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "0.100.0"

  values = [
    yamlencode({
      mode = "deployment"
      config = {
        receivers = {
          otlp = {
            protocols = {
              grpc = {
                endpoint = "0.0.0.0:4317"
              }
              http = {
                endpoint = "0.0.0.0:4318"
              }
            }
          }
        }
        exporters = {
          prometheus = {
            endpoint = "0.0.0.0:8889"
          }
          otlp = {
            endpoint = "jaeger-collector.monitoring.svc.cluster.local:14250"
            tls = {
              insecure = true
            }
          }
        }
        service = {
          pipelines = {
            traces = {
              receivers  = ["otlp"]
              processors = []
              exporters  = ["otlp"]
            }
            metrics = {
              receivers  = ["otlp"]
              processors = []
              exporters  = ["prometheus"]
            }
          }
        }
      }
      ports = {
        otlp = {
          enabled          = true
          containerPort    = 4317
          servicePort      = 4317
          protocol         = "TCP"
        }
        otlp-http = {
          enabled          = true
          containerPort    = 4318
          servicePort      = 4318
          protocol         = "TCP"
        }
        prometheus = {
          enabled          = true
          containerPort    = 8889
          servicePort      = 8889
          protocol         = "TCP"
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# ──────────────────────────────────────────────────────────────────────────────
# 3. Jaeger (all-in-one)
# ──────────────────────────────────────────────────────────────────────────────
resource "helm_release" "jaeger" {
  name       = "jaeger"
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "3.3.1"

  values = [
    yamlencode({
      provisionDataStore = {
        cassandra = false
        elasticsearch = false
      }
      allInOne = {
        enabled = true
        ingress = {
          enabled = true
          annotations = {
            "kubernetes.io/ingress.class"               = "alb"
            "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"     = "ip"
            "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\":80}]"
          }
          hosts = [""]
        }
      }
      storage = {
        type = "memory"
      }
      agent = {
        enabled = false
      }
      collector = {
        enabled = false
      }
      query = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}
