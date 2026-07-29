terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

resource "docker_volume" "music_assistant_data" {
  name = "music_assistant_data"
}

resource "docker_image" "music_assistant" {
  name = "ghcr.io/music-assistant/server:stable"
}

resource "docker_container" "music_assistant" {
  image        = docker_image.music_assistant.image_id
  name         = "music-assistant"
  restart      = "unless-stopped"
  network_mode = "host"

  # Resource limits for stability
  memory      = var.memory_limit
  memory_swap = var.memory_limit * 2

  # Lifecycle management to prevent unnecessary recreation
  lifecycle {
    ignore_changes = [
      memory,
      memory_swap,
      # Docker normalises "60s" → "1m0s"; ignore to prevent perpetual in-place diff
      healthcheck,
    ]
    replace_triggered_by = [
      docker_image.music_assistant.image_id,
    ]
  }

  # Health check — image has no curl, use wget via CMD-SHELL
  healthcheck {
    test         = ["CMD-SHELL", "wget -qO- http://localhost:8095/ > /dev/null"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "60s"
  }

  # Capabilities required for AirPlay/DLNA discovery
  capabilities {
    add = ["SYS_ADMIN", "DAC_READ_SEARCH"]
  }

  # Environment variables
  env = [
    "TZ=${var.timezone}",
    "LOG_LEVEL=${var.log_level}",
  ]

  # Data volume
  volumes {
    container_path = "/data"
    volume_name    = docker_volume.music_assistant_data.name
  }

  # Logging configuration
  log_opts = var.log_opts
}

resource "null_resource" "ma_base_url_config" {
  count = var.base_url != "" ? 1 : 0

  triggers = {
    container_id = docker_container.music_assistant.id
    base_url     = var.base_url
  }

  provisioner "local-exec" {
    command = <<-BASH
      set -e
      SSH="ssh -i ${var.ssh_private_key_path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -p ${var.ssh_port} ${var.ssh_user}@${var.hostname}"

      # Stop MA so its graceful shutdown writes settings.json first,
      # then we patch the volume before MA starts — preventing the
      # shutdown overwrite from clobbering our change.
      $SSH "docker stop music-assistant"

      # Patch settings.json via a temp container reusing the already-pulled
      # MA image, so no extra pull is needed.
      $SSH "docker run --rm --entrypoint python3 -v music_assistant_data:/data \
        ghcr.io/music-assistant/server:stable \
        -c \"
import json
with open('/data/settings.json') as f:
    s = json.load(f)
current = s.get('core', {}).get('webserver', {}).get('values', {}).get('base_url', '')
if current == '${var.base_url}':
    print('base_url already set, skipping')
else:
    s.setdefault('core', {}).setdefault('webserver', {})['values'] = {'base_url': '${var.base_url}'}
    s['core']['webserver']['domain'] = 'webserver'
    s['core']['webserver']['last_error'] = None
    with open('/data/settings.json', 'w') as f:
        json.dump(s, f, indent=2)
    print('base_url set to ${var.base_url}')
\""

      $SSH "docker start music-assistant"
      echo "MA settings.json patched and container started"
    BASH
  }

  depends_on = [docker_container.music_assistant]
}
