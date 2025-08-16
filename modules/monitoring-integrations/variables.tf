# Variables for Monitoring Integrations Module

variable "namespace" {
  description = "Kubernetes namespace for monitoring resources"
  type        = string
  default     = "monitoring"
}

variable "enable_loki_monitoring" {
  description = "Enable Loki ServiceMonitor for Prometheus scraping"
  type        = bool
  default     = true
}

variable "enable_external_monitoring" {
  description = "Enable monitoring of external services (Mac Mini, Pi-hole)"
  type        = bool
  default     = true
}

variable "enable_custom_alerts" {
  description = "Enable custom homelab alerting rules"
  type        = bool
  default     = true
}

# External service configuration
variable "mac_mini_ip" {
  description = "Mac Mini IP address for monitoring"
  type        = string
  default     = ""
}

variable "mac_mini_docker_endpoint" {
  description = "Mac Mini Docker endpoint for monitoring"
  type        = string
  default     = ""
}

variable "raspberry_pi_hostname" {
  description = "Raspberry Pi hostname"
  type        = string
}

variable "pihole_port" {
  description = "Pi-hole web interface port"
  type        = number
  default     = 8080
}

variable "pihole_api_token" {
  description = "Pi-hole API token for metrics scraping"
  type        = string
  default     = ""
  sensitive   = true
}