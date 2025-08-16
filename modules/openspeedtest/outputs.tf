output "container_id" {
  description = "OpenSpeedTest container ID"
  value       = docker_container.openspeedtest.id
}

output "container_name" {
  description = "OpenSpeedTest container name"
  value       = docker_container.openspeedtest.name
}

output "service_urls" {
  description = "OpenSpeedTest service URLs"
  value = {
    http  = "http://${var.hostname}:${var.ports.http}"
    https = "https://${var.hostname}:${var.ports.https}"
  }
}

output "container_status" {
  description = "Container status information"
  value = {
    restart_policy = docker_container.openspeedtest.restart
    memory_limit   = docker_container.openspeedtest.memory
    ports         = var.ports
  }
}