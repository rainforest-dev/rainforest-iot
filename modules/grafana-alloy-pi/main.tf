resource "docker_image" "alloy" {
  name         = "grafana/alloy:${var.image_version}"
  keep_locally = true
}

resource "docker_container" "alloy" {
  name  = "${var.project_name}-alloy-pi"
  image = docker_image.alloy.image_id

  restart = "unless-stopped"

  command = [
    "run",
    "--server.http.listen-addr=0.0.0.0:12345",
    "--storage.path=/var/lib/alloy",
    "/etc/alloy/alloy.river",
  ]

  env = [
    "PROMETHEUS_REMOTE_WRITE_URL=${var.prometheus_url}",
    "LOKI_PUSH_URL=${var.loki_url}",
  ]

  volumes {
    host_path      = "/opt/homelab/alloy/alloy.river"
    container_path = "/etc/alloy/alloy.river"
    read_only      = true
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  volumes {
    host_path      = "/var/log/pods"
    container_path = "/var/log/pods"
    read_only      = true
  }

  ports {
    internal = 12345
    external = 12346
    protocol = "tcp"
  }

  memory     = 192
  cpu_shares = 512

  log_driver = "json-file"
  log_opts   = var.log_opts

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://localhost:12345/-/healthy"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  lifecycle {
    ignore_changes = [
      # Docker normalises "30s" → "30s" but healthcheck interval representation drifts
      healthcheck,
      # Docker provider drops read_only after apply; ignore to prevent perpetual replacement
      volumes,
    ]
    replace_triggered_by = [
      docker_image.alloy.image_id,
    ]
  }
}
