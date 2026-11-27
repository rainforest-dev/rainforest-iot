variable "project_name" {
  type    = string
  default = "homelab"
}

variable "image_version" {
  description = "Ntopng Docker image tag; Docker Hub publishes only latest, so it is pinned by digest"
  type        = string
  default     = "latest@sha256:39029eaa9b2d4a024aeda49f1889d822a6c72fcd8c960267181140794c1b9833"
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
