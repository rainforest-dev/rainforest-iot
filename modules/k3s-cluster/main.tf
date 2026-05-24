terraform {
  required_providers {
    kubernetes = {
      source                = "hashicorp/kubernetes"
      version               = "~> 2.24"
      configuration_aliases = [kubernetes]
    }
  }
}

# Create namespace for monitoring stack
resource "kubernetes_namespace" "monitoring" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name = "monitoring"

    labels = {
      name                        = "monitoring"
      "app.kubernetes.io/name"    = "monitoring"
      "app.kubernetes.io/part-of" = var.cluster_name
    }
  }
}

# Create namespace for ingress
resource "kubernetes_namespace" "ingress" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name = "ingress-system"

    labels = {
      name                        = "ingress-system"
      "app.kubernetes.io/name"    = "ingress"
      "app.kubernetes.io/part-of" = var.cluster_name
    }
  }
}

# Storage class for local path provisioner (K3s default)
resource "kubernetes_storage_class" "local_path" {
  metadata {
    name = "local-path"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "rancher.io/local-path"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    "path" = "/opt/local-path-provisioner"
  }
}

# Create monitoring storage class for better performance
resource "kubernetes_storage_class" "monitoring_storage" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name = "monitoring-storage"
  }

  storage_provisioner    = "rancher.io/local-path"
  reclaim_policy         = "Retain" # Keep monitoring data on deletion
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    "path" = "/opt/monitoring-storage"
  }
}

# Create resource quota for monitoring namespace.
# NOTE: Only track *requests* aggregate here — limits.cpu/limits.memory in a ResourceQuota
# would block every pod that doesn't set explicit limits (including kube-prometheus-stack sidecars).
# A LimitRange below provides sensible defaults for containers that omit limits.
resource "kubernetes_resource_quota" "monitoring_quota" {
  count = var.enable_monitoring && var.enable_resource_quotas ? 1 : 0

  metadata {
    name      = "monitoring-quota"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"           = var.monitoring_cpu_limit
      "requests.memory"        = var.monitoring_memory_limit
      "requests.storage"       = var.monitoring_storage_limit
      "persistentvolumeclaims" = "10"
    }
  }
}

# Provide default resource limits for containers in the monitoring namespace.
# kube-prometheus-stack injects sidecar containers (config-reloader, grafana-sc-dashboard,
# kube-state-metrics, node-exporter) that don't specify limits — without defaults they would
# be blocked by a ResourceQuota that enforces limits.
resource "kubernetes_limit_range" "monitoring_defaults" {
  count = var.enable_monitoring && var.enable_resource_quotas ? 1 : 0

  metadata {
    name      = "monitoring-defaults"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "200m"
        memory = "256Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }
  }
}

# Network policy for monitoring namespace security
resource "kubernetes_network_policy" "monitoring_network_policy" {
  count = var.enable_monitoring && var.enable_network_policies ? 1 : 0

  metadata {
    name      = "monitoring-network-policy"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "ingress-system"
          }
        }
      }

      # Allow access from same namespace
      from {
        namespace_selector {
          match_labels = {
            name = "monitoring"
          }
        }
      }
    }

    egress {
      # Allow DNS - to kube-system for CoreDNS
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      ports {
        port     = 53
        protocol = "TCP"
      }
      ports {
        port     = 53
        protocol = "UDP"
      }
    }

    egress {
      # Allow Kubernetes API server access  
      ports {
        port     = 443
        protocol = "TCP"
      }
      ports {
        port     = 6443
        protocol = "TCP"
      }
    }

    egress {
      # Allow communication within monitoring namespace
      to {
        namespace_selector {
          match_labels = {
            name = "monitoring"
          }
        }
      }
    }

    egress {
      # Allow Prometheus to scrape pods in any namespace
      to {
        namespace_selector {}
      }
      ports {
        port     = 9090
        protocol = "TCP"
      }
      ports {
        port     = 9100
        protocol = "TCP"
      }
      ports {
        port     = 9115
        protocol = "TCP"
      }
      ports {
        port     = 9617
        protocol = "TCP"
      }
      ports {
        port     = 8080
        protocol = "TCP"
      }
      ports {
        port     = 3000
        protocol = "TCP"
      }
    }

    egress {
      # Allow scraping external targets (Pi-hole, Mac Mini) outside the cluster
      to {
        ip_block {
          cidr = "192.168.0.0/24"
        }
      }
    }
  }
}