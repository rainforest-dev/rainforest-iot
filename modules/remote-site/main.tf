locals {
  alloy_config = templatefile("${path.module}/config.alloy.tftpl", {
    site             = var.site
    isp_ping_targets = var.isp_ping_targets
    lan_ping_targets = var.lan_ping_targets
    snmp_targets     = var.snmp_targets
  })

  unifi_auth_env = var.unifi_api_key != "" ? [
    "UP_UNIFI_DEFAULT_API_KEY=${var.unifi_api_key}",
    ] : [
    "UP_UNIFI_DEFAULT_USER=${var.unifi_user}",
    "UP_UNIFI_DEFAULT_PASS=${var.unifi_pass}",
  ]
}

resource "docker_network" "site" {
  name = "${var.site}-monitoring"
}

resource "docker_image" "alloy" {
  name         = "grafana/alloy:${var.alloy_version}"
  keep_locally = true
}

resource "docker_image" "unpoller" {
  name         = "ghcr.io/unpoller/unpoller:${var.unpoller_version}"
  keep_locally = true
}

resource "docker_image" "speedtest" {
  name         = "ghcr.io/miguelndecarvalho/speedtest-exporter:${var.speedtest_exporter_version}"
  keep_locally = true
}

resource "docker_volume" "alloy_data" {
  name = "${var.site}-alloy-data"
}

resource "docker_container" "unpoller" {
  name    = "${var.site}-unpoller"
  image   = docker_image.unpoller.image_id
  restart = "unless-stopped"

  env = concat(local.unifi_auth_env, [
    "UP_UNIFI_DEFAULT_URL=${var.unifi_url}",
    "UP_UNIFI_DEFAULT_VERIFY_SSL=false",
    "UP_UNIFI_DEFAULT_SAVE_SITES=true",
    "UP_INFLUXDB_DISABLE=true",
    "UP_PROMETHEUS_HTTP_LISTEN=0.0.0.0:9130",
    "UP_POLLER_QUIET=true",
  ])

  networks_advanced {
    name    = docker_network.site.name
    aliases = ["unpoller"]
  }

  memory   = 128
  log_opts = var.log_opts
}

resource "docker_container" "speedtest" {
  name    = "${var.site}-speedtest"
  image   = docker_image.speedtest.image_id
  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.site.name
    aliases = ["speedtest"]
  }

  memory   = 320
  log_opts = var.log_opts
}

resource "docker_container" "alloy" {
  name    = "${var.site}-alloy"
  image   = docker_image.alloy.image_id
  restart = "unless-stopped"

  command = [
    "run",
    "--server.http.listen-addr=0.0.0.0:12345",
    "--storage.path=/var/lib/alloy",
    "/etc/alloy/config.alloy",
  ]

  env = [
    "PROMETHEUS_REMOTE_WRITE_URL=${var.remote_write_url}",
    "SNMP_COMMUNITY=${var.snmp_community}",
  ]

  upload {
    file    = "/etc/alloy/config.alloy"
    content = local.alloy_config
  }

  volumes {
    volume_name    = docker_volume.alloy_data.name
    container_path = "/var/lib/alloy"
  }

  capabilities {
    add = ["NET_RAW"]
  }

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  networks_advanced {
    name    = docker_network.site.name
    aliases = ["alloy"]
  }

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://localhost:12345/-/healthy"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  memory   = 256
  log_opts = var.log_opts

  depends_on = [docker_container.unpoller, docker_container.speedtest]
}
