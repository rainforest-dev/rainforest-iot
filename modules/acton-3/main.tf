terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

resource "docker_image" "shareport-sync" {
  name = "mikebrady/shairport-sync:latest"
}

resource "docker_container" "acton-3" {
  image        = docker_image.shareport-sync.name
  name         = "acton-3"
  restart      = "unless-stopped"
  network_mode = "host"
  command      = ["--statistics", "-a", "Acton III"]

  devices {
    host_path = "/dev/snd"
  }

  # volumes {
  #   container_path = "/etc/shairport-sync.conf"
  #   host_path      = "/shairport-sync/shairport-sync.conf"
  #   volume_name    = var.configuration_volume_name
  # }

  log_opts = {
    "max-size" = "200k"
    "max-file" = "10"
  }
}
