output "container_id" {
  description = "HomeAssistant container ID"
  value       = docker_container.homeassistant.id
}

output "container_name" {
  description = "HomeAssistant container name"
  value       = docker_container.homeassistant.name
}

output "service_url" {
  description = "HomeAssistant service URL"
  value       = "http://${var.hostname}:8123"
}

output "volume_name" {
  description = "HomeAssistant configuration volume name"
  value       = docker_volume.homeassistant_configuration.name
}

output "container_status" {
  description = "Container status information"
  value = {
    restart_policy = docker_container.homeassistant.restart
    memory_limit   = docker_container.homeassistant.memory
    network_mode   = docker_container.homeassistant.network_mode
    usb_enabled    = var.enable_usb_devices
    hacs_enabled   = var.enable_hacs
  }
}
