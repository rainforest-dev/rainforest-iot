provider "docker" {
  alias = "raspberry-pi"
  host  = local.raspberry_pi_host
  
  # SSH connection configuration for reliability
  ssh_opts = ["-o", "ServerAliveInterval=30", "-o", "ServerAliveCountMax=6"]
}

# Kubernetes provider for K3s cluster
provider "kubernetes" {
  alias                  = "k3s"
  host                   = "https://${var.raspberry_pi_hostname}:6443"
  config_path            = var.k8s_config_path
  config_context         = var.k8s_config_context
  insecure               = var.k8s_insecure_skip_tls_verify
}

# Helm provider for K3s cluster
provider "helm" {
  alias = "k3s"
  kubernetes {
    host                   = "https://${var.raspberry_pi_hostname}:6443"
    config_path            = var.k8s_config_path
    config_context         = var.k8s_config_context
    insecure               = var.k8s_insecure_skip_tls_verify
  }
}

module "homeassistant" {
  source = "./modules/homeassistant"

  providers = {
    docker = docker.raspberry-pi
  }
  
  # Pass configuration variables
  hostname = var.raspberry_pi_hostname
  memory_limit = var.homeassistant_memory
  enable_usb_devices = var.enable_usb_devices
  timezone = var.timezone
  log_opts = local.common_log_opts
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
  
  hostname = var.raspberry_pi_hostname
  raspberry_pi_hostname = var.raspberry_pi_hostname
  external_port = var.homepage_port
  timezone = var.timezone
  log_opts = local.common_log_opts
}

module "watchtower" {
  source = "./modules/watchtower"

  providers = {
    docker = docker.raspberry-pi
  }
  
  poll_interval = var.watchtower_poll_interval
  timezone = var.timezone
  log_opts = local.common_log_opts
}

module "openspeedtest" {
  source = "./modules/openspeedtest"

  providers = {
    docker = docker.raspberry-pi
  }
  
  hostname = var.raspberry_pi_hostname
  ports = var.openspeedtest_ports
  timezone = var.timezone
  log_opts = local.common_log_opts
}

module "pi-hole" {
  source = "./modules/pi-hole"

  providers = {
    docker = docker.raspberry-pi
  }
  
  hostname = var.raspberry_pi_hostname
  web_port = var.pihole_web_port
  timezone = var.timezone
  log_opts = local.common_log_opts
}

# K3s Cluster configuration (when enabled)
module "k3s_cluster" {
  count  = var.enable_k8s_cluster ? 1 : 0
  source = "./modules/k3s-cluster"

  providers = {
    kubernetes = kubernetes.k3s
  }

  cluster_name = var.k8s_cluster_name
  enable_monitoring = var.k8s_enable_monitoring
  enable_ingress = var.k8s_enable_ingress
  enable_resource_quotas = var.k8s_enable_resource_quotas
  enable_network_policies = var.k8s_enable_network_policies
}

# Prometheus monitoring stack (when K8s is enabled)
module "prometheus_stack" {
  count  = var.enable_k8s_cluster && var.k8s_enable_monitoring ? 1 : 0
  source = "./modules/prometheus-stack"

  providers = {
    kubernetes = kubernetes.k3s
    helm = helm.k3s
  }

  namespace = var.k8s_monitoring_namespace
  chart_version = var.prometheus_chart_version
  storage_class = var.k8s_storage_class
  external_hostname = var.raspberry_pi_hostname

  # Prometheus configuration
  prometheus_cpu_request = var.monitoring_resource_limits.prometheus_cpu_request
  prometheus_cpu_limit = var.monitoring_resource_limits.prometheus_cpu_limit
  prometheus_memory_request = var.monitoring_resource_limits.prometheus_memory_request
  prometheus_memory_limit = var.monitoring_resource_limits.prometheus_memory_limit
  prometheus_storage_size = var.monitoring_resource_limits.prometheus_storage_size
  prometheus_retention = var.monitoring_resource_limits.prometheus_retention
  prometheus_port = var.prometheus_port

  # Grafana configuration
  grafana_enabled = var.grafana_enabled
  grafana_cpu_request = var.monitoring_resource_limits.grafana_cpu_request
  grafana_cpu_limit = var.monitoring_resource_limits.grafana_cpu_limit
  grafana_memory_request = var.monitoring_resource_limits.grafana_memory_request
  grafana_memory_limit = var.monitoring_resource_limits.grafana_memory_limit
  grafana_storage_size = var.monitoring_resource_limits.grafana_storage_size
  grafana_admin_password = var.grafana_admin_password
  grafana_port = var.grafana_port

  # AlertManager configuration
  alertmanager_enabled = var.alertmanager_enabled
  alertmanager_cpu_request = var.monitoring_resource_limits.alertmanager_cpu_request
  alertmanager_cpu_limit = var.monitoring_resource_limits.alertmanager_cpu_limit
  alertmanager_memory_request = var.monitoring_resource_limits.alertmanager_memory_request
  alertmanager_memory_limit = var.monitoring_resource_limits.alertmanager_memory_limit
  alertmanager_storage_size = var.monitoring_resource_limits.alertmanager_storage_size
  alertmanager_port = var.alertmanager_port

  # External monitoring targets
  mac_mini_ip = var.mac_mini_ip
  mac_mini_docker_endpoint = var.mac_mini_docker_endpoint
  pihole_endpoint = "${var.raspberry_pi_hostname}:${var.pihole_web_port}"
  pihole_api_token = var.pihole_api_token

  depends_on = [module.k3s_cluster]
}

# Loki logging stack (when K8s is enabled)
module "loki_stack" {
  count  = var.enable_k8s_cluster && var.k8s_enable_monitoring && var.loki_enabled ? 1 : 0
  source = "./modules/loki-stack"

  providers = {
    kubernetes = kubernetes.k3s
    helm = helm.k3s
  }

  namespace = var.k8s_monitoring_namespace
  chart_version = var.loki_chart_version
  storage_class = var.k8s_storage_class
  external_hostname = var.raspberry_pi_hostname

  # Loki configuration
  loki_cpu_request = var.monitoring_resource_limits.loki_cpu_request
  loki_cpu_limit = var.monitoring_resource_limits.loki_cpu_limit
  loki_memory_request = var.monitoring_resource_limits.loki_memory_request
  loki_memory_limit = var.monitoring_resource_limits.loki_memory_limit
  loki_storage_size = var.monitoring_resource_limits.loki_storage_size
  loki_retention = var.monitoring_resource_limits.loki_retention
  loki_port = var.loki_port

  # Promtail configuration
  promtail_enabled = var.promtail_enabled
  promtail_cpu_request = var.monitoring_resource_limits.promtail_cpu_request
  promtail_cpu_limit = var.monitoring_resource_limits.promtail_cpu_limit
  promtail_memory_request = var.monitoring_resource_limits.promtail_memory_request
  promtail_memory_limit = var.monitoring_resource_limits.promtail_memory_limit

  # Integration with Prometheus
  enable_prometheus_monitoring = true
  alertmanager_url = var.enable_k8s_cluster && var.k8s_enable_monitoring && var.alertmanager_enabled ? "http://prometheus-kube-prometheus-alertmanager:9093" : ""

  depends_on = [module.k3s_cluster, module.prometheus_stack]
}
