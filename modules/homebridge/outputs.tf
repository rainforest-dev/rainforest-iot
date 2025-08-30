output "container_id" {
  description = "Homebridge container ID"
  value       = docker_container.homebridge.id
}

output "container_name" {
  description = "Homebridge container name"
  value       = docker_container.homebridge.name
}

output "service_url" {
  description = "Homebridge web interface URL"
  value       = "http://${var.hostname}:${var.web_port}"
}

output "volume_name" {
  description = "Homebridge data volume name"
  value       = docker_volume.homebridge_data.name
}

output "container_status" {
  description = "Container status information"
  value = {
    restart_policy = docker_container.homebridge.restart
    memory_limit   = docker_container.homebridge.memory
    network_mode   = docker_container.homebridge.network_mode
    web_port       = var.web_port
  }
}