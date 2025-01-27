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

  ports {
    internal = 3000
    external = 3000
  }

  ports {
    internal = 3001
    external = 3001
  }
}
