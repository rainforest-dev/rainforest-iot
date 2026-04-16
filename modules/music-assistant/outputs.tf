output "container_id" {
  description = "Music Assistant container ID"
  value       = docker_container.music_assistant.id
}

output "container_name" {
  description = "Music Assistant container name"
  value       = docker_container.music_assistant.name
}

output "service_url" {
  description = "Music Assistant service URL"
  value       = "http://${var.hostname}:8095"
}

output "volume_name" {
  description = "Music Assistant data volume name"
  value       = docker_volume.music_assistant_data.name
}
