# Namespace information
output "monitoring_namespace" {
  description = "Monitoring namespace name"
  value       = var.enable_monitoring ? kubernetes_namespace.monitoring[0].metadata[0].name : null
}

output "ingress_namespace" {
  description = "Ingress namespace name"  
  value       = var.enable_ingress ? kubernetes_namespace.ingress[0].metadata[0].name : null
}

# Storage class information
output "default_storage_class" {
  description = "Default storage class name"
  value       = kubernetes_storage_class.local_path.metadata[0].name
}

output "monitoring_storage_class" {
  description = "Monitoring storage class name"
  value       = var.enable_monitoring ? kubernetes_storage_class.monitoring_storage[0].metadata[0].name : null
}

# Cluster information
output "cluster_info" {
  description = "K3s cluster configuration information"
  value = {
    cluster_name = var.cluster_name
    monitoring_enabled = var.enable_monitoring
    ingress_enabled = var.enable_ingress
    resource_quotas_enabled = var.enable_resource_quotas
    network_policies_enabled = var.enable_network_policies
  }
}