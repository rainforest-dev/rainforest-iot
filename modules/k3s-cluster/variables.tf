variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "rpi5-homelab"
}

variable "enable_monitoring" {
  description = "Enable monitoring namespace and resources"
  type        = bool
  default     = true
}

variable "enable_ingress" {
  description = "Enable ingress namespace"
  type        = bool
  default     = true
}

variable "enable_resource_quotas" {
  description = "Enable resource quotas for better resource management"
  type        = bool
  default     = true
}

variable "enable_network_policies" {
  description = "Enable network policies for enhanced security"
  type        = bool
  default     = false  # Start with false, enable when comfortable
}

# Resource limits for monitoring namespace
variable "monitoring_cpu_limit" {
  description = "CPU limit for monitoring namespace"
  type        = string
  default     = "2000m"  # 2 CPU cores
}

variable "monitoring_memory_limit" {
  description = "Memory limit for monitoring namespace"
  type        = string
  default     = "4Gi"    # 4GB RAM
}

variable "monitoring_storage_limit" {
  description = "Storage limit for monitoring namespace"
  type        = string
  default     = "50Gi"   # 50GB storage
}