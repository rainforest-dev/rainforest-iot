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

# Install Loki stack via Helm
resource "helm_release" "loki_stack" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = var.chart_version
  namespace  = var.namespace

  # Pi 5 optimized values
  values = [
    yamlencode({
      # Loki configuration
      loki = {
        enabled = true
        
        # Resource limits for Pi 5
        resources = {
          requests = {
            cpu    = var.loki_cpu_request
            memory = var.loki_memory_request
          }
          limits = {
            cpu    = var.loki_cpu_limit
            memory = var.loki_memory_limit
          }
        }
        
        # Persistence configuration
        persistence = {
          enabled = true
          storageClassName = var.storage_class
          size = var.loki_storage_size
        }
        
        # Loki configuration
        config = {
          auth_enabled = false
          
          server = {
            http_listen_port = 3100
            grpc_listen_port = 9096
          }
          
          common = {
            path_prefix = "/loki"
            storage = {
              filesystem = {
                chunks_directory = "/loki/chunks"
                rules_directory = "/loki/rules"
              }
            }
            replication_factor = 1
            ring = {
              instance_addr = "127.0.0.1"
              kvstore = {
                store = "inmemory"
              }
            }
          }
          
          schema_config = {
            configs = [
              {
                from = "2020-10-24"
                store = "boltdb-shipper"
                object_store = "filesystem"
                schema = "v11"
                index = {
                  prefix = "index_"
                  period = "24h"
                }
              }
            ]
          }
          
          storage_config = {
            boltdb_shipper = {
              active_index_directory = "/loki/boltdb-shipper-active"
              cache_location = "/loki/boltdb-shipper-cache"
              cache_ttl = "24h"
              shared_store = "filesystem"
            }
            filesystem = {
              directory = "/loki/chunks"
            }
          }
          
          compactor = {
            working_directory = "/loki/boltdb-shipper-compactor"
            shared_store = "filesystem"
          }
          
          limits_config = {
            reject_old_samples = true
            reject_old_samples_max_age = "168h"
            ingestion_rate_mb = 4  # Reduced for Pi 5
            ingestion_burst_size_mb = 6
            max_concurrent_tail_requests = 10
            retention_period = var.loki_retention
          }
          
          chunk_store_config = {
            max_look_back_period = "0s"
          }
          
          table_manager = {
            retention_deletes_enabled = true
            retention_period = var.loki_retention
          }
          
          ruler = {
            storage = {
              type = "local"
              local = {
                directory = "/loki/rules"
              }
            }
            rule_path = "/loki/rules-temp"
            alertmanager_url = var.alertmanager_url
          }
        }
        
        # Service configuration
        service = {
          type = "NodePort"
          nodePort = var.loki_port
        }
      }
      
      # Promtail configuration (log collection agent)
      promtail = {
        enabled = var.promtail_enabled
        
        resources = {
          requests = {
            cpu    = var.promtail_cpu_request
            memory = var.promtail_memory_request
          }
          limits = {
            cpu    = var.promtail_cpu_limit
            memory = var.promtail_memory_limit
          }
        }
        
        config = {
          lokiAddress = "http://loki:3100/loki/api/v1/push"
          
          snippets = {
            scrapeConfigs = [
              {
                job_name = "kubernetes-pods"
                pipeline_stages = [
                  {
                    cri = {}
                  }
                ]
                kubernetes_sd_configs = [
                  {
                    role = "pod"
                  }
                ]
                relabel_configs = [
                  {
                    source_labels = ["__meta_kubernetes_pod_controller_name"]
                    regex = "([0-9a-z-.]+?)(-[0-9a-f]{8,10})?"
                    action = "replace"
                    target_label = "__tmp_controller_name"
                  },
                  {
                    source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name", "__meta_kubernetes_pod_label_app", "__tmp_controller_name", "__meta_kubernetes_pod_name"]
                    regex = "^;*([^;]+)(;.*)?$"
                    action = "replace"
                    target_label = "app"
                  },
                  {
                    source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_instance", "__meta_kubernetes_pod_label_release"]
                    regex = "^;*([^;]+)(;.*)?$"
                    action = "replace"
                    target_label = "instance"
                  },
                  {
                    source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_component", "__meta_kubernetes_pod_label_component"]
                    regex = "^;*([^;]+)(;.*)?$"
                    action = "replace"
                    target_label = "component"
                  }
                ]
              },
              {
                job_name = "kubernetes-pods-app"
                pipeline_stages = [
                  {
                    cri = {}
                  }
                ]
                kubernetes_sd_configs = [
                  {
                    role = "pod"
                  }
                ]
                relabel_configs = [
                  {
                    action = "keep"
                    regex = true
                    source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                  },
                  {
                    action = "replace"
                    source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
                    target_label = "__meta_kubernetes_pod_annotation_prometheus_io_path"
                    regex = "(.+)"
                  }
                ]
              }
            ]
          }
        }
        
        # Mount additional log sources
        extraVolumes = var.extra_log_volumes
        extraVolumeMounts = var.extra_log_volume_mounts
      }
      
      # Fluent Bit (alternative to Promtail, lighter)
      fluent-bit = {
        enabled = var.fluent_bit_enabled
      }
      
      # Grafana (if not already installed via prometheus stack)
      grafana = {
        enabled = false  # We'll use the one from prometheus-stack
      }
      
      # Prometheus (for monitoring Loki itself)
      prometheus = {
        enabled = false  # We'll use the one from prometheus-stack
      }
    })
  ]
}

# Create a ServiceMonitor for Prometheus to scrape Loki metrics
resource "kubernetes_manifest" "loki_service_monitor" {
  count = var.enable_prometheus_monitoring ? 1 : 0
  
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "loki"
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/name" = "loki"
        "app.kubernetes.io/part-of" = "loki-stack"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "loki"
        }
      }
      endpoints = [
        {
          port = "http-metrics"
          path = "/metrics"
          interval = "30s"
        }
      ]
    }
  }
  
  depends_on = [helm_release.loki_stack]
}