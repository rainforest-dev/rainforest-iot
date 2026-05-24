variable "project_name" {
  type    = string
  default = "homelab"
}

variable "crowdsec_version" {
  description = "CrowdSec Agent image version"
  type        = string
  default     = "v1.6.3"
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
  description = "Enable firewall bouncer container (requires Docker Hub auth for CrowdSec bouncer images)"
  type        = bool
  default     = false
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
  description = "CIDRs to never block (LAN, loopback)"
  type        = list(string)
  default     = ["192.168.0.0/24", "127.0.0.1/32"]
}

variable "log_paths" {
  description = "Host log paths to monitor for intrusion signals"
  type        = list(string)
  default = [
    "/var/log/auth.log",
    "/var/log/syslog",
  ]
}
