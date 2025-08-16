provider "docker" {
  alias = "raspberry-pi"
  host  = local.raspberry_pi_host
  
  # SSH connection configuration for reliability
  ssh_opts = ["-o", "ServerAliveInterval=30", "-o", "ServerAliveCountMax=6"]
}

module "homeassistant" {
  source = "./modules/homeassistant"

  providers = {
    docker = docker.raspberry-pi
  }
  
  # Pass configuration variables
  hostname = var.raspberry_pi_hostname
  memory_limit = var.homeassistant_memory
  enable_usb_devices = var.enable_usb_devices
  timezone = var.timezone
  log_opts = local.common_log_opts
}

# module "acton-3" {
#   source = "./modules/acton-3"

#   providers = {
#     docker = docker.raspberry-pi
#   }
  
#   timezone = var.timezone
#   log_opts = local.common_log_opts
# }

module "homepage" {
  source = "./modules/homepage"

  providers = {
    docker = docker.raspberry-pi
  }
  
  hostname = var.raspberry_pi_hostname
  raspberry_pi_hostname = var.raspberry_pi_hostname
  external_port = var.homepage_port
  timezone = var.timezone
  log_opts = local.common_log_opts
}

module "watchtower" {
  source = "./modules/watchtower"

  providers = {
    docker = docker.raspberry-pi
  }
  
  poll_interval = var.watchtower_poll_interval
  timezone = var.timezone
  log_opts = local.common_log_opts
}

module "openspeedtest" {
  source = "./modules/openspeedtest"

  providers = {
    docker = docker.raspberry-pi
  }
  
  hostname = var.raspberry_pi_hostname
  ports = var.openspeedtest_ports
  timezone = var.timezone
  log_opts = local.common_log_opts
}

module "pi-hole" {
  source = "./modules/pi-hole"

  providers = {
    docker = docker.raspberry-pi
  }
  
  hostname = var.raspberry_pi_hostname
  web_port = var.pihole_web_port
  timezone = var.timezone
  log_opts = local.common_log_opts
}
