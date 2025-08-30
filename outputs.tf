# Service URLs and Access Information
output "service_urls" {
  description = "URLs to access deployed services"
  value = {
    homeassistant = module.homeassistant.service_url
    homebridge    = module.homebridge.service_url
    homepage      = module.homepage.service_url
    pihole        = module.pi-hole.service_url
    openspeedtest = module.openspeedtest.service_urls
  }
}

# Container Status Information
output "container_info" {
  description = "Container names and status information"
  value = {
    homeassistant = module.homeassistant.container_status
    homebridge    = module.homebridge.container_status
    homepage      = module.homepage.container_status
    pihole        = module.pi-hole.container_status
    openspeedtest = module.openspeedtest.container_status
    watchtower    = module.watchtower.container_status
  }
}

# Connection Information
output "connection_info" {
  description = "Connection details for the Raspberry Pi"
  value = {
    hostname    = var.raspberry_pi_hostname
    user        = var.raspberry_pi_user
    port        = var.raspberry_pi_port
    timezone    = var.timezone
    docker_host = "ssh://${var.raspberry_pi_user}@${var.raspberry_pi_hostname}:${var.raspberry_pi_port}"
  }
  sensitive = false
}

# Volume Information
output "volume_info" {
  description = "Docker volume information for backups"
  value = {
    homeassistant = module.homeassistant.volume_name
    homebridge    = module.homebridge.volume_name
    homepage      = module.homepage.volume_name
    pihole        = module.pi-hole.volume_names
  }
}

# Kubernetes Service URLs (when enabled)
output "kubernetes_services" {
  description = "Kubernetes service access URLs"
  value = var.enable_k8s_cluster ? {
    prometheus   = "http://${var.raspberry_pi_hostname}:${var.prometheus_port}"
    grafana      = "http://${var.raspberry_pi_hostname}:${var.grafana_port}"
    alertmanager = "http://${var.raspberry_pi_hostname}:${var.alertmanager_port}"
    loki         = var.loki_enabled ? "http://${var.raspberry_pi_hostname}:${var.loki_port}" : null
  } : null
}

# Wake-on-LAN Configuration Info
output "wol_setup_info" {
  description = "Information for Wake-on-LAN setup"
  value = {
    instructions = "Both HomeAssistant and Homebridge support Wake-on-LAN:"
    homeassistant_methods = [
      "Built-in Wake-on-LAN integration",
      "Shell command service with wakeonlan utility",
      "Custom automation scripts"
    ]
    homebridge_methods = [
      "homebridge-wol plugin",
      "homebridge-computer plugin (includes WoL)",
      "Custom script plugins"
    ]
    requirements = [
      "Target PC must have WoL enabled in BIOS/UEFI",
      "Network adapter must support WoL",
      "PC must be connected via Ethernet (not WiFi)",
      "Need target PC's MAC address"
    ]
  }
}

# HomeKit Setup Information
output "homekit_setup_info" {
  description = "HomeKit setup instructions and access information"
  value = {
    homebridge_setup_url    = "http://${var.raspberry_pi_hostname}:${var.homebridge_web_port}"
    homeassistant_setup_url = "http://${var.raspberry_pi_hostname}:8123"
    pc_info = {
      note       = "Configure PC details (MAC address, hostname) via Homebridge web UI"
      wol_status = "✅ Wake-on-LAN enabled on rainforest-ubuntu via SSH"
    }
    setup_instructions = [
      "1. Access Homebridge web UI at the URL above",
      "2. Complete setup wizard (auto-generates secure PIN)",
      "3. Install 'homebridge-wol' plugin via web interface",
      "4. Configure PC details in plugin settings",
      "5. Scan QR code in iOS Home app to add bridge",
      "6. Your PC will appear as a HomeKit switch"
    ]
    recommended_plugins = [
      "homebridge-wol (simple wake switch)",
      "homebridge-computer (advanced PC control)"
    ]
  }
  sensitive = false
}
