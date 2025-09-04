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
    mac_mini_ip          = var.mac_mini_ip
    raspberry_pi_hostname = var.raspberry_pi_hostname
    homepage_title        = var.homepage_title
    grafana_port         = var.grafana_port
    prometheus_port      = var.prometheus_port
    alertmanager_port    = var.alertmanager_port
    homepage_enable_kubernetes_widgets = var.homepage_enable_kubernetes_widgets
  }
  
  # Build directory for generated files
  build_dir = "${path.root}/build/homepage"

  # Normalize hostnames for allowed hosts logic
  # Use split to derive the short hostname robustly (works if input is short or FQDN)
  short_hostname = element(split(".", var.raspberry_pi_hostname), 0)
  allowed_hosts  = "${local.short_hostname},${local.short_hostname}.local,${local.short_hostname}:${var.external_port},${local.short_hostname}.local:${var.external_port}"
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

# Create volume for kubeconfig with IP-based server URL
resource "docker_volume" "kubeconfig" {
  name = "homepage_kubeconfig"
}

# Homepage Docker image
resource "docker_image" "homepage" {
  name = "ghcr.io/gethomepage/homepage:latest"
}

# Copy Raspberry Pi kubeconfig content and rewrite with IP
resource "local_file" "kubeconfig_pi5_content" {
  content = replace(
    file(var.raspberry_pi_kubeconfig_path),
    "https://raspberrypi-5.local:6443",
    "https://192.168.0.134:6443"
  )
  filename = "${local.build_dir}/kubeconfig-pi5.yaml"
  depends_on = [null_resource.create_build_dir]
}

# Copy Mac Mini kubeconfig content and rewrite with IP
resource "local_file" "kubeconfig_mac_content" {
  content = replace(
    replace(
      file(var.mac_mini_kubeconfig_path),
      "https://127.0.0.1:6443",
      "https://${var.mac_mini_ip}:6443"
    ),
    "https://127.0.0.1:26443",
    "https://${var.mac_mini_ip}:26443"
  )
  filename = "${local.build_dir}/kubeconfig-mac.yaml"
  depends_on = [null_resource.create_build_dir]
}

# Helper container to create both kubeconfig files with IP instead of mDNS hostname
resource "docker_container" "kubeconfig_updater" {
  image    = "alpine:latest"
  name     = "homepage-kubeconfig-updater-${substr(md5(join("", [local_file.kubeconfig_pi5_content.content, local_file.kubeconfig_mac_content.content])), 0, 8)}"
  must_run = false
  
  command = [
    "sh", "-c", 
    <<-EOF
    echo '${base64encode(local_file.kubeconfig_pi5_content.content)}' | base64 -d > /target/kubeconfig-pi5.yaml &&
    echo '${base64encode(local_file.kubeconfig_mac_content.content)}' | base64 -d > /target/kubeconfig-mac.yaml &&
    chmod 644 /target/*.yaml &&
    echo "Kubeconfig files updated with IP addresses:" &&
    echo "Pi5 cluster:" && grep server /target/kubeconfig-pi5.yaml &&
    echo "Mac Mini cluster:" && grep server /target/kubeconfig-mac.yaml
    EOF
  ]

  volumes {
    container_path = "/target"
    volume_name    = docker_volume.kubeconfig.name
  }
  
  depends_on = [
    local_file.kubeconfig_pi5_content,
    local_file.kubeconfig_mac_content
  ]
}

# Helper container to create configs directly in volume
resource "docker_container" "config_updater" {
  image    = "alpine:latest"
  name     = "homepage-config-updater-${substr(md5(join("", [local_file.services_config.content, local_file.docker_config.content])), 0, 8)}"
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
  depends_on = [docker_container.config_updater, docker_container.kubeconfig_updater]
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
    # Allow both short hostname and .local FQDN to avoid 404 from allowed hosts check
    "HOMEPAGE_ALLOWED_HOSTS=${local.allowed_hosts}"
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

  # Kubernetes configuration for widgets (Pi 5 cluster)
  # Note: Uses rewritten kubeconfig with IP instead of mDNS hostname
  volumes {
    container_path = "/tmp/kube"
    volume_name    = "homepage_kubeconfig"
    read_only      = true
  }


  # Logging configuration
  log_opts = var.log_opts
}
