terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

resource "docker_volume" "pihole" {
  name = "pihole"
}

resource "docker_volume" "dnsmasq" {
  name = "pihole_dnsmasq"
}

resource "docker_container" "pihole" {
  image   = "pihole/pihole:latest"
  name    = "pihole"
  restart = "unless-stopped"
  env     = ["TZ=Asia/Taipei"]
  # capabilities {
  #   add = ["NET_ADMIN"]
  # }
  ports {
    internal = 53
    external = 53
  }
  ports {
    internal = 53
    external = 53
    protocol = "udp"
  }
  ports {
    internal = 67
    external = 67
    protocol = "udp"
  }
  ports {
    internal = 80
    external = 80
  }
  volumes {
    container_path = "/etc/pihole"
    volume_name    = docker_volume.pihole.name
  }
  volumes {
    container_path = "/etc/dnsmasq.d"
    volume_name    = docker_volume.dnsmasq.name
  }
}
