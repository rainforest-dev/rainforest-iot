variable "hostname" {
  description = "Hostname of the Raspberry Pi"
  type        = string
  default     = "raspberrypi-5"
}

variable "web_port" {
  description = "External port for Pi-hole web interface"
  type        = number
  default     = 8080
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