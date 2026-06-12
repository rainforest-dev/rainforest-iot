provider "docker" {
  alias = "raspberry-pi"
  host  = local.raspberry_pi_host

  # Use IdentitiesOnly to avoid "Too many authentication failures" when SSH agent
  # has many keys loaded. The Docker SSH client tries all agent keys by default,
  # which exceeds the server's MaxAuthTries limit.
  ssh_opts = [
    "-i", "~/.ssh/id_ed25519.rpi5",
    "-o", "IdentitiesOnly=yes",
    "-o", "ServerAliveInterval=30",
    "-o", "ServerAliveCountMax=6",
  ]
}

# Kubernetes provider for K3s cluster
provider "kubernetes" {
  alias          = "k3s"
  config_path    = var.k8s_config_path
  config_context = var.k8s_config_context
  insecure       = var.k8s_insecure_skip_tls_verify
}

# Helm provider for K3s cluster
provider "helm" {
  alias = "k3s"
  kubernetes {
    config_path    = var.k8s_config_path
    config_context = var.k8s_config_context
    insecure       = var.k8s_insecure_skip_tls_verify
  }
}

module "homeassistant" {
  source = "./modules/homeassistant"

  providers = {
    docker = docker.raspberry-pi
  }

  # Pass configuration variables
  hostname           = var.raspberry_pi_hostname
  memory_limit       = var.homeassistant_memory
  enable_usb_devices = var.enable_usb_devices
  enable_hacs        = var.enable_hacs
  timezone           = var.timezone
  log_opts           = local.common_log_opts

  # Trust the Mac Mini as a reverse proxy (Cloudflare Tunnel routes through it)
  # Scoped to the local /24 subnet rather than broad RFC1918 ranges
  trusted_proxies = ["192.168.0.0/24"]
  ssh_user        = var.raspberry_pi_user
  ssh_port        = var.raspberry_pi_port
}

module "music_assistant" {
  source = "./modules/music-assistant"

  providers = {
    docker = docker.raspberry-pi
  }

  hostname     = var.raspberry_pi_hostname
  memory_limit = var.music_assistant_memory
  timezone     = var.timezone
  log_opts     = local.common_log_opts
  base_url     = "https://music-assistant.rainforest.tools"
}

module "homebridge" {
  source = "./modules/homebridge"

  providers = {
    docker = docker.raspberry-pi
  }

  hostname      = var.raspberry_pi_hostname
  pi_hostname   = var.raspberry_pi_hostname
  pi_user       = var.raspberry_pi_user
  pi_port       = var.raspberry_pi_port
  memory_limit  = var.homebridge_memory
  web_port      = var.homebridge_web_port
  timezone      = var.timezone
  log_opts      = local.common_log_opts
  image_version = var.homebridge_image_version
}

# module "acton-3" {
#   source = "./modules/acton-3"

#   providers = {
#     docker = docker.raspberry-pi
#   }

#   timezone = var.timezone
#   log_opts = local.common_log_opts
# }

module "homepage" {
  source = "./modules/homepage"

  providers = {
    docker = docker.raspberry-pi
  }

  hostname              = var.raspberry_pi_hostname
  raspberry_pi_hostname = var.raspberry_pi_hostname
  raspberry_pi_ip       = var.raspberry_pi_ip
  raspberry_pi_user     = var.raspberry_pi_user
  external_port         = var.homepage_port
  timezone              = var.timezone
  log_opts              = local.common_log_opts
  image_version         = var.homepage_image_version

  # New template variables
  mac_mini_hostname                  = var.mac_mini_hostname
  mac_mini_ip                        = var.mac_mini_ip
  homepage_title                     = var.homepage_title
  homepage_enable_kubernetes_widgets = var.homepage_enable_kubernetes_widgets
  grafana_port                       = var.grafana_port
  grafana_username                   = "admin"
  grafana_password                   = var.grafana_admin_password
  prometheus_port                    = var.prometheus_port
  alertmanager_port                  = var.alertmanager_port
  loki_port                          = var.loki_port

  # Kubeconfig paths for dual cluster support
  mac_mini_kubeconfig_path     = var.mac_mini_kubeconfig_path
  raspberry_pi_kubeconfig_path = var.k8s_config_path
}


module "openspeedtest" {
  source = "./modules/openspeedtest"

  providers = {
    docker = docker.raspberry-pi
  }

  hostname      = var.raspberry_pi_hostname
  ports         = var.openspeedtest_ports
  timezone      = var.timezone
  log_opts      = local.common_log_opts
  image_version = var.openspeedtest_image_version
}

module "pi-hole" {
  source = "./modules/pi-hole"

  providers = {
    docker = docker.raspberry-pi
  }

  hostname         = var.raspberry_pi_hostname
  web_port         = var.pihole_web_port
  timezone         = var.timezone
  log_opts         = local.common_log_opts
  image_version    = var.pihole_image_version
  ssh_user         = var.raspberry_pi_user
  ssh_port         = var.raspberry_pi_port
  exporter_version = var.pihole_exporter_version
  pihole_password = var.pihole_password
}

# K3s Cluster configuration (when enabled)
module "k3s_cluster" {
  count  = var.enable_k8s_cluster ? 1 : 0
  source = "./modules/k3s-cluster"

  providers = {
    kubernetes = kubernetes.k3s
  }

  cluster_name            = var.k8s_cluster_name
  enable_monitoring       = var.k8s_enable_monitoring
  enable_ingress          = var.k8s_enable_ingress
  enable_resource_quotas  = var.k8s_enable_resource_quotas
  enable_network_policies = var.k8s_enable_network_policies
  pi_hostname             = var.raspberry_pi_hostname
  pi_user                 = var.raspberry_pi_user
  pi_ssh_private_key      = var.pi_ssh_private_key
}

# Prometheus monitoring stack (when K8s is enabled)
module "prometheus_stack" {
  count      = var.enable_k8s_cluster && var.k8s_enable_monitoring ? 1 : 0
  source     = "./modules/prometheus-stack"
  depends_on = [module.k3s_cluster]

  providers = {
    kubernetes = kubernetes.k3s
    helm       = helm.k3s
  }

  namespace         = var.k8s_monitoring_namespace
  chart_version     = var.prometheus_chart_version
  storage_class     = var.k8s_storage_class
  external_hostname = var.raspberry_pi_hostname

  # Prometheus configuration
  prometheus_cpu_request    = var.monitoring_resource_limits.prometheus_cpu_request
  prometheus_cpu_limit      = var.monitoring_resource_limits.prometheus_cpu_limit
  prometheus_memory_request = var.monitoring_resource_limits.prometheus_memory_request
  prometheus_memory_limit   = var.monitoring_resource_limits.prometheus_memory_limit
  prometheus_storage_size   = var.monitoring_resource_limits.prometheus_storage_size
  prometheus_retention      = var.monitoring_resource_limits.prometheus_retention
  prometheus_port           = var.prometheus_port

  # Grafana configuration
  grafana_enabled        = var.grafana_enabled
  grafana_cpu_request    = var.monitoring_resource_limits.grafana_cpu_request
  grafana_cpu_limit      = var.monitoring_resource_limits.grafana_cpu_limit
  grafana_memory_request = var.monitoring_resource_limits.grafana_memory_request
  grafana_memory_limit   = var.monitoring_resource_limits.grafana_memory_limit
  grafana_storage_size   = var.monitoring_resource_limits.grafana_storage_size
  grafana_admin_password = var.grafana_admin_password
  grafana_port           = var.grafana_port

  # AlertManager configuration
  alertmanager_enabled        = var.alertmanager_enabled
  alertmanager_cpu_request    = var.monitoring_resource_limits.alertmanager_cpu_request
  alertmanager_cpu_limit      = var.monitoring_resource_limits.alertmanager_cpu_limit
  alertmanager_memory_request = var.monitoring_resource_limits.alertmanager_memory_request
  alertmanager_memory_limit   = var.monitoring_resource_limits.alertmanager_memory_limit
  alertmanager_storage_size   = var.monitoring_resource_limits.alertmanager_storage_size
  alertmanager_port           = var.alertmanager_port

  # External monitoring targets — use IPs, not .local hostnames (K3s CoreDNS can't resolve mDNS).
  # Mac Mini metrics come via Grafana Alloy push (remote_write) rather than pull-based scraping.
  external_ip           = var.raspberry_pi_ip
  blackbox_http_targets = var.blackbox_http_targets
  blackbox_icmp_targets = var.blackbox_icmp_targets

  # Home Assistant Prometheus scraping — set token to enable the HA scrape job
  homeassistant_token = var.homeassistant_token
}

# Wait for Prometheus CRDs to be available
resource "time_sleep" "wait_for_prometheus_crds" {
  count           = var.enable_k8s_cluster && var.k8s_enable_monitoring && var.loki_enabled ? 1 : 0
  depends_on      = [module.prometheus_stack]
  create_duration = "60s"
}

# Monitoring integrations (ServiceMonitors after CRDs are ready)
module "monitoring_integrations" {
  count      = var.enable_k8s_cluster && var.k8s_enable_monitoring ? 1 : 0
  source     = "./modules/monitoring-integrations"
  depends_on = [time_sleep.wait_for_prometheus_crds]

  providers = {
    kubernetes = kubernetes.k3s
  }

  namespace             = var.k8s_monitoring_namespace
  raspberry_pi_hostname = var.raspberry_pi_hostname

  # Integration toggles
  enable_loki_monitoring     = false # Disable until Loki is deployed
  enable_external_monitoring = true
  enable_custom_alerts       = true

  # External monitoring targets
  mac_mini_ip              = var.mac_mini_ip
  mac_mini_docker_endpoint = var.mac_mini_docker_endpoint
  pihole_port              = var.pihole_web_port
  pihole_password         = var.pihole_password
  ntopng_port              = var.ntopng_web_port
}

# Loki logging stack (after Prometheus CRDs exist)
module "loki_stack" {
  count      = var.enable_k8s_cluster && var.k8s_enable_monitoring && var.loki_enabled ? 1 : 0
  source     = "./modules/loki-stack"
  depends_on = [time_sleep.wait_for_prometheus_crds]

  providers = {
    kubernetes = kubernetes.k3s
    helm       = helm.k3s
  }

  namespace         = var.k8s_monitoring_namespace
  chart_version     = var.loki_chart_version
  storage_class     = var.k8s_storage_class
  external_hostname = var.raspberry_pi_hostname

  # Loki configuration
  loki_cpu_request    = var.monitoring_resource_limits.loki_cpu_request
  loki_cpu_limit      = var.monitoring_resource_limits.loki_cpu_limit
  loki_memory_request = var.monitoring_resource_limits.loki_memory_request
  loki_memory_limit   = var.monitoring_resource_limits.loki_memory_limit
  loki_storage_size   = var.monitoring_resource_limits.loki_storage_size
  loki_retention      = var.monitoring_resource_limits.loki_retention
  loki_port           = var.loki_port

  # Promtail configuration
  promtail_enabled        = var.promtail_enabled
  promtail_cpu_request    = var.monitoring_resource_limits.promtail_cpu_request
  promtail_cpu_limit      = var.monitoring_resource_limits.promtail_cpu_limit
  promtail_memory_request = var.monitoring_resource_limits.promtail_memory_request
  promtail_memory_limit   = var.monitoring_resource_limits.promtail_memory_limit

  # Integration with Prometheus (disabled to avoid CRD issues)
  enable_prometheus_monitoring = false
  alertmanager_url             = ""
}

# Teleport node agent — joins the Mac Mini Teleport cluster.
#
# Access strategy per service:
#   Home Assistant  → Cloudflare Zero Trust (genuine remote use, two auth layers)
#   Pi-hole         → Teleport app access (admin-only, no permanent public URL)
#   Homebridge      → Teleport app access (admin-only, no permanent public URL)
#   Music Assistant → LAN only (speakers are local; no remote use case)
#   SSH to Pi       → Teleport SSH (replaces direct SSH exposure)
module "teleport_node" {
  count  = var.enable_teleport_node ? 1 : 0
  source = "./modules/teleport-node"

  providers = {
    docker = docker.raspberry-pi
  }

  project_name           = "homelab"
  teleport_proxy_address = var.teleport_proxy_address
  auth_token             = var.teleport_auth_token
  node_name              = "raspberry-pi-5"
  enable_ssh             = true # Pi SSH tunnelled through Teleport — no direct port exposure

  # Only register admin UIs that have no business being on a public URL
  apps = {
    "pihole" = {
      uri         = "http://localhost:${var.pihole_web_port}"
      description = "Pi-hole DNS ad blocker (admin)"
    }
    "homebridge" = {
      uri         = "http://localhost:${var.homebridge_web_port}"
      description = "Homebridge HomeKit bridge (admin)"
    }
    "ntopng" = {
      uri         = "http://localhost:${var.ntopng_web_port}"
      description = "Ntopng LAN traffic analysis (admin)"
    }
  }

  hostname = var.raspberry_pi_hostname
  ssh_user = var.raspberry_pi_user
  ssh_port = var.raspberry_pi_port
  timezone = var.timezone
  log_opts = local.common_log_opts
}

module "crowdsec" {
  source = "./modules/crowdsec"

  providers = {
    docker = docker.raspberry-pi
  }

  project_name     = "homelab"
  crowdsec_version = var.crowdsec_version
  bouncer_api_key  = var.crowdsec_bouncer_api_key
  enable_bouncer   = var.crowdsec_bouncer_api_key != ""
  hostname         = var.raspberry_pi_ip
  ssh_user         = var.raspberry_pi_user
  ssh_port         = var.raspberry_pi_port
  timezone         = var.timezone
  log_opts         = local.common_log_opts
}

module "ntopng" {
  count  = var.enable_ntopng ? 1 : 0
  source = "./modules/ntopng"

  providers = {
    docker = docker.raspberry-pi
  }

  project_name  = "homelab"
  image_version = var.ntopng_image_version
  web_port      = var.ntopng_web_port
  timezone      = var.timezone
  log_opts      = local.common_log_opts
}

# Homepage ingress (when K8s is enabled) - points to existing Docker container
module "homepage_ingress" {
  count      = var.enable_k8s_cluster ? 1 : 0
  source     = "./modules/homepage-ingress"
  depends_on = [module.k3s_cluster]

  providers = {
    kubernetes = kubernetes.k3s
  }

  raspberry_pi_hostname = var.raspberry_pi_hostname
  raspberry_pi_ip       = "192.168.0.134" # Pi's actual IP address
}

module "docker_volume_backup" {
  source = "./modules/docker-volume-backup"

  providers = {
    docker = docker.raspberry-pi
  }

  # MinIO credentials already used by Velero — reuse same values
  minio_access_key = var.minio_access_key
  minio_secret_key = var.minio_secret_key
  log_opts         = local.common_log_opts
}

module "velero" {
  count      = var.enable_k8s_cluster ? 1 : 0
  source     = "./modules/velero"
  depends_on = [module.k3s_cluster]

  providers = {
    kubernetes = kubernetes.k3s
    helm       = helm.k3s
  }

  chart_version = var.velero_chart_version
  # Use LAN IP directly — Tailscale may not be available during disaster recovery
  # Module default (http://192.168.0.126:9000) is correct; mac_mini_ip is Tailscale
  minio_access_key = var.minio_access_key
  minio_secret_key = var.minio_secret_key
}

resource "null_resource" "alloy_pi_config" {
  triggers = {
    config_hash = filemd5("${path.module}/modules/grafana-alloy-pi/alloy.river")
  }

  connection {
    type        = "ssh"
    host        = var.raspberry_pi_ip
    user        = var.raspberry_pi_user
    private_key = var.pi_ssh_private_key
    port        = var.raspberry_pi_port
  }

  provisioner "remote-exec" {
    inline = ["sudo mkdir -p /opt/homelab/alloy && sudo chown ${var.raspberry_pi_user}:${var.raspberry_pi_user} /opt/homelab/alloy"]
  }

  provisioner "file" {
    source      = "${path.module}/modules/grafana-alloy-pi/alloy.river"
    destination = "/opt/homelab/alloy/alloy.river"
  }
}

module "grafana_alloy_pi" {
  source     = "./modules/grafana-alloy-pi"
  depends_on = [null_resource.alloy_pi_config]

  providers = {
    docker = docker.raspberry-pi
  }

  project_name   = "homelab"
  image_version  = var.alloy_pi_version
  prometheus_url = "http://${var.raspberry_pi_ip}:30090/api/v1/write"
  loki_url       = "http://${var.raspberry_pi_ip}:30100/loki/api/v1/push"
  log_opts       = {}
}
