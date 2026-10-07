resource "docker_image" "crowdsec" {
  name         = "crowdsecurity/crowdsec:${var.crowdsec_version}"
  keep_locally = true
}

# The firewall bouncer is installed on the host by Ansible
# (ansible/playbooks/crowdsec-bouncer.yml): it needs host iptables, and its API
# key is issued on the Pi so it never enters git.

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
    ip       = "127.0.0.1"
    protocol = "tcp"
  }

  env = [
    "TZ=${var.timezone}",
    "COLLECTIONS=crowdsecurity/linux crowdsecurity/sshd crowdsecurity/iptables crowdsecurity/nginx",
    "CUSTOM_HOSTNAME=${var.project_name}-crowdsec",
  ]

  upload {
    file    = "/etc/crowdsec/acquis.yaml"
    content = file("${path.module}/acquis.yaml")
  }

  upload {
    file = "/etc/crowdsec/parsers/s02-enrich/homelab-whitelists.yaml"
    content = yamlencode({
      name        = "homelab/whitelists"
      description = "Homelab trusted networks"
      whitelist = {
        reason = "homelab trusted network"
        cidr   = var.whitelist_cidrs
      }
    })
  }

  volumes {
    host_path      = "/var/log/journal"
    container_path = "/var/log/journal"
    read_only      = true
  }

  volumes {
    host_path      = "/etc/machine-id"
    container_path = "/etc/machine-id"
    read_only      = true
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
