variable "project_name" {
  type    = string
  default = "homelab"
}

variable "image_version" {
  description = "Grafana Alloy Docker image version"
  type        = string
  default     = "v1.8.2"
}

variable "prometheus_url" {
  description = "Local Prometheus remote_write endpoint (NodePort on Pi)"
  type        = string
  default     = "http://192.168.0.128:30090/api/v1/write"
}

variable "loki_url" {
  description = "Local Loki push endpoint (NodePort on Pi)"
  type        = string
  default     = "http://192.168.0.128:30100/loki/api/v1/push"
}

variable "log_opts" {
  type = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}
