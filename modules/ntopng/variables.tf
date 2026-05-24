variable "project_name" {
  type    = string
  default = "homelab"
}

variable "image_version" {
  description = "Ntopng Docker image version tag"
  type        = string
  default     = "latest"
}

variable "timezone" {
  type    = string
  default = "Asia/Taipei"
}

variable "log_opts" {
  type = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}

variable "web_port" {
  description = "Ntopng web UI port"
  type        = number
  default     = 3001
}

variable "interface" {
  description = "Network interface to monitor (must match RPi eth0 name)"
  type        = string
  default     = "eth0"
}
