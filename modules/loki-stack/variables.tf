variable "namespace" {
  description = "Kubernetes namespace for Loki stack"
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "Version of loki-stack Helm chart"
  type        = string
  default     = "2.9.11"  # Stable version
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

# Loki configuration
variable "loki_cpu_request" {
  description = "Loki CPU request"
  type        = string
  default     = "100m"
}

variable "loki_cpu_limit" {
  description = "Loki CPU limit"
  type        = string
  default     = "300m"
}

variable "loki_memory_request" {
  description = "Loki memory request"
  type        = string
  default     = "128Mi"
}

variable "loki_memory_limit" {
  description = "Loki memory limit"
  type        = string
  default     = "512Mi"
}

variable "loki_storage_size" {
  description = "Loki storage size"
  type        = string
  default     = "10Gi"
}

variable "loki_retention" {
  description = "Loki log retention period"
  type        = string
  default     = "168h"  # 7 days
}

variable "loki_port" {
  description = "NodePort for Loki service"
  type        = number
  default     = 30100
}

# Promtail configuration
variable "promtail_enabled" {
  description = "Enable Promtail log collection agent"
  type        = bool
  default     = true
}

variable "promtail_cpu_request" {
  description = "Promtail CPU request"
  type        = string
  default     = "50m"
}

variable "promtail_cpu_limit" {
  description = "Promtail CPU limit"
  type        = string
  default     = "100m"
}

variable "promtail_memory_request" {
  description = "Promtail memory request"
  type        = string
  default     = "64Mi"
}

variable "promtail_memory_limit" {
  description = "Promtail memory limit"
  type        = string
  default     = "128Mi"
}

# Fluent Bit configuration (alternative to Promtail)
variable "fluent_bit_enabled" {
  description = "Enable Fluent Bit instead of Promtail"
  type        = bool
  default     = false
}

# Additional log volumes
variable "extra_log_volumes" {
  description = "Extra volumes to mount for log collection"
  type = list(object({
    name = string
    hostPath = object({
      path = string
    })
  }))
  default = []
}

variable "extra_log_volume_mounts" {
  description = "Extra volume mounts for log collection"
  type = list(object({
    name      = string
    mountPath = string
    readOnly  = bool
  }))
  default = []
}

# Monitoring integration
variable "enable_prometheus_monitoring" {
  description = "Enable Prometheus monitoring of Loki"
  type        = bool
  default     = true
}

variable "alertmanager_url" {
  description = "AlertManager URL for Loki ruler"
  type        = string
  default     = "http://prometheus-kube-prometheus-alertmanager:9093"
}

# External log sources
variable "docker_log_path" {
  description = "Docker container log path on host"
  type        = string
  default     = "/var/lib/docker/containers"
}

variable "system_log_path" {
  description = "System log path on host"
  type        = string
  default     = "/var/log"
}