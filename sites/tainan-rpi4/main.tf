# Separate root: the Docker provider dials the Pi 4 on every plan, through the NAS.
provider "docker" {
  host = "ssh://${var.ssh_host}"
}

locals {
  homeassistant_image = "sha256:43166a6f5ba2010ad8ffc8f8828807c0b0e1a8d29f7c40781e79ea9ffe6a1cd8"
  shairport_image     = "sha256:9d572de7223c0c8da6f7167125bfeccffd6e66a22d995c5ff478e5396361c278"
  openspeedtest_image = "sha256:0333c1099ff930817dfbd0fbf390adfbddffc4da46039db30bdc457995338117"
}

resource "docker_volume" "homeassistant_configuration" {
  name = "homeassistant_configuration"
}

resource "docker_volume" "shairport_sync_configuration" {
  name = "shairport_sync_configuration"
}

resource "docker_container" "homeassistant" {
  name         = "homeassistant"
  image        = local.homeassistant_image
  restart      = "unless-stopped"
  network_mode = "host"
  privileged   = true

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

  # Import leaves env, volumes and the provider defaults unset, which would force a replacement.
  # Remove this in the commit that upgrades the container, so the config above takes over.
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_container" "acton_3" {
  name         = "acton-3"
  image        = local.shairport_image
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

  # Import leaves env, volumes and the provider defaults unset, which would force a replacement.
  # Remove this in the commit that upgrades the container, so the config above takes over.
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_container" "openspeedtest" {
  name    = "openspeedtest"
  image   = local.openspeedtest_image
  restart = "unless-stopped"

  ports {
    internal = 3000
    external = 3000
  }

  ports {
    internal = 3001
    external = 3001
  }

  # Import leaves env, volumes and the provider defaults unset, which would force a replacement.
  # Remove this in the commit that upgrades the container, so the config above takes over.
  lifecycle {
    ignore_changes = all
  }
}
