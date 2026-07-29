# ─── Decision: KEEP homebridge (Theme C, Component 2 · 2026-07-27) ───────────
# Scope: a single-purpose bridge — one plugin (homebridge-wol) exposing one
# Wake-on-LAN "NetworkDevice" accessory to Apple HomeKit / Siri. That's all it does.
#
# Why not fold it into Home Assistant: HA's native HomeKit bridge (`homekit:`) is
# NOT enabled, and enabling it just to absorb one WoL accessory adds a re-pairing
# surface and more moving parts for zero functional gain. This is one tiny,
# reliable container (Up 11+ days) doing one thing HA does not currently do.
#
# Revisit if: HA's HomeKit bridge gets adopted for other reasons (then migrate the
# WoL accessory and retire this), or the WoL need disappears.
terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

resource "docker_volume" "homebridge_data" {
  name = "homebridge_data"
}

resource "docker_image" "homebridge" {
  name = "homebridge/homebridge:${var.image_version}"
}

resource "docker_container" "homebridge" {
  image        = docker_image.homebridge.image_id
  name         = "homebridge"
  restart      = "unless-stopped"
  network_mode = "host"

  # Resource limits for stability
  memory      = var.memory_limit
  memory_swap = var.memory_limit * 2

  # Lifecycle management to prevent unnecessary recreation
  lifecycle {
    ignore_changes = [
      # Ignore Docker-managed attributes that don't affect functionality
      memory,
      memory_swap,
      # Docker normalises "60s" → "1m0s"; ignore to prevent perpetual in-place diff
      healthcheck,
    ]
    replace_triggered_by = [
      docker_image.homebridge.image_id,
    ]
  }

  # Environment variables
  env = [
    "TZ=${var.timezone}",
    "PGID=1000",
    "PUID=1000",
    "HOMEBRIDGE_CONFIG_UI=1",
    "HOMEBRIDGE_CONFIG_UI_PORT=${var.web_port}",
    "HOMEBRIDGE_INSECURE=1" # Allow setup mode for easier initial configuration
  ]

  # Health check for Homebridge web UI
  healthcheck {
    test         = ["CMD", "curl", "-f", "http://localhost:${var.web_port}/"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "60s"
  }

  # Security capabilities instead of privileged mode
  capabilities {
    add = ["NET_ADMIN", "NET_RAW"]
  }

  # Volume mounts
  volumes {
    container_path = "/homebridge"
    volume_name    = docker_volume.homebridge_data.name
  }

  volumes {
    container_path = "/etc/localtime"
    host_path      = "/etc/localtime"
    read_only      = true
  }

  # Logging configuration
  log_opts = var.log_opts
}

# UFW firewall rule for Homebridge web UI port - Managed manually for now
# resource "null_resource" "homebridge_firewall_rule" {
#   # Trigger when the container is created or when port changes
#   triggers = {
#     container_id = docker_container.homebridge.id
#     web_port     = var.web_port
#     pi_hostname  = var.pi_hostname
#     pi_user      = var.pi_user
#     pi_port      = var.pi_port
#   }
# 
#   # Add UFW rule for Homebridge web UI port
#   provisioner "remote-exec" {
#     inline = [
#       "sudo ufw allow ${var.web_port}/tcp comment 'Homebridge Web UI'",
#       "echo 'Firewall rule added for Homebridge port ${var.web_port}'"
#     ]
# 
#     connection {
#       type        = "ssh"
#       host        = var.pi_hostname
#       user        = var.pi_user
#       port        = var.pi_port
#       agent       = true
#       timeout     = "60s"
#     }
#   }
# 
#   # Remove UFW rule when destroyed
#   provisioner "remote-exec" {
#     when = destroy
#     inline = [
#       "sudo ufw delete allow ${self.triggers.web_port}/tcp || echo 'Rule already deleted'",
#       "echo 'Firewall rule removed for Homebridge port ${self.triggers.web_port}'"
#     ]
# 
#     connection {
#       type        = "ssh"
#       host        = self.triggers.pi_hostname
#       user        = self.triggers.pi_user
#       port        = self.triggers.pi_port
#       agent       = true
#       timeout     = "60s"
#     }
#   }
# 
#   depends_on = [docker_container.homebridge]
# }
