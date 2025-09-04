# Service URLs
output "loki_url" {
  description = "URL to access Loki"
  value       = "http://${var.external_hostname}:${var.loki_port}"
}

output "loki_internal_url" {
  description = "Internal Loki URL for Grafana data source"
  value       = "http://loki:3100"
}

# Service information
output "service_info" {
  description = "Loki stack service information"
  value = {
    loki_port = var.loki_port
    namespace = var.namespace
    chart_version = var.chart_version
    promtail_enabled = var.promtail_enabled
    fluent_bit_enabled = var.fluent_bit_enabled
  }
}

# Resource configuration
output "resource_config" {
  description = "Resource configuration for Loki stack"
  value = {
    loki = {
      cpu_limit = var.loki_cpu_limit
      memory_limit = var.loki_memory_limit
      storage_size = var.loki_storage_size
      retention = var.loki_retention
    }
    promtail = var.promtail_enabled ? {
      cpu_limit = var.promtail_cpu_limit
      memory_limit = var.promtail_memory_limit
    } : null
  }
}

# Helm release info
output "helm_release_info" {
  description = "Helm release information"
  value = {
    name = helm_release.loki_stack.name
    namespace = helm_release.loki_stack.namespace
    chart = helm_release.loki_stack.chart
    version = helm_release.loki_stack.version
    status = helm_release.loki_stack.status
  }
}

# Grafana data source configuration
output "grafana_datasource_config" {
  description = "Loki data source configuration for Grafana"
  value = {
    name      = "Loki"
    type      = "loki"
    url       = "http://loki:3100"
    access    = "proxy"
    isDefault = false
  }
}