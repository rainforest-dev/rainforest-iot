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

variable "image_version" {
  description = "Pi-hole Docker image version"
  type        = string
  default     = "2026.05.0"
}

variable "ssh_user" {
  description = "SSH user for Raspberry Pi"
  type        = string
  default     = "rainforest"
}

variable "ssh_port" {
  description = "SSH port for Raspberry Pi"
  type        = number
  default     = 22
}

variable "blocklists" {
  description = "Additional threat blocklist URLs to add to Pi-hole gravity database"
  type        = list(string)
  default = [
    "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt",
    "https://big.oisd.nl/",
    "https://openphish.com/feed.txt",
  ]
}