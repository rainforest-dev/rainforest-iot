variable "namespace" {
  description = "Kubernetes namespace for Tempo"
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "Version of the grafana/tempo Helm chart"
  type        = string
  default     = "1.24.4"
}

variable "storage_class" {
  description = "Storage class for the trace volume"
  type        = string
  default     = "local-path"
}

variable "storage_size" {
  description = "Size of the trace volume"
  type        = string
  default     = "5Gi"
}

variable "retention" {
  description = "How long Tempo keeps traces"
  type        = string
  default     = "72h"
}

variable "cpu_request" {
  description = "Tempo CPU request"
  type        = string
  default     = "50m"
}

variable "cpu_limit" {
  description = "Tempo CPU limit"
  type        = string
  default     = "500m"
}

variable "memory_request" {
  description = "Tempo memory request"
  type        = string
  default     = "128Mi"
}

variable "memory_limit" {
  description = "Tempo memory limit"
  type        = string
  default     = "512Mi"
}

variable "otlp_http_node_port" {
  description = "NodePort that exposes Tempo's OTLP/HTTP receiver on the LAN"
  type        = number
  default     = 30418
}

variable "prometheus_datasource_uid" {
  description = "Grafana UID of the Prometheus datasource, for trace-to-metrics links"
  type        = string
  default     = "prometheus"
}
