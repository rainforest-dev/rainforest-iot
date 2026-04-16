# Teleport node agent running on the Raspberry Pi
# Joins the Teleport cluster hosted on the Mac Mini (tp.<domain>)
# Registers Pi services as Teleport Applications for SSO-protected access

resource "docker_image" "teleport" {
  provider = docker

  name         = "public.ecr.aws/gravitational/teleport-distroless:${var.teleport_version}"
  keep_locally = true
}

# Config for teleport in "app" + "node" mode only (no auth/proxy)
resource "docker_container" "teleport_node" {
  provider = docker

  name    = "${var.project_name}-teleport-node"
  image   = docker_image.teleport.image_id
  restart = "unless-stopped"

  # Teleport node/app service — dials OUT to the cluster, no inbound ports needed
  command = [
    "start",
    "--config=/etc/teleport/teleport.yaml",
  ]

  env = [
    "TZ=${var.timezone}",
  ]

  # Persist node identity so it doesn't re-register on every restart
  volumes {
    volume_name    = docker_volume.teleport_data.name
    container_path = "/var/lib/teleport"
  }

  volumes {
    host_path      = "/etc/teleport"
    container_path = "/etc/teleport"
    read_only      = true
  }

  log_opts = var.log_opts

  healthcheck {
    test         = ["CMD", "teleport", "status"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  depends_on = [docker_volume.teleport_data, null_resource.teleport_config]
}

resource "docker_volume" "teleport_data" {
  provider = docker
  name     = "${var.project_name}-teleport-node-data"
}

# Write Teleport config to /etc/teleport on the Pi via SSH null_resource
resource "null_resource" "teleport_config" {
  triggers = {
    # Re-run if any config values change
    auth_token   = sha256(var.auth_token)
    proxy_addr   = var.teleport_proxy_address
    apps         = jsonencode(var.apps)
    node_name    = var.node_name
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/teleport",
      "sudo tee /etc/teleport/teleport.yaml > /dev/null <<'TELEPORT_EOF'\n${local.teleport_config_yaml}\nTELEPORT_EOF",
      "sudo chmod 600 /etc/teleport/teleport.yaml",
    ]

    connection {
      type        = "ssh"
      host        = var.hostname
      user        = var.ssh_user
      port        = var.ssh_port
      private_key = var.ssh_private_key != "" ? file(var.ssh_private_key) : null
    }
  }
}

locals {
  teleport_config_yaml = yamlencode({
    version = "v3"

    teleport = {
      nodename    = var.node_name
      data_dir    = "/var/lib/teleport"
      auth_token  = var.auth_token
      proxy_server = var.teleport_proxy_address
      log = {
        output   = "stderr"
        severity = "INFO"
      }
    }

    # Disable services not needed on the node agent
    auth_service = {
      enabled = false
    }
    proxy_service = {
      enabled = false
    }
    ssh_service = {
      enabled = var.enable_ssh
      labels = {
        env  = "homelab"
        role = "iot"
      }
    }

    # Register each Pi web service as a Teleport Application
    app_service = {
      enabled = true
      apps = [
        for name, config in var.apps : {
          name        = name
          description = config.description
          uri         = config.uri
          labels = {
            env  = "homelab"
            role = "iot"
          }
        }
      ]
    }
  })
}
