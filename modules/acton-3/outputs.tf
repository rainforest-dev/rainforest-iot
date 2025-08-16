output "container_id" {
  description = "Acton-3 container ID"
  value       = docker_container.acton-3.id
}

output "container_name" {
  description = "Acton-3 container name"
  value       = docker_container.acton-3.name
}

output "volume_name" {
  description = "Shairport-sync configuration volume name"
  value       = docker_volume.shairport_sync_configuration.name
}

output "container_status" {
  description = "Container status information"
  value = {
    restart_policy = docker_container.acton-3.restart
    memory_limit   = docker_container.acton-3.memory
    network_mode   = docker_container.acton-3.network_mode
  }
}