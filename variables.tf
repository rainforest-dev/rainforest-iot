variable "raspberry_pi_hostname" {
  description = "Hostname or IP address of the Raspberry Pi"
  type        = string
  default     = "raspberrypi-5"
}

variable "raspberry_pi_user" {
  description = "SSH username for Raspberry Pi connection"
  type        = string
  default     = "rainforest"
}

variable "raspberry_pi_port" {
  description = "SSH port for Raspberry Pi connection"
  type        = number
  default     = 22
}

variable "raspberry_pi_host" {
  description = "Complete SSH connection string for Raspberry Pi"
  type        = string
  default     = ""  # Will be computed from hostname, user, and port
}

variable "timezone" {
  description = "Timezone for containers"
  type        = string
  default     = "Asia/Taipei"
}

variable "homeassistant_memory" {
  description = "Memory limit for HomeAssistant container (MB)"
  type        = number
  default     = 1024
}

variable "enable_usb_devices" {
  description = "Enable USB device access for HomeAssistant (Zigbee/Z-Wave)"
  type        = bool
  default     = false
}

variable "pihole_web_port" {
  description = "External port for Pi-hole web interface"
  type        = number
  default     = 8080
}

variable "homepage_port" {
  description = "External port for Homepage dashboard"
  type        = number
  default     = 80
}

variable "openspeedtest_ports" {
  description = "External ports for OpenSpeedTest"
  type        = object({
    http = number
    https = number
  })
  default = {
    http  = 3000
    https = 3001
  }
}

variable "watchtower_poll_interval" {
  description = "Watchtower polling interval in seconds"
  type        = number
  default     = 86400  # 24 hours
}

variable "log_max_size" {
  description = "Maximum log file size"
  type        = string
  default     = "50m"
}

variable "log_max_files" {
  description = "Maximum number of log files to keep"
  type        = number
  default     = 3
}