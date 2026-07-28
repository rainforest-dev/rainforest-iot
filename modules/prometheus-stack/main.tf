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

resource "kubernetes_config_map" "grafana_dashboard_pihole" {
  metadata {
    name      = "grafana-pihole-stats"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "pihole-stats.json" = file("${path.module}/dashboards/pihole-stats.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_crowdsec" {
  metadata {
    name      = "grafana-crowdsec-events"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "crowdsec-events.json" = file("${path.module}/dashboards/crowdsec-events.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_service_status" {
  metadata {
    name      = "grafana-service-status"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "service-status.json" = file("${path.module}/dashboards/service-status.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_ai_automation" {
  metadata {
    name      = "grafana-ai-automation"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "ai-automation.json" = file("${path.module}/dashboards/ai-automation.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_home_music" {
  metadata {
    name      = "grafana-home-music"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "home-music.json" = file("${path.module}/dashboards/home-music.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_ha_security" {
  metadata {
    name      = "grafana-ha-security"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "ha-security.json" = file("${path.module}/dashboards/ha-security.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_ha_home_comfort" {
  metadata {
    name      = "grafana-ha-home-comfort"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "ha-home-comfort.json" = file("${path.module}/dashboards/ha-home-comfort.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_ha_robot_maid" {
  metadata {
    name      = "grafana-ha-robot-maid"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "ha-robot-maid.json" = file("${path.module}/dashboards/ha-robot-maid.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_ha_daily_rhythm" {
  metadata {
    name      = "grafana-ha-daily-rhythm"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "ha-daily-rhythm.json" = file("${path.module}/dashboards/ha-daily-rhythm.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_ha_maintenance_hub" {
  metadata {
    name      = "grafana-ha-maintenance-hub"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "ha-maintenance-hub.json" = file("${path.module}/dashboards/ha-maintenance-hub.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_isp_network" {
  metadata {
    name      = "grafana-isp-network"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "isp-network.json" = file("${path.module}/dashboards/isp-network.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_local_machines" {
  metadata {
    name      = "grafana-local-machines"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "local-machines.json" = file("${path.module}/dashboards/local-machines.json")
  }
}


# Build the list of additional scrape job configs.
# All scrape targets use raw IPs — K3s CoreDNS cannot resolve .local mDNS hostnames.
locals {
  _resolved_ip = var.external_ip != "" ? var.external_ip : var.external_hostname

  _relabel_blackbox = [
    { source_labels = ["__address__"], target_label = "__param_target" },
    { source_labels = ["__param_target"], target_label = "instance" },
    { target_label = "__address__", replacement = "prometheus-prometheus-blackbox-exporter:9115" },
  ]

  # Note: mac-mini-docker (port 2375 dockerproxy) was removed — docker-socket-proxy
  # has no /metrics endpoint (403 on all non-Docker-API paths). Mac Mini telemetry
  # is handled by Grafana Alloy push → Pi Prometheus remote_write instead.
  # mac-mini-minio was removed — MinIO is ClusterIP-only on Mac Mini, unreachable
  # from Pi scraper. Alloy collects container/cluster metrics and pushes them.

  _base_scrape_jobs = [
    # Pi-hole Prometheus exporter sidecar (port 9617).
    # Replaces the old /admin/api.php job which returned JSON, not Prometheus text-format.
    {
      job_name       = "pihole-exporter"
      static_configs = [{ targets = ["${local._resolved_ip}:9617"], labels = { instance = "raspberry-pi-5", service = "pihole" } }]
      metrics_path    = "/metrics"
      scrape_interval = "30s"
    },
    # Speedtest exporter — two WiFi sample points at different locations.
    # Both run every 30 min. Use 'instance' label to compare locations.
    {
      job_name       = "speedtest"
      metrics_path   = "/metrics"
      scrape_interval = "30m" # Don't run too frequently — each test uses ~200MB of bandwidth
      scrape_timeout  = "90s" # Speedtest takes up to 60s to complete
      static_configs = [{
        targets = [
          "${var.mac_mini_ip}:9798",
          "${local._resolved_ip}:9799",
        ]
        labels = { service = "speedtest" }
      }]
      relabel_configs = [
        {
          source_labels = ["__address__"]
          regex         = "${replace(var.mac_mini_ip, ".", "\\.")}:.*"
          target_label  = "instance"
          replacement   = "mac-mini"
        },
        {
          source_labels = ["__address__"]
          regex         = "${replace(local._resolved_ip, ".", "\\.")}:.*"
          target_label  = "instance"
          replacement   = "raspberry-pi"
        },
      ]
    },
    # CrowdSec IDS metrics (community bans + local decisions)
    {
      job_name       = "crowdsec"
      static_configs = [{ targets = ["${local._resolved_ip}:6060"], labels = { instance = "raspberry-pi-5", service = "crowdsec" } }]
      metrics_path    = "/metrics"
      scrape_interval = "30s"
    },
    # Blackbox Exporter — HTTP synthetic monitoring
    {
      job_name        = "blackbox-http"
      metrics_path    = "/probe"
      params          = { module = ["http_2xx"] }
      static_configs  = [{ targets = var.blackbox_http_targets }]
      relabel_configs = local._relabel_blackbox
    },
    # Blackbox Exporter — ICMP ping probes
    {
      job_name        = "blackbox-icmp"
      metrics_path    = "/probe"
      params          = { module = ["icmp"] }
      static_configs  = [{ targets = var.blackbox_icmp_targets }]
      relabel_configs = local._relabel_blackbox
    },
    # Blackbox Exporter — MCP OAuth gateway liveness
    # Probes /.well-known/oauth-authorization-server which returns 200 without auth.
    # A 200 here confirms the Cloudflare Worker + tunnel routing stack is healthy end-to-end.
    {
      job_name        = "blackbox-mcp"
      metrics_path    = "/probe"
      params          = { module = ["http_2xx"] }
      static_configs  = [{ targets = [for t in var.blackbox_mcp_targets : "${t}/.well-known/oauth-authorization-server"] }]
      relabel_configs = local._relabel_blackbox
    },
  ]

  # Home Assistant job is optional — requires a long-lived token + HA Prometheus integration enabled.
  _ha_scrape_job = var.homeassistant_token != "" ? [{
    job_name       = "homeassistant"
    static_configs = [{ targets = ["${local._resolved_ip}:8123"] }]
    metrics_path    = "/api/prometheus"
    authorization  = { credentials = var.homeassistant_token }
    scrape_interval = "60s"
  }] : []

  _all_scrape_jobs = concat(local._base_scrape_jobs, local._ha_scrape_job)
}

# Create Secret for additional scrape configs (Prometheus operator expects Secret, not ConfigMap)
resource "kubernetes_secret" "prometheus_additional_scrape_configs" {
  metadata {
    name      = "additional-scrape-configs"
    namespace = var.namespace
  }

  data = {
    # yamlencode generates guaranteed-valid YAML, avoiding the whitespace-stripping
    # issues that Terraform templatefile %{~ for ~} loops cause in YAML list contexts.
    "prometheus-additional.yaml" = yamlencode(local._all_scrape_jobs)
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
  timeout    = 600 # 10 min — Pi 5 needs extra time to pull/roll pods

  # Pi 5 optimized values
  values = [
    yamlencode({
      # Prometheus configuration
      prometheus = {
        prometheusSpec = {
          enableRemoteWriteReceiver = true

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
            name    = kubernetes_secret.prometheus_additional_scrape_configs.metadata[0].name
            key     = "prometheus-additional.yaml"
          }

          # External access
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          ruleSelectorNilUsesHelmValues           = false

          # Enable external URL access
          externalUrl = "http://${var.external_hostname}:${var.prometheus_port}"
        }

        service = {
          type     = "NodePort"
          nodePort = var.prometheus_port
        }
      }

      # Grafana configuration
      grafana = {
        enabled = var.grafana_enabled

        # Pin Grafana 13.1.1 explicitly — chart 87.19.0 bundles 13.x, but we must
        # avoid 13.0.0 (a storage-migration bug can lose dashboards; fixed in 13.0.1+).
        image = {
          tag = "13.1.1"
        }

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
          enabled          = true
          storageClassName = var.storage_class
          size             = var.grafana_storage_size
        }

        # Service configuration
        service = {
          type     = "NodePort"
          nodePort = var.grafana_port
        }

        # Default dashboards (disabled — Kubernetes/* and Node Exporter/* defaults add clutter)
        defaultDashboardsEnabled = false

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
            admin_user = "admin"
            # admin_password is set via the top-level adminPassword value (K8s secret)
            # Setting it here too triggers kube-prometheus-stack's assertNoLeakedSecrets check
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
          type     = "NodePort"
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

      # Blackbox Exporter for HTTP health checks
      "prometheus-blackbox-exporter" = {
        enabled = true

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

        config = {
          modules = {
            http_2xx = {
              prober  = "http"
              timeout = "5s"
              http = {
                valid_status_codes    = []
                valid_http_versions   = ["HTTP/1.1", "HTTP/2.0"]
                follow_redirects      = true
                preferred_ip_protocol = "ip4"
              }
            }
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
        # config-reloader sidecar limits — required when ResourceQuota mandates limits on all containers
        configReloaderResources = {
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

      # Blackbox probes have no default rule in kube-prometheus-stack, so a public
      # endpoint could go down silently. probe_success is emitted per target by the
      # blackbox exporter.
      additionalPrometheusRulesMap = {
        blackbox-rules = {
          groups = [
            {
              name = "blackbox"
              rules = [
                {
                  alert = "BlackboxProbeFailed"
                  expr  = "probe_success == 0"
                  for   = "5m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary = "Probe failing for {{ $labels.instance }}"
                  }
                }
              ]
            }
          ]
        }

        # Homelab host/service alerts. These previously lived in a plain ConfigMap
        # labelled role=alert-rules, which the Prometheus Operator never reads —
        # it only picks up PrometheusRule CRDs, so they never loaded. Rules that
        # duplicated kube-prometheus-stack built-ins were dropped rather than ported.
        homelab-rules = {
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
                  alert = "HomelabServiceDown"
                  expr  = "up{job=~\"mac-mini-.*|pi-hole\"} == 0"
                  for   = "2m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary     = "Homelab service is down"
                    description = "Homelab service {{ $labels.job }} is not responding"
                  }
                }
              ]
            }
          ]
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

# ---------------------------------------------------------------------------
# Standalone blackbox exporter
#
# The kube-prometheus-stack Helm subchart (prometheus-blackbox-exporter) was
# added to the Helm values AFTER the chart was first deployed (277 days ago),
# so it was never rolled out via Helm.  These three resources mirror what was
# deployed imperatively via `kubectl apply` so that Terraform owns the
# lifecycle going forward.  Import them with:
#   terraform import 'module.prometheus_stack[0].kubernetes_config_map.blackbox_exporter_config' 'monitoring/blackbox-exporter-config'
#   terraform import 'module.prometheus_stack[0].kubernetes_deployment.blackbox_exporter'        'monitoring/prometheus-prometheus-blackbox-exporter'
#   terraform import 'module.prometheus_stack[0].kubernetes_service.blackbox_exporter'           'monitoring/prometheus-prometheus-blackbox-exporter'
# ---------------------------------------------------------------------------

resource "kubernetes_config_map" "blackbox_exporter_config" {
  metadata {
    name      = "blackbox-exporter-config"
    namespace = var.namespace
    labels = {
      app = "blackbox-exporter"
    }
  }

  data = {
    # icmp probe uses preferred_ip_protocol: ip4 to avoid IPv6 issues on Pi.
    # valid_status_codes: [] means Prometheus uses its default (2xx).
    "config.yml" = <<-YAML
      modules:
        http_2xx:
          prober: http
          timeout: 10s
          http:
            preferred_ip_protocol: ip4
            valid_status_codes: []
        icmp:
          prober: icmp
          timeout: 10s
          icmp:
            preferred_ip_protocol: ip4
    YAML
  }
}

resource "kubernetes_deployment" "blackbox_exporter" {
  metadata {
    name      = "prometheus-prometheus-blackbox-exporter"
    namespace = var.namespace
    labels = {
      app = "blackbox-exporter"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "blackbox-exporter"
      }
    }

    template {
      metadata {
        labels = {
          app = "blackbox-exporter"
        }
      }

      spec {
        container {
          name  = "blackbox-exporter"
          image = "prom/blackbox-exporter:v0.25.0"
          args  = ["--config.file=/etc/blackbox_exporter/config.yml"]

          port {
            name           = "http"
            container_port = 9115
          }

          resources {
            requests = {
              cpu    = "20m"
              memory = "32Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/blackbox_exporter"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.blackbox_exporter_config.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_config_map.blackbox_exporter_config]
}

resource "kubernetes_service" "blackbox_exporter" {
  metadata {
    # Name must match the address used in scrape relabeling:
    #   replacement = "prometheus-prometheus-blackbox-exporter:9115"
    name      = "prometheus-prometheus-blackbox-exporter"
    namespace = var.namespace
    labels = {
      app = "blackbox-exporter"
    }
  }

  spec {
    selector = {
      app = "blackbox-exporter"
    }

    port {
      name        = "http"
      port        = 9115
      target_port = 9115
    }

    type = "ClusterIP"
  }
}

# ─── Speedtest exporter on Raspberry Pi (WiFi sample point) ─────────────────

resource "kubernetes_deployment" "speedtest_exporter" {
  metadata {
    name      = "speedtest-exporter"
    namespace = var.namespace
    labels    = { app = "speedtest-exporter" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "speedtest-exporter" }
    }

    template {
      metadata {
        labels = { app = "speedtest-exporter" }
      }

      spec {
        container {
          name  = "speedtest-exporter"
          image = "ghcr.io/miguelndecarvalho/speedtest-exporter:v3.5.4"

          port {
            container_port = 9798
          }

          # A speedtest run buffers ~200MB of download, so a 128Mi limit got the
          # container OOMKilled (exit 137) mid-test — it crash-looped 8000+ times
          # and never reported a result. 320Mi covers a run with headroom.
          resources {
            requests = { cpu = "50m", memory = "96Mi" }
            limits   = { cpu = "500m", memory = "320Mi" }
          }

          # Probe the landing page, NOT /healthz (this image has no such route —
          # it returned 404, so the kubelet SIGKILLed the container ~every 2 min:
          # 627 restarts, exit 137 misread as OOM). Root "/" returns 200 instantly;
          # do NOT use "/metrics" — that path runs a real speedtest on every hit.
          liveness_probe {
            http_get {
              path = "/"
              port = 9798
            }
            initial_delay_seconds = 10
            period_seconds        = 30
            timeout_seconds       = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "speedtest_exporter" {
  metadata {
    name      = "speedtest-exporter"
    namespace = var.namespace
    labels    = { app = "speedtest-exporter" }
  }

  spec {
    selector = { app = "speedtest-exporter" }

    port {
      name        = "metrics"
      port        = 9799
      target_port = 9798
      node_port   = 30099
    }

    type = "NodePort"
  }
}