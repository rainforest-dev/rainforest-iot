terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

resource "docker_volume" "pihole" {
  name = "pihole"
}

resource "docker_volume" "dnsmasq" {
  name = "pihole_dnsmasq"
}

resource "docker_image" "pihole" {
  name = "pihole/pihole:${var.image_version}"
}

resource "docker_container" "pihole" {
  image   = docker_image.pihole.image_id
  name    = "pihole"
  restart = "unless-stopped"

  # Resource limits
  memory = 512
  memory_swap = 1024

  # Lifecycle management to prevent unnecessary recreation
  lifecycle {
    ignore_changes = [
      # Ignore Docker-managed attributes that don't affect functionality
      memory,
      memory_swap,
      network_mode,
    ]
    replace_triggered_by = [
      docker_image.pihole.image_id,
    ]
  }

  # Environment variables
  env = [
    "TZ=${var.timezone}",
    "WEBPASSWORD_FILE=/run/secrets/pihole_password",
    "DNSMASQ_LISTENING=local"
  ]

  # Health check
  healthcheck {
    test         = ["CMD", "dig", "@127.0.0.1", "pi.hole", "+norecurse", "+retry=0"]
    interval     = "30s"
    timeout      = "5s"
    retries      = 3
    start_period = "60s"
  }

  # Network capabilities for DNS
  capabilities {
    add = ["NET_ADMIN", "NET_BIND_SERVICE"]
  }

  ports {
    internal = 53
    external = 53
  }
  ports {
    internal = 53
    external = 53
    protocol = "udp"
  }
  ports {
    internal = 67
    external = 67
    protocol = "udp"
  }
  ports {
    internal = 80
    external = var.web_port
  }

  volumes {
    container_path = "/etc/pihole"
    volume_name    = docker_volume.pihole.name
  }
  volumes {
    container_path = "/etc/dnsmasq.d"
    volume_name    = docker_volume.dnsmasq.name
  }

  # Logging configuration
  log_opts = var.log_opts
}

# Add threat blocklists to Pi-hole gravity database via SSH.
# Fires whenever the blocklist URLs change (triggers key).
# Uses INSERT OR IGNORE so re-runs are safe (no duplicates).
resource "null_resource" "pihole_blocklists" {
  triggers = {
    blocklists_hash = sha256(join(",", sort(var.blocklists)))
    container_id    = docker_container.pihole.id
  }

  connection {
    type  = "ssh"
    host  = var.hostname
    user  = var.ssh_user
    port  = var.ssh_port
    agent = true
  }

  provisioner "remote-exec" {
    inline = concat(
      [for url in var.blocklists : "docker exec pihole sqlite3 /etc/pihole/gravity.db \"INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('${url}', 1, 'Terraform managed');\""],
      ["docker exec pihole pihole updateGravity || docker exec pihole pihole -g || true"]
    )
  }

  depends_on = [docker_container.pihole]
}
