variable "hostname" {
  description = "Hostname of the Raspberry Pi"
  type        = string
  default     = "raspberrypi-5"
}

variable "ports" {
  description = "External ports for OpenSpeedTest"
  type        = object({
    http  = number
    https = number
  })
  default = {
    http  = 3000
    https = 3001
  }
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
    "max-size" = "50m"
    "max-file" = "3"
  }
}