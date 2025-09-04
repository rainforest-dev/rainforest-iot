output "container_id" {
  description = "Watchtower container ID"
  value       = docker_container.watchtower.id
}

output "container_name" {
  description = "Watchtower container name"
  value       = docker_container.watchtower.name
}

output "container_status" {
  description = "Container status information"
  value = {
    restart_policy = docker_container.watchtower.restart
    memory_limit   = docker_container.watchtower.memory
    poll_interval  = var.poll_interval
  }
}