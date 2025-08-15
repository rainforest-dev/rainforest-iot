terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

resource "docker_image" "openspeedtest" {
  name = "openspeedtest/latest"
}

resource "docker_container" "openspeedtest" {
  image   = docker_image.openspeedtest.image_id
  name    = "openspeedtest"
  restart = "unless-stopped"

  # Resource limits
  memory = 256
  memory_swap = 512

  # Health check
  healthcheck {
    test         = ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000"]
    interval     = "60s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  ports {
    internal = 3000
    external = var.ports.http
  }

  ports {
    internal = 3001
    external = var.ports.https
  }

  # Logging configuration
  log_opts = var.log_opts
}
