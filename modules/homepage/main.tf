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
