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
  image = docker_image.watchtower.image_id
  name  = "watchtower"

  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
  }
}
