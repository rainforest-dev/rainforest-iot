output "container_id" {
  description = "Pi-hole container ID"
  value       = docker_container.pihole.id
}

output "container_name" {
  description = "Pi-hole container name"
  value       = docker_container.pihole.name
}

output "service_url" {
  description = "Pi-hole admin interface URL"
  value       = "http://${var.hostname}:${var.web_port}/admin"
}

output "volume_names" {
  description = "Pi-hole volume names"
  value = {
    config = docker_volume.pihole.name
    dnsmasq = docker_volume.dnsmasq.name
  }
}

output "container_status" {
  description = "Container status information"
  value = {
    restart_policy = docker_container.pihole.restart
    memory_limit   = docker_container.pihole.memory
    dns_ports      = [53]
    web_port       = var.web_port
  }
}