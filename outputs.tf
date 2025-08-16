# Service URLs and Access Information
output "service_urls" {
  description = "URLs to access deployed services"
  value = {
    homeassistant = module.homeassistant.service_url
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
    hostname     = var.raspberry_pi_hostname
    user         = var.raspberry_pi_user
    port         = var.raspberry_pi_port
    timezone     = var.timezone
    docker_host  = "ssh://${var.raspberry_pi_user}@${var.raspberry_pi_hostname}:${var.raspberry_pi_port}"
  }
  sensitive = false
}

# Volume Information
output "volume_info" {
  description = "Docker volume information for backups"
  value = {
    homeassistant = module.homeassistant.volume_name
    homepage      = module.homepage.volume_name
    pihole        = module.pi-hole.volume_names
  }
}