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

# Grafana dashboards as ConfigMaps for sidecar auto-import
resource "kubernetes_config_map" "grafana_dashboard_homelab_overview" {
  metadata {
    name      = "grafana-homelab-overview"
    namespace = var.namespace
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "homelab-overview.json" = file("${path.module}/dashboards/homelab-overview.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_kubernetes_cluster" {
  metadata {
    name      = "grafana-kubernetes-cluster"
    namespace = var.namespace
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "kubernetes-cluster.json" = file("${path.module}/dashboards/kubernetes-cluster.json")
  }
}

# Create Secret for additional scrape configs (Prometheus operator expects Secret, not ConfigMap)
resource "kubernetes_secret" "prometheus_additional_scrape_configs" {
  metadata {
    name      = "additional-scrape-configs"
    namespace = var.namespace
  }

  data = {
    "prometheus-additional.yaml" = templatefile("${path.module}/templates/additional-scrape-configs.yaml.tpl", {
      mac_mini_docker_endpoint = var.mac_mini_docker_endpoint
      mac_mini_ip              = var.mac_mini_ip
      pihole_endpoint          = var.pihole_endpoint
      pihole_api_token         = var.pihole_api_token
      external_hostname        = var.external_hostname
    })
  }

  type = "Opaque"
}

# Install kube-prometheus-stack via Helm
resource "helm_release" "prometheus_stack" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version
  namespace  = var.namespace

  # Pi 5 optimized values
  values = [
    yamlencode({
      # Prometheus configuration
      prometheus = {
        prometheusSpec = {
          # Add pod labels for Homepage integration
          podMetadata = {
            labels = {
              app = "prometheus"
            }
          }
          
          # Resource limits for Pi 5
          resources = {
            requests = {
              cpu    = var.prometheus_cpu_request
              memory = var.prometheus_memory_request
            }
            limits = {
              cpu    = var.prometheus_cpu_limit
              memory = var.prometheus_memory_limit
            }
          }
          
          # Storage configuration
          retention = var.prometheus_retention
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          }
          
          # Additional scrape configs for comprehensive monitoring
          additionalScrapeConfigsSecret = {
            enabled = true
            name = kubernetes_secret.prometheus_additional_scrape_configs.metadata[0].name
            key  = "prometheus-additional.yaml"
          }
          
          # External access
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          ruleSelectorNilUsesHelmValues           = false
          
          # Enable external URL access
          externalUrl = "http://${var.external_hostname}:${var.prometheus_port}"
        }
        
        service = {
          type = "NodePort"
          nodePort = var.prometheus_port
        }
      }
      
      # Grafana configuration
      grafana = {
        enabled = var.grafana_enabled
        
        # Add pod labels for Homepage integration
        podLabels = {
          app = "grafana"
        }
        
        # Resource limits
        resources = {
          requests = {
            cpu    = var.grafana_cpu_request
            memory = var.grafana_memory_request
          }
          limits = {
            cpu    = var.grafana_cpu_limit
            memory = var.grafana_memory_limit
          }
        }
        
        # Admin credentials
        adminPassword = var.grafana_admin_password
        
        # Persistence
        persistence = {
          enabled = true
          storageClassName = var.storage_class
          size = var.grafana_storage_size
        }
        
        # Service configuration
        service = {
          type = "NodePort"
          nodePort = var.grafana_port
        }
        
        # Default dashboards
        defaultDashboardsEnabled = true
        
        # Additional data sources
        additionalDataSources = concat(var.grafana_additional_datasources, [
          {
            name      = "Loki"
            type      = "loki"
            url       = "http://loki:3100"
            access    = "proxy"
            isDefault = false
          }
        ])
        
        # Grafana configuration
        "grafana.ini" = {
          server = {
            root_url = "http://${var.external_hostname}:${var.grafana_port}"
          }
          "auth.anonymous" = {
            enabled = false
          }
          security = {
            admin_user     = "admin"
            admin_password = var.grafana_admin_password
          }
        }
        
        # Sidecar resource limits
        sidecar = {
          dashboards = {
            enabled = true
            label   = "grafana_dashboard"
            resources = {
              requests = {
                cpu    = "50m"
                memory = "64Mi"
              }
              limits = {
                cpu    = "100m"
                memory = "128Mi"
              }
            }
          }
          datasources = {
            resources = {
              requests = {
                cpu    = "50m"
                memory = "64Mi"
              }
              limits = {
                cpu    = "100m"
                memory = "128Mi"
              }
            }
          }
        }
        
        # Init container resource limits
        initChownData = {
          resources = {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
      }
      
      # AlertManager configuration
      alertmanager = {
        enabled = var.alertmanager_enabled
        
        alertmanagerSpec = {
          # Add pod labels for Homepage integration
          podMetadata = {
            labels = {
              app = "alertmanager"
            }
          }
          
          resources = {
            requests = {
              cpu    = var.alertmanager_cpu_request
              memory = var.alertmanager_memory_request
            }
            limits = {
              cpu    = var.alertmanager_cpu_limit
              memory = var.alertmanager_memory_limit
            }
          }
          
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.alertmanager_storage_size
                  }
                }
              }
            }
          }
          
          externalUrl = "http://${var.external_hostname}:${var.alertmanager_port}"
        }
        
        service = {
          type = "NodePort"
          nodePort = var.alertmanager_port
        }
      }
      
      # Node Exporter configuration
      nodeExporter = {
        enabled = var.node_exporter_enabled
        
        resources = {
          requests = {
            cpu    = "50m"
            memory = "32Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "64Mi"
          }
        }
      }
      
      # Kube State Metrics configuration
      kubeStateMetrics = {
        enabled = var.kube_state_metrics_enabled
        
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
      
      # Admission webhook configuration with resource limits
      prometheusOperator = {
        admissionWebhooks = {
          patch = {
            resources = {
              requests = {
                cpu    = "10m"
                memory = "32Mi"
              }
              limits = {
                cpu    = "50m"
                memory = "64Mi"
              }
            }
          }
        }
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
      
      # Disable components that are too heavy for Pi
      kubeEtcd = {
        enabled = false
      }
      kubeControllerManager = {
        enabled = false
      }
      kubeScheduler = {
        enabled = false
      }
      kubeProxy = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_secret.prometheus_additional_scrape_configs]
}

# Create custom alerting rules for homelab
resource "kubernetes_config_map" "alerting_rules" {
  count = var.enable_custom_alerts ? 1 : 0
  
  metadata {
    name      = "homelab-alerting-rules"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "prometheus"
      "prometheus" = "kube-prometheus-prometheus"
      "role" = "alert-rules"
    }
  }

  data = {
    "homelab.rules.yaml" = yamlencode({
      groups = [
        {
          name = "homelab.rules"
          rules = [
            {
              alert = "HighCPUUsage"
              expr  = "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100) > 80"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "High CPU usage detected"
                description = "CPU usage is above 80% for more than 5 minutes on {{ $labels.instance }}"
              }
            },
            {
              alert = "HighMemoryUsage"
              expr  = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "High memory usage detected"
                description = "Memory usage is above 85% for more than 5 minutes on {{ $labels.instance }}"
              }
            },
            {
              alert = "ServiceDown"
              expr  = "up == 0"
              for   = "1m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Service is down"
                description = "Service {{ $labels.job }} on {{ $labels.instance }} is down"
              }
            },
            {
              alert = "HighDiskUsage"
              expr  = "(1 - (node_filesystem_avail_bytes{fstype!=\"tmpfs\"} / node_filesystem_size_bytes{fstype!=\"tmpfs\"})) * 100 > 90"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "High disk usage detected"
                description = "Disk usage is above 90% for more than 5 minutes on {{ $labels.instance }} filesystem {{ $labels.mountpoint }}"
              }
            }
          ]
        }
      ]
    })
  }
}