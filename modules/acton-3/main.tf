terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

resource "docker_volume" "shairport_sync_configuration" {
  name = "shairport_sync_configuration"
}

resource "docker_image" "alpine" {
  name = "alpine:latest"
}

resource "docker_image" "shairport-sync" {
  name = "mikebrady/shairport-sync:latest"
}

resource "docker_container" "add-configuration" {
  image    = docker_image.alpine.image_id
  name     = "add-configuration"
  command  = ["sh", "-c", "echo 'general = { volume_range_db = 60 }' > /shairport-sync/shairport-sync.conf"]
  must_run = false
  volumes {
    container_path = "/shairport-sync"
    volume_name    = docker_volume.shairport_sync_configuration.name
  }
}

resource "docker_container" "acton-3" {
  depends_on   = [docker_container.add-configuration]
  image        = docker_image.shairport-sync.image_id
  name         = "acton-3"
  restart      = "unless-stopped"
  network_mode = "host"
  command      = ["--statistics", "-a", "Acton III", "-c", "/config/shairport-sync.conf", "--", "-d", "hw:Headphones", "-c", "Headphone"]

  # Resource limits
  memory = 128
  memory_swap = 256

  # Health check for audio service
  healthcheck {
    test         = ["CMD", "pgrep", "shairport-sync"]
    interval     = "30s"
    timeout      = "5s"
    retries      = 3
    start_period = "10s"
  }

  devices {
    host_path = "/dev/snd"
  }

  volumes {
    container_path = "/config"
    volume_name    = docker_volume.shairport_sync_configuration.name
  }

  log_opts = var.log_opts
}
