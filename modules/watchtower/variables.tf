variable "poll_interval" {
  description = "Watchtower polling interval in seconds"
  type        = number
  default     = 86400
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
    "max-size" = "10m"
    "max-file" = "2"
  }
}