variable "hostname" {
  description = "Hostname of the Raspberry Pi"
  type        = string
  default     = "raspberrypi-5"
}

variable "memory_limit" {
  description = "Memory limit for HomeAssistant container (MB)"
  type        = number
  default     = 1024
}

variable "enable_usb_devices" {
  description = "Enable USB device access for Zigbee/Z-Wave dongles"
  type        = bool
  default     = false
}

variable "enable_hacs" {
  description = "Enable HACS (Home Assistant Community Store) installation"
  type        = bool
  default     = true
}

variable "timezone" {
  description = "Timezone for the container"
  type        = string
  default     = "Asia/Taipei"
}

variable "trusted_proxies" {
  description = "CIDR ranges trusted as reverse proxies (needed when HA is behind Cloudflare Tunnel)"
  type        = list(string)
  default     = []
}

variable "ssh_user" {
  description = "SSH user for provisioning HA config on the Pi"
  type        = string
  default     = "rainforest"
}

variable "ssh_port" {
  description = "SSH port on the Pi"
  type        = number
  default     = 22
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for the Pi (must match authorized_keys on the Pi)"
  type        = string
  default     = "~/.ssh/id_ed25519.rpi5"
}

variable "log_opts" {
  description = "Logging options for the container"
  type        = map(string)
  default = {
    "max-size" = "100m"
    "max-file" = "5"
  }
}
