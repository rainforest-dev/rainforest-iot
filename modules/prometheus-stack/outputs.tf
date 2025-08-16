# Service URLs
output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = "http://${var.external_hostname}:${var.prometheus_port}"
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = var.grafana_enabled ? "http://${var.external_hostname}:${var.grafana_port}" : null
}

output "alertmanager_url" {
  description = "URL to access AlertManager"
  value       = var.alertmanager_enabled ? "http://${var.external_hostname}:${var.alertmanager_port}" : null
}

# Service information
output "service_info" {
  description = "Prometheus stack service information"
  value = {
    prometheus_port = var.prometheus_port
    grafana_port = var.grafana_enabled ? var.grafana_port : null
    alertmanager_port = var.alertmanager_enabled ? var.alertmanager_port : null
    namespace = var.namespace
    chart_version = var.chart_version
  }
}

# Resource configuration
output "resource_config" {
  description = "Resource configuration for monitoring"
  value = {
    prometheus = {
      cpu_limit = var.prometheus_cpu_limit
      memory_limit = var.prometheus_memory_limit
      storage_size = var.prometheus_storage_size
      retention = var.prometheus_retention
    }
    grafana = var.grafana_enabled ? {
      cpu_limit = var.grafana_cpu_limit
      memory_limit = var.grafana_memory_limit
      storage_size = var.grafana_storage_size
    } : null
    alertmanager = var.alertmanager_enabled ? {
      cpu_limit = var.alertmanager_cpu_limit
      memory_limit = var.alertmanager_memory_limit
      storage_size = var.alertmanager_storage_size
    } : null
  }
}

# Helm release info
output "helm_release_info" {
  description = "Helm release information"
  value = {
    name = helm_release.prometheus_stack.name
    namespace = helm_release.prometheus_stack.namespace
    chart = helm_release.prometheus_stack.chart
    version = helm_release.prometheus_stack.version
    status = helm_release.prometheus_stack.status
  }
}