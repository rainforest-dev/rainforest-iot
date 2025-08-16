output "container_id" {
  description = "Homepage container ID"
  value       = docker_container.homepage.id
}

output "container_name" {
  description = "Homepage container name"
  value       = docker_container.homepage.name
}

output "service_url" {
  description = "Homepage service URL"
  value       = "http://${var.hostname}:${var.external_port}"
}

output "volume_name" {
  description = "Homepage configuration volume name"
  value       = docker_volume.configuration.name
}

output "container_status" {
  description = "Container status information"
  value = {
    restart_policy = docker_container.homepage.restart
    memory_limit   = docker_container.homepage.memory
    external_port  = var.external_port
  }
}