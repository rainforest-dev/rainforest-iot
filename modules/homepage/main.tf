terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

resource "docker_volume" "configuration" {
  name = "homepage_configuration"
}

resource "docker_image" "helper" {
  name         = "helper"
  keep_locally = false
  build {
    context    = "./modules/homepage"
    dockerfile = "dockerfile.helper"
  }
}

resource "docker_container" "helper" {
  image    = docker_image.helper.image_id
  name     = "helper"
  must_run = false

  volumes {
    container_path = "/data"
    volume_name    = docker_volume.configuration.name
  }
}

resource "docker_image" "homepage" {
  name = "ghcr.io/gethomepage/homepage:latest"
}

resource "docker_container" "homepage" {
  depends_on = [docker_container.helper]
  image      = docker_image.homepage.image_id
  name       = "homepage"
  restart    = "unless-stopped"

  # Resource limits
  memory = 256
  memory_swap = 512

  # Lifecycle management to prevent unnecessary recreation
  lifecycle {
    replace_triggered_by = [
      # Only recreate if image or critical config changes
      docker_image.homepage.image_id,
    ]
  }

  # Environment variables for host validation
  env = [
    "TZ=${var.timezone}",
    "HOMEPAGE_VAR_TITLE=IoT Dashboard",
    "HOMEPAGE_VAR_SEARCH_PROVIDER=duckduckgo",
    "HOMEPAGE_VAR_HEADER_STYLE=clean",
    "HOMEPAGE_VAR_DISABLE_GUEST=false",
    "HOMEPAGE_ALLOWED_HOSTS=raspberrypi-5,raspberrypi-5.local,${var.raspberry_pi_hostname},${var.raspberry_pi_hostname}.local"
  ]

  # Health check
  healthcheck {
    test         = ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  ports {
    internal = 3000
    external = var.external_port
  }

  volumes {
    container_path = "/app/config"
    volume_name    = docker_volume.configuration.name
  }

  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
    read_only      = true
  }

  # Logging configuration
  log_opts = var.log_opts
}
