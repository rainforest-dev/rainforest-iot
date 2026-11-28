variable "site" {
  description = "Site name, attached to every series as the `site` label"
  type        = string
}

variable "remote_write_url" {
  description = "Prometheus remote_write endpoint on the Pi, reached over the tailnet"
  type        = string
}

variable "unifi_url" {
  description = "Local URL of the UniFi console (gateway) that unpoller polls"
  type        = string
}

variable "unifi_api_key" {
  description = "UniFi Network API key for unpoller; leave empty to log in with unifi_user/unifi_pass"
  type        = string
  default     = ""
  sensitive   = true
}

variable "unifi_user" {
  description = "Local View Only admin on the UniFi console, used when unifi_api_key is empty"
  type        = string
  default     = ""
}

variable "unifi_pass" {
  type      = string
  default   = ""
  sensitive = true
}

variable "snmp_v3" {
  description = "SNMPv3 user (authPriv, SHA + AES) for targets with auth = \"v3\""
  type = object({
    username      = string
    auth_password = string
    priv_password = string
  })
  default = {
    username      = ""
    auth_password = ""
    priv_password = ""
  }
  sensitive = true
}

variable "snmp_community" {
  description = "SNMP v2c community for targets with auth = \"v2\", for devices without SNMPv3"
  type        = string
  default     = ""
  sensitive   = true
}

variable "snmp_targets" {
  description = "SNMP targets: name => { address, module, auth (v3 or v2) }; names become Alloy block labels, so no hyphens"
  type = map(object({
    address = string
    module  = string
    auth    = optional(string, "v3")
  }))
  default = {}

  validation {
    condition     = alltrue([for name in keys(var.snmp_targets) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", name))])
    error_message = "snmp_targets keys must be valid Alloy identifiers (letters, digits, underscores)."
  }

  validation {
    condition     = alltrue([for t in values(var.snmp_targets) : contains(["v3", "v2"], t.auth)])
    error_message = "snmp_targets auth must be \"v3\" or \"v2\"."
  }
}

variable "isp_ping_targets" {
  description = "Hosts beyond the WAN, pinged to measure the ISP line: name => address"
  type        = map(string)
}

variable "lan_ping_targets" {
  description = "Devices on the site LAN, pinged for up/down and latency: name => address"
  type        = map(string)
  default     = {}
}

variable "node_targets" {
  description = "Hosts running node_exporter: instance name => host:port"
  type        = map(string)
  default     = {}
}

variable "alloy_version" {
  type    = string
  default = "v1.8.2"
}

variable "unpoller_version" {
  type    = string
  default = "v5.5.0"
}

variable "speedtest_exporter_version" {
  type    = string
  default = "v3.5.4"
}

variable "log_opts" {
  type = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}
