variable "raspberry_pi_hostname" {
  description = "Hostname or IP address of the Raspberry Pi"
  type        = string
  default     = "raspberrypi-5"
}

variable "raspberry_pi_user" {
  description = "SSH username for Raspberry Pi connection"
  type        = string
  default     = "rainforest"
}

variable "raspberry_pi_port" {
  description = "SSH port for Raspberry Pi connection"
  type        = number
  default     = 22
}

variable "raspberry_pi_host" {
  description = "Complete SSH connection string for Raspberry Pi"
  type        = string
  default     = ""  # Will be computed from hostname, user, and port
}

variable "timezone" {
  description = "Timezone for containers"
  type        = string
  default     = "Asia/Taipei"
}

variable "homeassistant_memory" {
  description = "Memory limit for HomeAssistant container (MB)"
  type        = number
  default     = 1024
}

variable "enable_usb_devices" {
  description = "Enable USB device access for HomeAssistant (Zigbee/Z-Wave)"
  type        = bool
  default     = false
}

variable "pihole_web_port" {
  description = "External port for Pi-hole web interface"
  type        = number
  default     = 8080
}

variable "homepage_port" {
  description = "External port for Homepage dashboard"
  type        = number
  default     = 80
}

variable "openspeedtest_ports" {
  description = "External ports for OpenSpeedTest"
  type        = object({
    http = number
    https = number
  })
  default = {
    http  = 3000
    https = 3001
  }
}

variable "watchtower_poll_interval" {
  description = "Watchtower polling interval in seconds"
  type        = number
  default     = 86400  # 24 hours
}

variable "log_max_size" {
  description = "Maximum log file size"
  type        = string
  default     = "50m"
}

variable "log_max_files" {
  description = "Maximum number of log files to keep"
  type        = number
  default     = 3
}

# Kubernetes Cluster Configuration
variable "enable_k8s_cluster" {
  description = "Enable K3s cluster on Pi 5"
  type        = bool
  default     = true
}

variable "k8s_cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "rpi5-homelab"
}

# Observability Stack Configuration
variable "enable_prometheus" {
  description = "Enable Prometheus monitoring"
  type        = bool
  default     = true
}

variable "enable_loki" {
  description = "Enable Loki logging stack"
  type        = bool
  default     = true
}

variable "enable_tempo" {
  description = "Enable Tempo distributed tracing"
  type        = bool
  default     = false
}

variable "enable_mimir" {
  description = "Enable Mimir long-term metrics storage"
  type        = bool
  default     = false
}

# This variable is redefined below with detailed component settings

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  default     = "admin123"
  sensitive   = true
}

# Additional K8s configuration variables (added to existing K8s section above)
variable "k8s_enable_monitoring" {
  description = "Enable monitoring namespace and features"
  type        = bool
  default     = true
}

variable "k8s_enable_ingress" {
  description = "Enable ingress namespace and features"
  type        = bool
  default     = true
}

variable "k8s_enable_resource_quotas" {
  description = "Enable resource quotas for namespaces"
  type        = bool
  default     = true
}

variable "k8s_enable_network_policies" {
  description = "Enable network policies for security"
  type        = bool
  default     = true
}

variable "k8s_monitoring_namespace" {
  description = "Kubernetes monitoring namespace"
  type        = string
  default     = "monitoring"
}

variable "k8s_storage_class" {
  description = "Default storage class for K8s"
  type        = string
  default     = "local-path"
}

# Kubernetes connection settings
variable "k8s_config_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "k8s_config_context" {
  description = "Kubernetes context to use"
  type        = string
  default     = ""
}

variable "k8s_insecure_skip_tls_verify" {
  description = "Skip TLS verification for K8s API"
  type        = bool
  default     = false
}

# Monitoring Stack Chart Versions
variable "prometheus_chart_version" {
  description = "Version of kube-prometheus-stack Helm chart"
  type        = string
  default     = "55.5.0"
}

variable "loki_chart_version" {
  description = "Version of loki-stack Helm chart"
  type        = string
  default     = "2.9.11"
}

# Monitoring Service Ports (NodePort)
variable "prometheus_port" {
  description = "NodePort for Prometheus service"
  type        = number
  default     = 30090
}

variable "grafana_port" {
  description = "NodePort for Grafana service"
  type        = number
  default     = 30080
}

variable "alertmanager_port" {
  description = "NodePort for AlertManager service"
  type        = number
  default     = 30093
}

variable "loki_port" {
  description = "NodePort for Loki service"
  type        = number
  default     = 30100
}

# Monitoring Component Toggles
variable "grafana_enabled" {
  description = "Enable Grafana"
  type        = bool
  default     = true
}

variable "alertmanager_enabled" {
  description = "Enable AlertManager"
  type        = bool
  default     = true
}

variable "loki_enabled" {
  description = "Enable Loki logging stack"
  type        = bool
  default     = true
}

variable "promtail_enabled" {
  description = "Enable Promtail log collection"
  type        = bool
  default     = true
}

# Homepage Configuration Variables
variable "mac_mini_hostname" {
  description = "Mac Mini hostname for service discovery"
  type        = string
  default     = "rainforest-mini"
}

variable "homepage_show_docker_stats" {
  description = "Show Docker container statistics in homepage"
  type        = bool
  default     = true
}

variable "homepage_enable_kubernetes_widgets" {
  description = "Enable Kubernetes cluster widgets in homepage"
  type        = bool
  default     = true
}

variable "homepage_title" {
  description = "Homepage dashboard title"
  type        = string
  default     = "Rainforest IoT & Homelab Dashboard"
}

# External Monitoring Targets
variable "mac_mini_ip" {
  description = "Mac mini IP address for monitoring"
  type        = string
  default     = "100.86.67.66"
}

variable "mac_mini_docker_endpoint" {
  description = "Mac mini Docker endpoint for monitoring"
  type        = string
  default     = "dockerproxy.orb.local:2375"
}

variable "pihole_api_token" {
  description = "Pi-hole API token for metrics"
  type        = string
  default     = ""
  sensitive   = true
}

# Detailed Resource Limits for All Components
variable "monitoring_resource_limits" {
  description = "Detailed resource limits for all monitoring components"
  type = object({
    # Prometheus settings
    prometheus_cpu_request    = string
    prometheus_cpu_limit      = string
    prometheus_memory_request = string
    prometheus_memory_limit   = string
    prometheus_storage_size   = string
    prometheus_retention      = string
    
    # Grafana settings
    grafana_cpu_request    = string
    grafana_cpu_limit      = string
    grafana_memory_request = string
    grafana_memory_limit   = string
    grafana_storage_size   = string
    
    # AlertManager settings
    alertmanager_cpu_request    = string
    alertmanager_cpu_limit      = string
    alertmanager_memory_request = string
    alertmanager_memory_limit   = string
    alertmanager_storage_size   = string
    
    # Loki settings
    loki_cpu_request    = string
    loki_cpu_limit      = string
    loki_memory_request = string
    loki_memory_limit   = string
    loki_storage_size   = string
    loki_retention      = string
    
    # Promtail settings
    promtail_cpu_request    = string
    promtail_cpu_limit      = string
    promtail_memory_request = string
    promtail_memory_limit   = string
  })
  default = {
    # Prometheus settings
    prometheus_cpu_request    = "200m"
    prometheus_cpu_limit      = "500m"
    prometheus_memory_request = "256Mi"
    prometheus_memory_limit   = "512Mi"
    prometheus_storage_size   = "10Gi"
    prometheus_retention      = "7d"
    
    # Grafana settings
    grafana_cpu_request    = "100m"
    grafana_cpu_limit      = "200m"
    grafana_memory_request = "128Mi"
    grafana_memory_limit   = "256Mi"
    grafana_storage_size   = "2Gi"
    
    # AlertManager settings
    alertmanager_cpu_request    = "50m"
    alertmanager_cpu_limit      = "100m"
    alertmanager_memory_request = "64Mi"
    alertmanager_memory_limit   = "128Mi"
    alertmanager_storage_size   = "1Gi"
    
    # Loki settings
    loki_cpu_request    = "100m"
    loki_cpu_limit      = "300m"
    loki_memory_request = "128Mi"
    loki_memory_limit   = "512Mi"
    loki_storage_size   = "10Gi"
    loki_retention      = "168h"
    
    # Promtail settings
    promtail_cpu_request    = "50m"
    promtail_cpu_limit      = "100m"
    promtail_memory_request = "64Mi"
    promtail_memory_limit   = "128Mi"
  }
}