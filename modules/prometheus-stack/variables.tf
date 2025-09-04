variable "namespace" {
  description = "Kubernetes namespace for Prometheus stack"
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "Version of kube-prometheus-stack Helm chart"
  type        = string
  default     = "55.5.0"  # Stable version
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
  type        = list(object({
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

variable "enable_custom_alerts" {
  description = "Enable custom alerting rules"
  type        = bool
  default     = true
}

# External monitoring targets
variable "mac_mini_ip" {
  description = "Mac mini IP address for monitoring"
  type        = string
  default     = "100.86.67.66"
}

variable "mac_mini_hostname" {
  description = "Mac mini hostname for monitoring"
  type        = string
  default     = "rainforest-mini.local"
}

variable "mac_mini_docker_endpoint" {
  description = "Mac mini Docker endpoint for monitoring"
  type        = string
  default     = "dockerproxy.orb.local:2375"
}

variable "pihole_endpoint" {
  description = "Pi-hole endpoint for monitoring"
  type        = string
  default     = "localhost:8080"
}

variable "pihole_api_token" {
  description = "Pi-hole API token for metrics"
  type        = string
  default     = ""
  sensitive   = true
}