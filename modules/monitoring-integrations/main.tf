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
  count      = var.enable_loki_monitoring ? 1 : 0
  depends_on = [time_sleep.wait_for_monitoring_stack]

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "loki"
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/name"    = "loki"
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
          port     = "http-metrics"
          path     = "/metrics"
          interval = "30s"
        }
      ]
    }
  }
}

# Additional scrape configurations for external services
resource "kubernetes_config_map" "additional_scrape_configs" {
  count      = var.enable_external_monitoring ? 1 : 0
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
        metrics_path    = "/metrics"
        scrape_interval = "30s"
      },
      # Mac Mini node monitoring (if node_exporter available)
      {
        job_name = "mac-mini-node"
        static_configs = [
          {
            targets = ["${var.mac_mini_ip}:9100"]
          }
        ]
        scrape_interval = "30s"
      },
      # Mac Mini homelab services monitoring
      {
        job_name = "mac-mini-calibre-web"
        static_configs = [
          {
            targets = ["${var.mac_mini_ip}:8083"]
          }
        ]
        metrics_path    = "/metrics"
        scrape_interval = "60s"
        scheme          = "http"
      },
      {
        job_name = "mac-mini-whisper"
        static_configs = [
          {
            targets = ["${var.mac_mini_ip}:9000"]
          }
        ]
        metrics_path    = "/health"
        scrape_interval = "30s"
        scheme          = "http"
      },
      {
        job_name = "mac-mini-docker-mcp"
        static_configs = [
          {
            targets = ["${var.mac_mini_ip}:3100"]
          }
        ]
        metrics_path    = "/health"
        scrape_interval = "30s"
        scheme          = "http"
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
      },
      # Pi-hole Prometheus exporter (port 9617)
      {
        job_name = "pihole-exporter"
        static_configs = [
          {
            targets = ["${var.raspberry_pi_hostname}:9617"]
            labels  = { instance = "raspberry-pi-5", service = "pihole" }
          }
        ]
        metrics_path    = "/metrics"
        scrape_interval = "30s"
      },
      # CrowdSec metrics
      {
        job_name = "crowdsec"
        static_configs = [
          {
            targets = ["${var.raspberry_pi_hostname}:6060"]
            labels  = { instance = "raspberry-pi-5", service = "crowdsec" }
          }
        ]
        metrics_path    = "/metrics"
        scrape_interval = "30s"
      },
      # Ntopng uptime check (community edition has no native Prometheus export)
      {
        job_name = "ntopng-health"
        static_configs = [
          {
            targets = ["${var.raspberry_pi_hostname}:${var.ntopng_port}"]
            labels  = { instance = "raspberry-pi-5", service = "ntopng" }
          }
        ]
        metrics_path    = "/"
        scrape_interval = "60s"
      }
    ])
  }
}

# Custom alerting rules for homelab
resource "kubernetes_config_map" "homelab_alerting_rules" {
  count      = var.enable_custom_alerts ? 1 : 0
  depends_on = [time_sleep.wait_for_monitoring_stack]

  metadata {
    name      = "homelab-alerting-rules"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "prometheus"
      "prometheus"             = "kube-prometheus-prometheus"
      "role"                   = "alert-rules"
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
                summary     = "High CPU usage detected"
              }
              expr = "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100) > 80"
              for  = "5m"
              labels = {
                severity = "warning"
              }
            },
            {
              alert = "HighMemoryUsage"
              annotations = {
                description = "Memory usage is above 85% for more than 5 minutes on {{ $labels.instance }}"
                summary     = "High memory usage detected"
              }
              expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85"
              for  = "5m"
              labels = {
                severity = "warning"
              }
            },
            {
              alert = "ServiceDown"
              annotations = {
                description = "Service {{ $labels.job }} on {{ $labels.instance }} is down"
                summary     = "Service is down"
              }
              expr = "up == 0"
              for  = "1m"
              labels = {
                severity = "critical"
              }
            },
            {
              alert = "HighDiskUsage"
              annotations = {
                description = "Disk usage is above 90% for more than 5 minutes on {{ $labels.instance }} filesystem {{ $labels.mountpoint }}"
                summary     = "High disk usage detected"
              }
              expr = "(1 - (node_filesystem_avail_bytes{fstype!=\"tmpfs\"} / node_filesystem_size_bytes{fstype!=\"tmpfs\"})) * 100 > 90"
              for  = "5m"
              labels = {
                severity = "critical"
              }
            },
            {
              alert = "HomelabServiceDown"
              annotations = {
                description = "Homelab service {{ $labels.job }} is not responding"
                summary     = "Homelab service is down"
              }
              expr = "up{job=~\"mac-mini-.*|pi-hole\"} == 0"
              for  = "2m"
              labels = {
                severity = "warning"
              }
            },
            {
              alert = "KubernetesNodeNotReady"
              annotations = {
                description = "Kubernetes node {{ $labels.node }} is not ready"
                summary     = "Kubernetes node not ready"
              }
              expr = "kube_node_status_condition{condition=\"Ready\",status=\"true\"} == 0"
              for  = "5m"
              labels = {
                severity = "critical"
              }
            },
            {
              alert = "KubernetesPodCrashLooping"
              annotations = {
                description = "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
                summary     = "Pod is crash looping"
              }
              expr = "rate(kube_pod_container_status_restarts_total[15m]) * 60 * 15 > 0"
              for  = "5m"
              labels = {
                severity = "warning"
              }
            }
          ]
        }
      ]
    })
  }
}