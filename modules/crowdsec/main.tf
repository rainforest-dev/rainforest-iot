resource "docker_image" "crowdsec" {
  name         = "crowdsecurity/crowdsec:${var.crowdsec_version}"
  keep_locally = true
}

# Bouncer is installed natively via apt (not Docker) so it can modify host iptables.
# Docker bouncers can only affect the container's network namespace.

resource "docker_network" "crowdsec" {
  name = "${var.project_name}-crowdsec"
}

resource "docker_volume" "crowdsec_data" {
  name = "${var.project_name}-crowdsec-data"
  labels {
    label = "project"
    value = var.project_name
  }
}

resource "docker_container" "crowdsec" {
  name  = "${var.project_name}-crowdsec"
  image = docker_image.crowdsec.image_id

  restart = "unless-stopped"

  # Docker reads back several default attributes after container creation that
  # don't need to be managed by Terraform:
  #   - network_mode="bridge": Docker default; container actually uses networks_advanced
  #   - memory_swap: Docker sets to 2× memory when unspecified
  #   - healthcheck: Docker normalises "60s" → "1m0s" causing perpetual diff
  lifecycle {
    ignore_changes = [network_mode, memory_swap, healthcheck]
  }

  ports {
    internal = 6060
    external = 6060
    protocol = "tcp"
  }
  ports {
    internal = 8080
    external = 6081
    protocol = "tcp"
  }

  env = [
    "TZ=${var.timezone}",
    "COLLECTIONS=crowdsecurity/linux crowdsecurity/sshd crowdsecurity/nginx",
    "CUSTOM_HOSTNAME=${var.project_name}-crowdsec",
  ]

  dynamic "volumes" {
    for_each = var.log_paths
    content {
      host_path      = volumes.value
      container_path = volumes.value
      read_only      = true
    }
  }

  volumes {
    volume_name    = docker_volume.crowdsec_data.name
    container_path = "/var/lib/crowdsec/data"
  }

  networks_advanced {
    name = docker_network.crowdsec.name
  }

  memory = 256

  log_driver = "json-file"
  log_opts   = var.log_opts

  healthcheck {
    test         = ["CMD", "cscli", "version"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "60s"
  }
}

# Install CrowdSec firewall bouncer natively via apt.
# Runs as a systemd service on the Pi host with direct iptables access.
# Triggers re-install if the API key changes.
resource "null_resource" "crowdsec_bouncer" {
  count = var.enable_bouncer ? 1 : 0

  triggers = {
    bouncer_api_key = var.bouncer_api_key
    hostname        = var.hostname
    ssh_port        = var.ssh_port
    ssh_user        = var.ssh_user
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-BASH
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} bash << 'ENDSSH'
        set -e
        # Add CrowdSec repo if not present
        if ! dpkg -l crowdsec-firewall-bouncer-iptables &>/dev/null; then
          curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | sudo bash
          sudo apt-get install -y crowdsec-firewall-bouncer-iptables
        fi
        # Configure the bouncer API key and LAPI URL
        sudo sed -i "s|^api_key:.*|api_key: ${var.bouncer_api_key}|" /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
        sudo sed -i "s|^api_url:.*|api_url: http://127.0.0.1:6081/|" /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
        sudo systemctl enable crowdsec-firewall-bouncer
        sudo systemctl restart crowdsec-firewall-bouncer
        sudo systemctl is-active crowdsec-firewall-bouncer
ENDSSH
    BASH
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-BASH
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${self.triggers.ssh_port} ${self.triggers.ssh_user}@${self.triggers.hostname} \
        "sudo systemctl stop crowdsec-firewall-bouncer || true && sudo apt-get remove -y crowdsec-firewall-bouncer-iptables || true"
    BASH
  }

  depends_on = [docker_container.crowdsec]
}
