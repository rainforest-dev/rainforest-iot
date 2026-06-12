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
  memory      = 512
  memory_swap = 1024

  # Lifecycle management to prevent unnecessary recreation
  lifecycle {
    ignore_changes = [
      # Ignore Docker-managed attributes that don't affect functionality
      memory,
      memory_swap,
      network_mode,
      # Docker normalises "60s" → "1m0s"; ignore to prevent perpetual in-place diff
      healthcheck,
    ]
    replace_triggered_by = [
      docker_image.pihole.image_id,
    ]
  }

  # Environment variables
  env = [
    "TZ=${var.timezone}",
    "WEBPASSWORD_FILE=/run/secrets/pihole_password",
    "DNSMASQ_LISTENING=all"
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

  # Uses native ssh with IdentitiesOnly to avoid MaxAuthTries exhaustion.
  # Writes a temp script locally and pipes it to ssh stdin in one connection.
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-BASH
      TMPSCRIPT=$(mktemp /tmp/pihole-blocklist-XXXXXX.sh)
      cat > "$TMPSCRIPT" << 'SCRIPT_EOF'
${join("\n", [for url in var.blocklists : "docker exec pihole sqlite3 /etc/pihole/gravity.db \"INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('${url}', 1, 'Terraform managed');\""])}
docker exec pihole pihole updateGravity || docker exec pihole pihole -g || true
SCRIPT_EOF
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} bash < "$TMPSCRIPT"
      rm -f "$TMPSCRIPT"
    BASH
  }

  depends_on = [docker_container.pihole]
}

# Native Pi-hole v6 Prometheus exporter — deployed as a systemd service.
# ekofr/pihole-exporter:v0.4.0 uses the removed Pi-hole v5 /admin/api.php endpoint
# and cannot be used with Pi-hole v6. This minimal Python stdlib exporter uses the
# v6 /api/ REST interface directly (no Docker Hub pull required).
resource "null_resource" "pihole_exporter" {
  triggers = {
    script_hash = sha256(local.pihole_exporter_script)
    password    = var.pihole_password
    hostname    = var.hostname
    ssh_port    = var.ssh_port
    ssh_user    = var.ssh_user
  }

  # Copy script and install systemd service
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-BASH
      TMPSCRIPT=$(mktemp /tmp/pihole-exporter-XXXXXX.py)
      cat > "$TMPSCRIPT" << 'PYEOF'
${local.pihole_exporter_script}
PYEOF
      scp -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -P ${var.ssh_port} "$TMPSCRIPT" ${var.ssh_user}@${var.hostname}:/tmp/pihole_exporter.py
      rm -f "$TMPSCRIPT"
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} bash << 'ENDSSH'
        sudo cp /tmp/pihole_exporter.py /usr/local/bin/pihole_exporter.py
        sudo chmod +x /usr/local/bin/pihole_exporter.py
        sudo tee /etc/systemd/system/pihole-exporter.service > /dev/null << 'SVC'
[Unit]
Description=Pi-hole v6 Prometheus Exporter
After=docker.service

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/pihole_exporter.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVC
        sudo systemctl daemon-reload
        sudo systemctl enable pihole-exporter
        sudo systemctl restart pihole-exporter
        sleep 3
        sudo systemctl is-active pihole-exporter
ENDSSH
    BASH
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-BASH
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${self.triggers.ssh_port} ${self.triggers.ssh_user}@${self.triggers.hostname} \
        "sudo systemctl stop pihole-exporter || true && sudo systemctl disable pihole-exporter || true && sudo rm -f /etc/systemd/system/pihole-exporter.service /usr/local/bin/pihole_exporter.py && sudo systemctl daemon-reload"
    BASH
  }

  depends_on = [docker_container.pihole]
}

# Open firewall ports for Prometheus scraping from K3s pods.
# pihole-exporter and node-exporter use network_mode=host / hostNetwork=true,
# so Docker's iptables bypass does NOT apply — UFW must explicitly allow the
# K3s pod CIDR (10.42.0.0/24) to reach these ports.
# This null_resource is idempotent: ufw add rules are silently no-ops when
# the rule already exists; deletes gracefully handle missing rules.
resource "null_resource" "monitoring_firewall_rules" {
  triggers = {
    exporter_id = null_resource.pihole_exporter.id
    hostname    = var.hostname
    ssh_port    = var.ssh_port
    ssh_user    = var.ssh_user
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-BASH
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} \
        "sudo ufw allow from 10.42.0.0/24 to any port 9617 proto tcp comment 'pihole-exporter - K3s Prometheus scraping' && \
         sudo ufw allow from 10.42.0.0/24 to any port 9100 proto tcp comment 'node-exporter - K3s Prometheus scraping' && \
         sudo ufw reload"
    BASH
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-BASH
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${self.triggers.ssh_port} ${self.triggers.ssh_user}@${self.triggers.hostname} \
        "sudo ufw delete allow from 10.42.0.0/24 to any port 9617 proto tcp || true && \
         sudo ufw delete allow from 10.42.0.0/24 to any port 9100 proto tcp || true && \
         sudo ufw reload"
    BASH
  }

  depends_on = [null_resource.pihole_exporter]
}
