terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

resource "docker_image" "watchtower" {
  name = "containrrr/watchtower"
}

resource "docker_container" "watchtower" {
  image   = docker_image.watchtower.image_id
  name    = "watchtower"
  restart = "unless-stopped"

  # Resource limits
  memory = 128
  memory_swap = 256

  # Lifecycle management to prevent unnecessary recreation
  lifecycle {
    ignore_changes = [
      # Ignore Docker-managed attributes that don't affect functionality
      memory,
      memory_swap,
      network_mode,
      healthcheck,
    ]
    replace_triggered_by = [
      docker_image.watchtower.image_id,
    ]
  }

  # Environment variables for safer operation
  env = [
    "TZ=${var.timezone}",
    "WATCHTOWER_CLEANUP=true",
    "WATCHTOWER_POLL_INTERVAL=${var.poll_interval}",
    "WATCHTOWER_INCLUDE_STOPPED=true"
  ]

  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
    read_only      = true
  }

  # Logging configuration
  log_opts = var.log_opts
}
