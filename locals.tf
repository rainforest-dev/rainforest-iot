locals {
  # Compute SSH connection string for Docker
  raspberry_pi_host = var.raspberry_pi_host != "" ? var.raspberry_pi_host : "ssh://${var.raspberry_pi_user}@${var.raspberry_pi_hostname}:${var.raspberry_pi_port}"
  
  # Common container environment variables
  common_env = [
    "TZ=${var.timezone}"
  ]
  
  # Common logging configuration
  common_log_opts = {
    "max-size" = var.log_max_size
    "max-file" = tostring(var.log_max_files)
  }
}