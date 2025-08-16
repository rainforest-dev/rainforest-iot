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
      name = "monitoring"
      "app.kubernetes.io/name" = "monitoring"
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
      name = "ingress-system"
      "app.kubernetes.io/name" = "ingress"
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
  reclaim_policy        = "Delete"
  volume_binding_mode   = "WaitForFirstConsumer"
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
  reclaim_policy        = "Retain"  # Keep monitoring data on deletion
  volume_binding_mode   = "WaitForFirstConsumer"
  allow_volume_expansion = true
  
  parameters = {
    "path" = "/opt/monitoring-storage"
  }
}

# Create resource quota for monitoring namespace
resource "kubernetes_resource_quota" "monitoring_quota" {
  count = var.enable_monitoring && var.enable_resource_quotas ? 1 : 0
  
  metadata {
    name      = "monitoring-quota"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
  }
  
  spec {
    hard = {
      "requests.cpu"    = var.monitoring_cpu_limit
      "requests.memory" = var.monitoring_memory_limit
      "requests.storage" = var.monitoring_storage_limit
      "limits.cpu"      = var.monitoring_cpu_limit
      "limits.memory"   = var.monitoring_memory_limit
      "persistentvolumeclaims" = "10"
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
  }
}