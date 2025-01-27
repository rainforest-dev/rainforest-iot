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

resource "docker_image" "homepage" {
  name = "ghcr.io/gethomepage/homepage:latest"
}

resource "docker_container" "homepage" {
  image = docker_image.homepage.image_id
  name  = "homepage"
  ports {
    internal = 3000
    external = 80
  }

  volumes {
    container_path = "/app/config"
    volume_name    = docker_volume.configuration.name
  }

  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
  }
}
