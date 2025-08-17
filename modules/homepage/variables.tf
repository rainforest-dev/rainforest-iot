variable "hostname" {
  description = "Hostname of the Raspberry Pi"
  type        = string
  default     = "raspberrypi-5"
}

variable "raspberry_pi_hostname" {
  description = "Raspberry Pi hostname for allowed hosts"
  type        = string
  default     = "raspberrypi-5"
}

variable "raspberry_pi_user" {
  description = "Raspberry Pi SSH user for kubeconfig path"
  type        = string
  default     = "rainforest"
}

variable "external_port" {
  description = "External port for Homepage dashboard"
  type        = number
  default     = 80
}

variable "timezone" {
  description = "Timezone for the container"
  type        = string
  default     = "Asia/Taipei"
}

variable "log_opts" {
  description = "Logging options for the container"
  type        = map(string)
  default = {
    "max-size" = "50m"
    "max-file" = "3"
  }
}

variable "mac_mini_hostname" {
  description = "Mac Mini hostname for service discovery"
  type        = string
  default     = "rainforest-mini.local"
}

variable "mac_mini_ip" {
  description = "Mac Mini IP address for Docker connection"
  type        = string
  default     = "100.86.67.66"
}

variable "homepage_title" {
  description = "Homepage dashboard title"
  type        = string
  default     = "Rainforest IoT & Homelab Dashboard"
}

variable "homepage_enable_kubernetes_widgets" {
  description = "Enable Kubernetes cluster widgets in homepage"
  type        = bool
  default     = true
}

variable "grafana_port" {
  description = "Grafana service port"
  type        = number
  default     = 30080
}

variable "prometheus_port" {
  description = "Prometheus service port"
  type        = number
  default     = 30090
}

variable "alertmanager_port" {
  description = "AlertManager service port"
  type        = number
  default     = 30093
}

variable "memory_limit" {
  description = "Memory limit for Homepage container (MB)"
  type        = number
  default     = 256
}