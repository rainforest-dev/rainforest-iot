variable "hostname" {
  description = "Hostname of the Raspberry Pi"
  type        = string
  default     = "raspberrypi-5"
}

variable "memory_limit" {
  description = "Memory limit for Music Assistant container (MB)"
  type        = number
  default     = 512
}

variable "timezone" {
  description = "Timezone for the container"
  type        = string
  default     = "Asia/Taipei"
}

variable "base_url" {
  description = "Public base URL for Music Assistant (used for OAuth redirects)"
  type        = string
  default     = ""
}

variable "ssh_user" {
  description = "SSH user for the Raspberry Pi"
  type        = string
  default     = "rainforest"
}

variable "ssh_port" {
  description = "SSH port for the Raspberry Pi"
  type        = number
  default     = 22
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for the Raspberry Pi"
  type        = string
  default     = "~/.ssh/id_ed25519.rpi5"
}

variable "log_opts" {
  description = "Logging options for the container"
  type        = map(string)
  default = {
    "max-size" = "100m"
    "max-file" = "5"
  }
}
