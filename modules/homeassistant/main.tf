terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

resource "docker_volume" "homeassistant_configuration" {
  name = "homeassistant_configuration"
}

resource "docker_image" "homeassistant" {
  name = "ghcr.io/home-assistant/home-assistant:stable"
}

resource "docker_container" "homeassistant" {
  image        = docker_image.homeassistant.image_id
  name         = "homeassistant"
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
    ]
    replace_triggered_by = [
      docker_image.homeassistant.image_id,
    ]
  }

  # Health check
  healthcheck {
    test         = ["CMD", "curl", "-f", "http://localhost:8123/"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "60s"
  }

  # Security capabilities instead of privileged mode
  capabilities {
    add = ["NET_ADMIN", "NET_RAW", "SYS_ADMIN"]
  }

  # Environment variables for HomeAssistant
  env = [
    "TZ=${var.timezone}",
    "HACS_ENABLED=${var.enable_hacs ? "true" : "false"}"
  ]

  # USB device access for Zigbee/Z-Wave dongles
  dynamic "devices" {
    for_each = var.enable_usb_devices ? [1] : []
    content {
      host_path      = "/dev/ttyUSB0"
      container_path = "/dev/ttyUSB0"
    }
  }

  dynamic "devices" {
    for_each = var.enable_usb_devices ? [1] : []
    content {
      host_path      = "/dev/ttyACM0"
      container_path = "/dev/ttyACM0"
    }
  }

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

  # Logging configuration
  log_opts = var.log_opts
}

# Inject HTTP proxy config so HA accepts requests forwarded by Cloudflare Tunnel.
# Uses grep/printf to append an `http:` block only when a top-level `http:` key
# is not already present; this does not perform YAML-aware merging.
# HA is restarted only when the config was actually written.
resource "null_resource" "ha_proxy_config" {
  count = length(var.trusted_proxies) > 0 ? 1 : 0

  triggers = {
    trusted_proxies = join(",", var.trusted_proxies)
  }

  # Use local-exec + native ssh so ~/.ssh/config (IdentityFile, IdentitiesOnly)
  # is respected — Terraform's built-in SSH client ignores ssh_config and
  # exhausts MaxAuthTries when multiple keys are in the agent.
  provisioner "local-exec" {
    # Runs inside the HA container (has write access to /config) via docker exec.
    # Fails fast on any SSH or docker error; restarts HA only when config changed.
    command = <<-BASH
      set -e
      result=$(ssh -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} \
        docker exec homeassistant bash -c \
        'if grep -q "^http:" /config/configuration.yaml; then
           echo "present"
         else
           printf "\nhttp:\n  use_x_forwarded_for: true\n  trusted_proxies:\n${join("", formatlist("    - %s\n", var.trusted_proxies))}" >> /config/configuration.yaml
           echo "written"
         fi')
      if [ "$result" = "written" ]; then
        ssh -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} docker restart homeassistant
      fi
    BASH
  }

  depends_on = [docker_container.homeassistant]
}

# HACS (Home Assistant Community Store) installation
resource "null_resource" "hacs_installation" {
  count = var.enable_hacs ? 1 : 0

  triggers = {
    container_id = docker_container.homeassistant.id
    hacs_enabled = var.enable_hacs
  }

  # Wait for HomeAssistant to be ready
  provisioner "local-exec" {
    command = "sleep 60"
  }

  # Install HACS
  provisioner "local-exec" {
    command = <<-EOT
      docker exec homeassistant bash -c '
        if [ ! -d "/config/custom_components/hacs" ]; then
          echo "Installing HACS..."
          cd /config
          wget -O - https://get.hacs.xyz | bash -
          echo "HACS installation completed. Restart HomeAssistant to activate."
        else
          echo "HACS already installed"
        fi
      '
    EOT
  }

  depends_on = [docker_container.homeassistant]
}
