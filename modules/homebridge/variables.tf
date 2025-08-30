variable "hostname" {
  description = "Hostname of the Raspberry Pi"
  type        = string
  default     = "raspberrypi-5"
}

variable "pi_hostname" {
  description = "SSH hostname for Pi connection"
  type        = string
}

variable "pi_user" {
  description = "SSH user for Pi connection"
  type        = string
}

variable "pi_port" {
  description = "SSH port for Pi connection"
  type        = number
  default     = 22
}

variable "memory_limit" {
  description = "Memory limit for Homebridge container (MB)"
  type        = number
  default     = 512
}

variable "web_port" {
  description = "External port for Homebridge web interface"
  type        = number
  default     = 8581
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