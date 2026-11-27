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
    "max-file" = "3"
  }
}

variable "shairport_version" {
  description = "shairport-sync Docker image tag"
  type        = string
  default     = "5.6.3"
}
