# Monitoring Integrations Module
# This module handles ServiceMonitors and custom monitoring configurations
# that integrate with the core monitoring stack deployed by Ansible

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# Wait for core monitoring stack to be ready
resource "time_sleep" "wait_for_monitoring_stack" {
  create_duration = "30s"
}

# Loki ServiceMonitor for Prometheus integration
resource "kubernetes_manifest" "loki_service_monitor" {
  count = var.enable_loki_monitoring ? 1 : 0
  depends_on = [time_sleep.wait_for_monitoring_stack]
  
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
}

# Additional scrape configurations for external services
resource "kubernetes_config_map" "additional_scrape_configs" {
  count = var.enable_external_monitoring ? 1 : 0
  depends_on = [time_sleep.wait_for_monitoring_stack]
  
  metadata {
    name      = "prometheus-additional-scrape-configs"
    namespace = var.namespace
  }

  data = {
    "additional-scrape-configs.yaml" = yamlencode([
      # Mac Mini Docker monitoring
      {
        job_name = "mac-mini-docker"
        static_configs = [
          {
            targets = [var.mac_mini_docker_endpoint]
          }
        ]
        metrics_path = "/metrics"
        scrape_interval = "30s"
      },
      # Mac Mini node monitoring
      {
        job_name = "mac-mini-node"
        static_configs = [
          {
            targets = ["${var.mac_mini_ip}:9100"]
          }
        ]
        scrape_interval = "30s"
      },
      # Pi-hole monitoring
      {
        job_name = "pi-hole"
        static_configs = [
          {
            targets = ["${var.raspberry_pi_hostname}:${var.pihole_port}"]
          }
        ]
        metrics_path = "/admin/api.php"
        params = {
          auth = [var.pihole_api_token]
        }
        scrape_interval = "60s"
      }
    ])
  }
}

# Custom alerting rules for homelab
resource "kubernetes_config_map" "homelab_alerting_rules" {
  count = var.enable_custom_alerts ? 1 : 0
  depends_on = [time_sleep.wait_for_monitoring_stack]
  
  metadata {
    name = "homelab-alerting-rules"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "prometheus"
      "prometheus" = "kube-prometheus-prometheus"
      "role" = "alert-rules"
    }
  }

  data = {
    "homelab-rules.yaml" = yamlencode({
      groups = [
        {
          name = "homelab.rules"
          rules = [
            {
              alert = "HighCPUUsage"
              annotations = {
                description = "CPU usage is above 80% for more than 5 minutes on {{ $labels.instance }}"
                summary = "High CPU usage detected"
              }
              expr = "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100) > 80"
              for = "5m"
              labels = {
                severity = "warning"
              }
            },
            {
              alert = "HighMemoryUsage"
              annotations = {
                description = "Memory usage is above 85% for more than 5 minutes on {{ $labels.instance }}"
                summary = "High memory usage detected"
              }
              expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85"
              for = "5m"
              labels = {
                severity = "warning"
              }
            },
            {
              alert = "ServiceDown"
              annotations = {
                description = "Service {{ $labels.job }} on {{ $labels.instance }} is down"
                summary = "Service is down"
              }
              expr = "up == 0"
              for = "1m"
              labels = {
                severity = "critical"
              }
            },
            {
              alert = "HighDiskUsage"
              annotations = {
                description = "Disk usage is above 90% for more than 5 minutes on {{ $labels.instance }} filesystem {{ $labels.mountpoint }}"
                summary = "High disk usage detected"
              }
              expr = "(1 - (node_filesystem_avail_bytes{fstype!=\"tmpfs\"} / node_filesystem_size_bytes{fstype!=\"tmpfs\"})) * 100 > 90"
              for = "5m"
              labels = {
                severity = "critical"
              }
            }
          ]
        }
      ]
    })
  }
}