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
      # Docker normalises "60s" → "1m0s"; ignore to prevent perpetual in-place diff
      healthcheck,
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

  # Stop this container before docker-volume-backup archives /config.
  # Home Assistant uses a SQLite recorder database (home-assistant_v2.db) that
  # must be quiesced before copying to avoid a corrupt backup.
  labels {
    label = "docker-volume-backup.stop-during-backup"
    value = "true"
  }
}

# Inject HTTP proxy config so HA accepts requests forwarded by Cloudflare Tunnel.
# Appends an `http:` block only when a top-level `http:` key is not already
# present; this does not perform YAML-aware merging.
# HA is restarted only when the config was actually written.
#
# Design notes:
#  - container_id in triggers provides both correct ordering (container must
#    exist before this runs) and intentional re-run when the container is
#    replaced (e.g. after a label change). The provisioner is idempotent —
#    it exits early if the http: block is already present in the config volume.
#  - Base64 encoding avoids all SSH/shell quoting issues when transferring
#    the YAML block through ssh → docker exec layers.
#  - depends_on is intentionally omitted; triggers already enforce ordering.
resource "null_resource" "ha_proxy_config" {
  count = length(var.trusted_proxies) > 0 ? 1 : 0

  triggers = {
    trusted_proxies = join(",", var.trusted_proxies)
    # Re-run when the container is replaced so the new container always has
    # the proxy config. Since the config volume persists, the grep check will
    # find the existing block and exit early without restarting HA.
    container_id = docker_container.homeassistant.id
  }

  # Use local-exec + native ssh so ~/.ssh/config (IdentityFile, IdentitiesOnly)
  # is respected — Terraform's built-in SSH client ignores ssh_config and
  # exhausts MaxAuthTries when multiple keys are in the agent.
  provisioner "local-exec" {
    command = <<-BASH
      set -e
      # Exit early if the http: block is already present (config volume persists
      # across container recreation, so this is the common path after a redeploy).
      if ssh -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} \
          docker exec homeassistant grep -q ^http: /config/configuration.yaml 2>/dev/null; then
        echo "HA trusted proxy config already present, skipping"
        exit 0
      fi
      # Base64-encode the YAML block locally and decode+append inside the
      # container — avoids all SSH/docker-exec quoting complexity.
      BLOCK=$(printf '\nhttp:\n  use_x_forwarded_for: true\n  trusted_proxies:\n${join("", formatlist("    - %s\\n", var.trusted_proxies))}' | base64 | tr -d '\n')
      ssh -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} \
        "echo '$${BLOCK}' | base64 -d | docker exec --interactive homeassistant sh -c 'cat >> /config/configuration.yaml'"
      ssh -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} docker restart homeassistant
      echo "HA trusted proxy config written, HA restarted"
    BASH
  }
}

resource "null_resource" "ha_prometheus_config" {
  triggers = {
    container_id = docker_container.homeassistant.id
  }

  provisioner "local-exec" {
    command = <<-BASH
      set -e
      # Exit early if the prometheus: block is already present (config volume persists
      # across container recreation, so this is the common path after a redeploy).
      if ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
          -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} \
          "docker exec homeassistant grep -q '^prometheus:' /config/configuration.yaml" 2>/dev/null; then
        echo "HA prometheus config already present, skipping"
        exit 0
      fi
      # Base64-encode the YAML block locally and decode+append inside the
      # container — avoids all SSH/docker-exec quoting complexity.
      BLOCK=$(printf '\nprometheus:\n' | base64 | tr -d '\n')
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} \
        "echo '$${BLOCK}' | base64 -d | docker exec --interactive homeassistant sh -c 'cat >> /config/configuration.yaml'"
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} docker restart homeassistant
      echo "HA prometheus config written, HA restarted"
    BASH
  }

  depends_on = [null_resource.ha_proxy_config]
}

# Inject a template sensor that exports the vacuum state as a numeric value.
# HA's Prometheus integration skips the vacuum domain because its state is a
# string (docked/cleaning/returning/…). A template sensor converts it to a
# number so Prometheus can store it.
#
# State mapping:  0=unknown  1=cleaning  2=returning  3=docked  4=paused  5=idle  6=error
resource "null_resource" "ha_vacuum_template_sensor" {
  triggers = {
    container_id = docker_container.homeassistant.id
  }

  provisioner "local-exec" {
    command = <<-BASH
      set -e
      if ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
          -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} \
          "docker exec homeassistant grep -q 'roborock_state_numeric' /config/configuration.yaml" 2>/dev/null; then
        echo "HA vacuum template sensor already present, skipping"
        exit 0
      fi
      BLOCK=$(printf '\ntemplate:\n  - sensor:\n      - name: "Roborock State Numeric"\n        unique_id: roborock_state_numeric\n        icon: mdi:robot-vacuum\n        state: >\n          {%% set s = states('"'"'vacuum.roborock_qrevo_c_pro'"'"') %%}\n          {%% if s == '"'"'cleaning'"'"' %%}1{%% elif s == '"'"'returning'"'"' %%}2{%% elif s == '"'"'docked'"'"' %%}3{%% elif s == '"'"'paused'"'"' %%}4{%% elif s == '"'"'idle'"'"' %%}5{%% elif s == '"'"'error'"'"' %%}6{%% else %%}0{%% endif %%}\n' | base64 | tr -d '\n')
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} \
        "echo '$${BLOCK}' | base64 -d | docker exec --interactive homeassistant sh -c 'cat >> /config/configuration.yaml'"
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} docker restart homeassistant
      echo "HA vacuum template sensor written, HA restarted"
    BASH
  }

  depends_on = [null_resource.ha_prometheus_config]
}

# HACS (Home Assistant Community Store) installation
resource "null_resource" "hacs_installation" {
  count = var.enable_hacs ? 1 : 0

  triggers = {
    container_id = docker_container.homeassistant.id
    hacs_enabled = var.enable_hacs
  }

  # Install HACS via native ssh (avoids Terraform SSH client exhausting MaxAuthTries
  # when many keys are loaded in the agent — uses IdentitiesOnly with explicit key)
  provisioner "local-exec" {
    command = <<-BASH
      ssh -i ${var.ssh_private_key_path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} \
        "docker exec homeassistant bash -c 'if [ ! -d /config/custom_components/hacs ]; then echo Installing HACS...; cd /config && wget -O - https://get.hacs.xyz | bash -; else echo HACS already installed; fi'"
    BASH
  }

  depends_on = [docker_container.homeassistant]
}
