terraform {
  required_providers {
    kubernetes = {
      source                = "hashicorp/kubernetes"
      version               = "~> 2.24"
      configuration_aliases = [kubernetes]
    }
    helm = {
      source                = "hashicorp/helm"
      version               = "~> 2.12"
      configuration_aliases = [helm]
    }
  }
}

resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = var.chart_version
  namespace  = var.namespace
  timeout    = 600

  values = [
    yamlencode({
      tempo = {
        reportingEnabled = false
        retention        = var.retention

        resources = {
          requests = {
            cpu    = var.cpu_request
            memory = var.memory_request
          }
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
        }

        receivers = {
          otlp = {
            protocols = {
              grpc = { endpoint = "0.0.0.0:4317" }
              http = { endpoint = "0.0.0.0:4318" }
            }
          }
        }
      }

      persistence = {
        enabled          = true
        storageClassName = var.storage_class
        size             = var.storage_size
      }
    })
  ]
}

resource "kubernetes_service" "otlp_http" {
  metadata {
    name      = "tempo-otlp-http"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "tempo"
      "app.kubernetes.io/instance" = "tempo"
    }
  }

  spec {
    type = "NodePort"

    selector = {
      "app.kubernetes.io/name"     = "tempo"
      "app.kubernetes.io/instance" = "tempo"
    }

    port {
      name        = "otlp-http"
      port        = 4318
      target_port = 4318
      node_port   = var.otlp_http_node_port
      protocol    = "TCP"
    }
  }

  depends_on = [helm_release.tempo]
}

resource "kubernetes_config_map" "grafana_datasource" {
  metadata {
    name      = "grafana-datasource-tempo"
    namespace = var.namespace
    labels    = { grafana_datasource = "1" }
  }

  data = {
    "tempo-datasource.yaml" = yamlencode({
      apiVersion = 1
      datasources = [{
        name      = "Tempo"
        uid       = "tempo"
        type      = "tempo"
        access    = "proxy"
        url       = "http://tempo.${var.namespace}.svc:3200"
        isDefault = false
        editable  = false
        jsonData = {
          nodeGraph = { enabled = true }
          search    = { hide = false }
          tracesToMetrics = {
            datasourceUid = var.prometheus_datasource_uid
          }
        }
      }]
    })
  }
}
