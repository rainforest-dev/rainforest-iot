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
      # Pi-hole Prometheus exporter (port 9617) — Pi-hole v6 compatible
      # The exporter handles password auth internally via PIHOLE_PASSWORD env var.
      # Direct /admin/api.php scrape removed: Pi-hole v6 dropped this endpoint.
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

# NOTE: Custom alerting rules were previously managed here but have been consolidated
# into modules/prometheus-stack/main.tf (kubernetes_config_map.alerting_rules) to
# avoid Terraform managing two resources that point to the same Kubernetes ConfigMap.
# The three homelab-specific alerts (HomelabServiceDown, KubernetesNodeNotReady,
# KubernetesPodCrashLooping) were merged into prometheus-stack at the same time.