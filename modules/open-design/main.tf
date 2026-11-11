terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

# Holds OpenDesign's projects and its saved settings, including the model-provider
# key pasted into the UI. Deliberately absent from docker-volume-backup's allowlist.
resource "docker_volume" "open_design_data" {
  name = "open_design_data"
}

resource "docker_image" "open_design" {
  name = "ghcr.io/nexu-io/od:${var.image_version}@${var.image_digest}"
}

resource "docker_container" "open_design" {
  image   = docker_image.open_design.image_id
  name    = "open-design"
  restart = "unless-stopped"

  memory      = var.memory_limit
  memory_swap = var.memory_limit

  read_only             = true
  security_opts         = ["no-new-privileges:true"]
  must_run              = true
  destroy_grace_seconds = 30

  tmpfs = {
    "/tmp" = "rw,noexec,nosuid,size=64m"
  }

  lifecycle {
    ignore_changes = [
      memory,
      memory_swap,
      healthcheck,
    ]
    replace_triggered_by = [
      docker_image.open_design.image_id,
    ]
  }

  healthcheck {
    test         = ["CMD", "node", "-e", "fetch('http://127.0.0.1:7456/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
    interval     = "30s"
    timeout      = "5s"
    retries      = 3
    start_period = "20s"
  }

  # Published on the Pi's LAN address only. The DOCKER-USER rule from
  # ansible/playbooks/docker-user-firewall.yml narrows it further to the Mac Mini.
  ports {
    internal = 7456
    external = 7456
    ip       = var.bind_ip
  }

  env = [
    "NODE_ENV=production",
    "NODE_OPTIONS=--max-old-space-size=${var.node_heap_mb}",
    "OD_BIND_HOST=0.0.0.0",
    "OD_PORT=7456",
    "OD_WEB_PORT=7456",
    "OD_ALLOWED_ORIGINS=${join(",", var.allowed_origins)}",
    "OD_API_TOKEN=${var.api_token}",
    "TZ=${var.timezone}",
  ]

  volumes {
    container_path = "/app/.od"
    volume_name    = docker_volume.open_design_data.name
  }

  log_opts = var.log_opts
}
