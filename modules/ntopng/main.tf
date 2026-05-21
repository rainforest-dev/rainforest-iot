resource "docker_image" "ntopng" {
  name         = "ntop/ntopng:${var.image_version}"
  keep_locally = true
}

resource "docker_volume" "ntopng_data" {
  name = "${var.project_name}-ntopng-data"
  labels {
    label = "project"
    value = var.project_name
  }
}

resource "docker_container" "ntopng" {
  name  = "${var.project_name}-ntopng"
  image = docker_image.ntopng.image_id

  restart = "unless-stopped"

  # host network mode is required to see all LAN traffic on eth0
  network_mode = "host"

  command = [
    "--interface=${var.interface}",
    "--http-port=${var.web_port}",
    "--community",
    "--disable-login=0",
    "--data-dir=/var/lib/ntopng",
  ]

  env = [
    "TZ=${var.timezone}",
  ]

  volumes {
    volume_name    = docker_volume.ntopng_data.name
    container_path = "/var/lib/ntopng"
  }

  memory = 512

  log_driver = "json-file"
  log_opts   = var.log_opts

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://localhost:${var.web_port}/"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }
}
