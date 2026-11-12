output "container_name" {
  description = "OpenDesign container name"
  value       = docker_container.open_design.name
}

output "service_url" {
  description = "OpenDesign API and web UI URL (token required)"
  value       = "http://${var.bind_ip}:7456"
}

output "volume_name" {
  description = "OpenDesign data volume; holds a provider secret and is not backed up"
  value       = docker_volume.open_design_data.name
}
