variable "hostname" {
  description = "Hostname of the Raspberry Pi"
  type        = string
  default     = "raspberrypi-5"
}

variable "raspberry_pi_hostname" {
  description = "Raspberry Pi hostname for allowed hosts"
  type        = string
  default     = "raspberrypi-5"
}

variable "external_port" {
  description = "External port for Homepage dashboard"
  type        = number
  default     = 80
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