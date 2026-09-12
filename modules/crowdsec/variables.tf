variable "project_name" {
  type    = string
  default = "homelab"
}

variable "crowdsec_version" {
  description = "CrowdSec Agent image tag (a -debian variant: journald acquisition needs journalctl)"
  type        = string
  default     = "v1.8.1-debian"
}

variable "bouncer_version" {
  description = "CrowdSec Firewall Bouncer image version"
  type        = string
  default     = "v0.0.29"
}

variable "bouncer_api_key" {
  description = "CrowdSec LAPI key for the firewall bouncer"
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_bouncer" {
  description = "Enable native iptables bouncer (installed via apt on the Pi host)"
  type        = bool
  default     = false
}

variable "hostname" {
  description = "Hostname or IP of the Raspberry Pi for SSH bouncer install"
  type        = string
  default     = "raspberrypi-5.local"
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

variable "whitelist_cidrs" {
  description = "CIDRs never banned by local detections, on top of the built-in crowdsecurity/whitelists (RFC1918, loopback)"
  type        = list(string)
  default     = ["100.64.0.0/10", "fd7a:115c:a1e0::/48"]
}
