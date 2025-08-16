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

# Create ConfigMap for additional scrape configs
resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-additional-scrape-configs"
    namespace = var.namespace
  }

  data = {
    "additional-scrape-configs.yaml" = yamlencode([
      {
        job_name = "mac-mini-docker"
        static_configs = [{
          targets = [var.mac_mini_docker_endpoint]
        }]
        metrics_path = "/metrics"
        scrape_interval = "30s"
      },
      {
        job_name = "mac-mini-node"
        static_configs = [{
          targets = ["${var.mac_mini_ip}:9100"]
        }]
        scrape_interval = "30s"
      },
      {
        job_name = "pi-hole"
        static_configs = [{
          targets = ["${var.pihole_endpoint}"]
        }]
        metrics_path = "/admin/api.php"
        params = {
          "auth" = [var.pihole_api_token]
        }
        scrape_interval = "60s"
      }
    ])
  }
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
          
          # Additional scrape configs
          additionalScrapeConfigsSecret = {
            enabled = true
            name    = kubernetes_config_map.prometheus_config.metadata[0].name
            key     = "additional-scrape-configs.yaml"
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

  depends_on = [kubernetes_config_map.prometheus_config]
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