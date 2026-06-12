terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

resource "docker_volume" "music_assistant_data" {
  name = "music_assistant_data"
}

resource "docker_image" "music_assistant" {
  name = "ghcr.io/music-assistant/server:stable"
}

resource "docker_container" "music_assistant" {
  image        = docker_image.music_assistant.image_id
  name         = "music-assistant"
  restart      = "unless-stopped"
  network_mode = "host"

  # Resource limits for stability
  memory      = var.memory_limit
  memory_swap = var.memory_limit * 2

  # Lifecycle management to prevent unnecessary recreation
  lifecycle {
    ignore_changes = [
      memory,
      memory_swap,
      # Docker normalises "60s" → "1m0s"; ignore to prevent perpetual in-place diff
      healthcheck,
    ]
    replace_triggered_by = [
      docker_image.music_assistant.image_id,
    ]
  }

  # Health check — image has no curl, use wget via CMD-SHELL
  healthcheck {
    test         = ["CMD-SHELL", "wget -qO- http://localhost:8095/ > /dev/null"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "60s"
  }

  # Capabilities required for AirPlay/DLNA discovery
  capabilities {
    add = ["SYS_ADMIN", "DAC_READ_SEARCH"]
  }

  # Environment variables
  env = concat(
    [
      "TZ=${var.timezone}",
    ],
    var.base_url != "" ? ["MA_SERVER_BASE_URL=${var.base_url}"] : [],
  )

  # Data volume
  volumes {
    container_path = "/data"
    volume_name    = docker_volume.music_assistant_data.name
  }

  # Logging configuration
  log_opts = var.log_opts
}
