# Separate root: the Docker provider dials the Pi 4 on every plan, through the NAS.
provider "docker" {
  host = "ssh://${var.ssh_host}"
}

resource "docker_image" "homeassistant" {
  name         = "ghcr.io/home-assistant/home-assistant:${var.homeassistant_version}"
  keep_locally = true
}

resource "docker_image" "shairport" {
  name         = "mikebrady/shairport-sync:${var.shairport_version}"
  keep_locally = true
}

resource "docker_image" "openspeedtest" {
  name         = "openspeedtest/latest:${var.openspeedtest_version}"
  keep_locally = true
}

resource "docker_volume" "homeassistant_configuration" {
  name = "homeassistant_configuration"

  lifecycle {
    prevent_destroy = true
  }
}

resource "docker_volume" "shairport_sync_configuration" {
  name = "shairport_sync_configuration"

  lifecycle {
    prevent_destroy = true
  }
}

resource "docker_container" "homeassistant" {
  name         = "homeassistant"
  image        = docker_image.homeassistant.image_id
  restart      = "unless-stopped"
  network_mode = "host"
  # Exception to the no-privileged rule; see docs/tainan-rpi4-upgrade.md
  privileged = true

  volumes {
    container_path = "/config"
    volume_name    = docker_volume.homeassistant_configuration.name
  }

  volumes {
    container_path = "/etc/localtime"
    host_path      = "/etc/localtime"
    read_only      = true
  }

  volumes {
    container_path = "/run/dbus"
    host_path      = "/run/dbus"
    read_only      = true
  }
}

resource "docker_container" "acton_3" {
  name         = "acton-3"
  image        = docker_image.shairport.image_id
  restart      = "unless-stopped"
  network_mode = "host"
  command      = ["--statistics", "-a", "Acton III", "-c", "/config/shairport-sync.conf", "--", "-d", "hw:Headphones", "-c", "Headphone"]

  devices {
    host_path      = "/dev/snd"
    container_path = "/dev/snd"
    permissions    = "rwm"
  }

  volumes {
    container_path = "/config"
    volume_name    = docker_volume.shairport_sync_configuration.name
  }

  log_driver = "json-file"
  log_opts = {
    max-file = "10"
    max-size = "200k"
  }
}

resource "docker_container" "openspeedtest" {
  name    = "openspeedtest"
  image   = docker_image.openspeedtest.image_id
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
