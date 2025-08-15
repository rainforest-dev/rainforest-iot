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

variable "timezone" {
  description = "Timezone for the container"
  type        = string
  default     = "Asia/Taipei"
}

variable "log_opts" {
  description = "Logging options for the container"
  type        = map(string)
  default = {
    "max-size" = "100m"
    "max-file" = "5"
  }
}