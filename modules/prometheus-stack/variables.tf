variable "namespace" {
  description = "Kubernetes namespace for Prometheus stack"
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "Version of kube-prometheus-stack Helm chart"
  type        = string
  default     = "55.5.0" # Stable version
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "local-path"
}

variable "external_hostname" {
  description = "External hostname for accessing services"
  type        = string
  default     = "raspberrypi-5"
}

# Prometheus configuration
variable "prometheus_cpu_request" {
  description = "Prometheus CPU request"
  type        = string
  default     = "200m"
}

variable "prometheus_cpu_limit" {
  description = "Prometheus CPU limit"
  type        = string
  default     = "500m"
}

variable "prometheus_memory_request" {
  description = "Prometheus memory request"
  type        = string
  default     = "256Mi"
}

variable "prometheus_memory_limit" {
  description = "Prometheus memory limit"
  type        = string
  default     = "512Mi"
}

variable "prometheus_storage_size" {
  description = "Prometheus storage size"
  type        = string
  default     = "10Gi"
}

variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
  default     = "7d"
}

variable "prometheus_port" {
  description = "NodePort for Prometheus service"
  type        = number
  default     = 30090
}

# Grafana configuration
variable "grafana_enabled" {
  description = "Enable Grafana"
  type        = bool
  default     = true
}

variable "grafana_cpu_request" {
  description = "Grafana CPU request"
  type        = string
  default     = "100m"
}

variable "grafana_cpu_limit" {
  description = "Grafana CPU limit"
  type        = string
  default     = "200m"
}

variable "grafana_memory_request" {
  description = "Grafana memory request"
  type        = string
  default     = "128Mi"
}

variable "grafana_memory_limit" {
  description = "Grafana memory limit"
  type        = string
  default     = "256Mi"
}

variable "grafana_storage_size" {
  description = "Grafana storage size"
  type        = string
  default     = "2Gi"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin123"
}

variable "grafana_port" {
  description = "NodePort for Grafana service"
  type        = number
  default     = 30080
}

variable "grafana_additional_datasources" {
  description = "Additional data sources for Grafana"
  type = list(object({
    name      = string
    type      = string
    url       = string
    access    = string
    isDefault = bool
  }))
  default = []
}

# AlertManager configuration
variable "alertmanager_enabled" {
  description = "Enable AlertManager"
  type        = bool
  default     = true
}

variable "alertmanager_cpu_request" {
  description = "AlertManager CPU request"
  type        = string
  default     = "50m"
}

variable "alertmanager_cpu_limit" {
  description = "AlertManager CPU limit"
  type        = string
  default     = "100m"
}

variable "alertmanager_memory_request" {
  description = "AlertManager memory request"
  type        = string
  default     = "64Mi"
}

variable "alertmanager_memory_limit" {
  description = "AlertManager memory limit"
  type        = string
  default     = "128Mi"
}

variable "alertmanager_storage_size" {
  description = "AlertManager storage size"
  type        = string
  default     = "1Gi"
}

variable "alertmanager_port" {
  description = "NodePort for AlertManager service"
  type        = number
  default     = 30093
}

# Component toggles
variable "node_exporter_enabled" {
  description = "Enable Node Exporter"
  type        = bool
  default     = true
}

variable "kube_state_metrics_enabled" {
  description = "Enable Kube State Metrics"
  type        = bool
  default     = true
}

# External monitoring targets
variable "mac_mini_ip" {
  description = "Mac mini LAN IP address for monitoring (use LAN IP, not Tailscale)"
  type        = string
  # No default: real value lives in terraform.tfvars (gitignored) so this
  # public repo does not disclose the internal network. 
}

variable "mac_mini_hostname" {
  description = "Mac mini hostname for monitoring"
  type        = string
  default     = "rainforest-mini.local"
}

variable "external_ip" {
  description = "Raspberry Pi LAN IP address. Must be a raw IP (not .local hostname) so scrape targets resolve inside K3s pods via CoreDNS."
  type        = string
  default     = ""
}

variable "homeassistant_token" {
  description = "Home Assistant long-lived access token for /api/prometheus endpoint. Leave empty to skip HA scraping."
  type        = string
  default     = ""
  sensitive   = true
}

variable "pihole_api_token" {
  description = "Pi-hole API token for metrics"
  type        = string
  default     = ""
  sensitive   = true
}

variable "blackbox_http_targets" {
  description = "HTTP/HTTPS endpoints for Blackbox Exporter to probe"
  type        = list(string)
  default = [
    # Core AI / productivity
    "https://open-webui.rainforest.tools",
    "https://n8n.rainforest.tools",
    # Media / books
    "https://calibre-web.rainforest.tools",
    # IoT / home
    "https://homeassistant.rainforest.tools",
    "https://bambii.rainforest.tools",
    # Infrastructure
    "https://whisper.rainforest.tools",
    "https://minio.rainforest.tools",
    "https://pgadmin.rainforest.tools",
  ]
}

variable "blackbox_icmp_targets" {
  description = "IP addresses for ICMP ping probes"
  type        = list(string)
  default     = ["192.168.0.1", "1.1.1.1"]
}

variable "blackbox_mcp_targets" {
  description = "MCP OAuth gateway base URLs — probed via /.well-known/oauth-authorization-server"
  type        = list(string)
  default     = []
}