resource "docker_image" "crowdsec" {
  name         = "crowdsecurity/crowdsec:${var.crowdsec_version}"
  keep_locally = true
}

resource "docker_image" "bouncer" {
  count        = var.enable_bouncer ? 1 : 0
  name         = "crowdsecurity/firewall-bouncer-iptables:${var.bouncer_version}"
  keep_locally = true
}

resource "docker_network" "crowdsec" {
  name = "${var.project_name}-crowdsec"
}

resource "docker_volume" "crowdsec_data" {
  name = "${var.project_name}-crowdsec-data"
  labels {
    label = "project"
    value = var.project_name
  }
}

resource "docker_container" "crowdsec" {
  name  = "${var.project_name}-crowdsec"
  image = docker_image.crowdsec.image_id

  restart = "unless-stopped"

  # Docker reads back several default attributes after container creation that
  # don't need to be managed by Terraform:
  #   - network_mode="bridge": Docker default; container actually uses networks_advanced
  #   - memory_swap: Docker sets to 2× memory when unspecified
  #   - healthcheck: Docker normalises "60s" → "1m0s" causing perpetual diff
  lifecycle {
    ignore_changes = [network_mode, memory_swap, healthcheck]
  }

  ports {
    internal = 6060
    external = 6060
    protocol = "tcp"
  }
  ports {
    internal = 8080
    external = 6081
    protocol = "tcp"
  }

  env = [
    "TZ=${var.timezone}",
    "COLLECTIONS=crowdsecurity/linux crowdsecurity/sshd crowdsecurity/nginx",
    "CUSTOM_HOSTNAME=${var.project_name}-crowdsec",
  ]

  dynamic "volumes" {
    for_each = var.log_paths
    content {
      host_path      = volumes.value
      container_path = volumes.value
      read_only      = true
    }
  }

  volumes {
    volume_name    = docker_volume.crowdsec_data.name
    container_path = "/var/lib/crowdsec/data"
  }

  networks_advanced {
    name = docker_network.crowdsec.name
  }

  memory = 256

  log_driver = "json-file"
  log_opts   = var.log_opts

  healthcheck {
    test         = ["CMD", "cscli", "version"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "60s"
  }
}

resource "docker_container" "crowdsec_bouncer" {
  count = var.enable_bouncer ? 1 : 0
  name  = "${var.project_name}-crowdsec-bouncer"
  image = docker_image.bouncer[0].image_id

  restart = "unless-stopped"

  capabilities {
    add = ["NET_ADMIN", "NET_RAW"]
  }

  network_mode = "host"

  env = [
    "TZ=${var.timezone}",
    "CROWDSEC_LAPI_URL=http://127.0.0.1:6081",
    "CROWDSEC_LAPI_KEY=${var.bouncer_api_key}",
    "GID=1000",
  ]

  memory = 64

  log_driver = "json-file"
  log_opts   = var.log_opts
}
