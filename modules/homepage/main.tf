terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

# Generate configuration files from templates
locals {
  template_vars = {
    mac_mini_hostname     = var.mac_mini_hostname
    raspberry_pi_hostname = var.raspberry_pi_hostname
    homepage_title        = var.homepage_title
    grafana_port         = var.grafana_port
    prometheus_port      = var.prometheus_port
    alertmanager_port    = var.alertmanager_port
    homepage_enable_kubernetes_widgets = var.homepage_enable_kubernetes_widgets
  }
  
  # Build directory for generated files
  build_dir = "${path.root}/build/homepage"
}

# Ensure build directory exists
resource "null_resource" "create_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.build_dir}"
  }
}

resource "local_file" "services_config" {
  content = templatefile("${path.module}/templates/services.yaml.tpl", local.template_vars)
  filename = "${local.build_dir}/services.yaml"
  depends_on = [null_resource.create_build_dir]
}

resource "local_file" "docker_config" {
  content = templatefile("${path.module}/templates/docker.yaml.tpl", local.template_vars)
  filename = "${local.build_dir}/docker.yaml"
  depends_on = [null_resource.create_build_dir]
}

resource "local_file" "settings_config" {
  content = templatefile("${path.module}/templates/settings.yaml.tpl", local.template_vars)
  filename = "${local.build_dir}/settings.yaml"
  depends_on = [null_resource.create_build_dir]
}

resource "local_file" "widgets_config" {
  content = templatefile("${path.module}/templates/widgets.yaml.tpl", local.template_vars)
  filename = "${local.build_dir}/widgets.yaml"
  depends_on = [null_resource.create_build_dir]
}

resource "local_file" "kubernetes_config" {
  content = templatefile("${path.module}/templates/kubernetes.yaml.tpl", local.template_vars)
  filename = "${local.build_dir}/kubernetes.yaml"
  depends_on = [null_resource.create_build_dir]
}

# Copy static configuration files to build directory
resource "local_file" "bookmarks_config" {
  content = file("${path.module}/static/bookmarks.yaml")
  filename = "${local.build_dir}/bookmarks.yaml"
  depends_on = [null_resource.create_build_dir]
}


# Create volume for Homepage configuration
resource "docker_volume" "configuration" {
  name = "homepage_configuration"
}

# Homepage Docker image
resource "docker_image" "homepage" {
  name = "ghcr.io/gethomepage/homepage:latest"
}

# Helper container to create configs directly in volume
resource "docker_container" "config_updater" {
  image    = "alpine:latest"
  name     = "homepage-config-updater"
  must_run = false
  
  command = [
    "sh", "-c", 
    <<-EOF
    echo '${base64encode(local_file.services_config.content)}' | base64 -d > /target/services.yaml &&
    echo '${base64encode(local_file.docker_config.content)}' | base64 -d > /target/docker.yaml &&
    echo '${base64encode(local_file.settings_config.content)}' | base64 -d > /target/settings.yaml &&
    echo '${base64encode(local_file.widgets_config.content)}' | base64 -d > /target/widgets.yaml &&
    echo '${base64encode(local_file.kubernetes_config.content)}' | base64 -d > /target/kubernetes.yaml &&
    echo '${base64encode(local_file.bookmarks_config.content)}' | base64 -d > /target/bookmarks.yaml &&
    chmod 644 /target/*.yaml &&
    ls -la /target/
    EOF
  ]

  volumes {
    container_path = "/target"
    volume_name    = docker_volume.configuration.name
  }

  depends_on = [
    local_file.services_config,
    local_file.docker_config,
    local_file.settings_config,
    local_file.widgets_config,
    local_file.kubernetes_config,
    local_file.bookmarks_config
  ]
}

resource "docker_container" "homepage" {
  depends_on = [docker_container.config_updater]
  image      = docker_image.homepage.image_id
  name       = "homepage"
  restart    = "unless-stopped"

  # Resource limits
  memory = var.memory_limit
  memory_swap = var.memory_limit * 2

  # Lifecycle management - recreate when config updater runs
  lifecycle {
    replace_triggered_by = [
      docker_container.config_updater.id
    ]
  }

  # Environment variables for host validation
  env = [
    "TZ=${var.timezone}",
    "HOMEPAGE_VAR_TITLE=IoT Dashboard",
    "HOMEPAGE_VAR_SEARCH_PROVIDER=duckduckgo",
    "HOMEPAGE_VAR_HEADER_STYLE=clean",
    "HOMEPAGE_VAR_DISABLE_GUEST=false",
    "HOMEPAGE_ALLOWED_HOSTS=raspberrypi-5,raspberrypi-5.local,${var.raspberry_pi_hostname},${var.raspberry_pi_hostname}.local"
  ]

  # Health check
  healthcheck {
    test         = ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://127.0.0.1:3000"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  ports {
    internal = 3000
    external = var.external_port
  }

  # Mount configuration volume
  volumes {
    container_path = "/app/config"
    volume_name    = docker_volume.configuration.name
  }

  # Docker socket for Docker widgets
  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
    read_only      = true
  }


  # Logging configuration
  log_opts = var.log_opts
}
