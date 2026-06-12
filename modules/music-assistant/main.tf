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

      # Idempotent: skip if base_url already set to this value
      CURRENT=$($SSH "docker exec music-assistant python3 -c \"
import json
with open('/data/settings.json') as f:
    s = json.load(f)
print(s.get('core', {}).get('webserver', {}).get('values', {}).get('base_url', ''))
\"" 2>/dev/null || echo "")

      if [ "$CURRENT" = "${var.base_url}" ]; then
        echo "MA base_url already set to ${var.base_url}, skipping"
        exit 0
      fi

      $SSH "docker exec music-assistant python3 -c \"
import json
with open('/data/settings.json') as f:
    s = json.load(f)
s.setdefault('core', {}).setdefault('webserver', {}).setdefault('values', {})['base_url'] = '${var.base_url}'
with open('/data/settings.json', 'w') as f:
    json.dump(s, f, indent=2)
print('base_url set to ${var.base_url}')
\""
      $SSH "docker restart music-assistant"
      echo "MA settings.json updated and container restarted"
    BASH
  }

  depends_on = [docker_container.music_assistant]
}
