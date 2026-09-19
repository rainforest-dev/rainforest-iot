variable "project_name" {
  type    = string
  default = "homelab"
}

variable "crowdsec_version" {
  description = "CrowdSec Agent image tag (a -debian variant: journald acquisition needs journalctl)"
  type        = string
  default     = "v1.8.1-debian"
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
  description = "CIDRs never banned by local detections, on top of the built-in crowdsecurity/whitelists (RFC1918 IPv4 and ::1 only — despite claiming IPv6 coverage, it does not whitelist link-local or ULA IPv6)"
  type        = list(string)
  default     = ["100.64.0.0/10", "fd7a:115c:a1e0::/48", "fe80::/10", "fc00::/7"]
}
