# Outputs for Monitoring Integrations Module

output "loki_service_monitor_created" {
  description = "Whether Loki ServiceMonitor was created"
  value       = var.enable_loki_monitoring && length(kubernetes_manifest.loki_service_monitor) > 0
}

output "external_monitoring_enabled" {
  description = "Whether external monitoring is configured"
  value       = var.enable_external_monitoring && length(kubernetes_config_map.additional_scrape_configs) > 0
}

output "custom_alerts_enabled" {
  description = "Whether custom alerting rules are configured"
  value       = var.enable_custom_alerts && length(kubernetes_config_map.homelab_alerting_rules) > 0
}

output "monitoring_integrations_summary" {
  description = "Summary of deployed monitoring integrations"
  value = {
    namespace = var.namespace
    loki_monitoring = var.enable_loki_monitoring
    external_monitoring = var.enable_external_monitoring
    custom_alerts = var.enable_custom_alerts
    mac_mini_monitored = var.mac_mini_ip != ""
    pihole_monitored = var.pihole_api_token != ""
  }
}