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
  default     = false # Start with false, enable when comfortable
}

variable "network_policy_ingress_cidrs" {
  description = "CIDRs allowed into the monitoring namespace: LAN, tailnet and the k3s cni0 gateway (NodePort SNAT source)"
  type        = list(string)
  default     = ["192.168.0.0/24", "100.64.0.0/10", "10.42.0.1/32"]
}

variable "restrict_egress" {
  description = "Also restrict egress from the monitoring namespace. The egress rules are incomplete, so leave false unless they are fixed"
  type        = bool
  default     = false
}

# Resource limits for monitoring namespace
variable "monitoring_cpu_limit" {
  description = "CPU limit for monitoring namespace"
  type        = string
  default     = "2000m" # 2 CPU cores
}

variable "monitoring_memory_limit" {
  description = "Memory limit for monitoring namespace"
  type        = string
  default     = "4Gi" # 4GB RAM
}

variable "monitoring_storage_limit" {
  description = "Storage limit for monitoring namespace"
  type        = string
  default     = "50Gi" # 50GB storage
}

