variable "nas_ssh_host" {
  description = "Teleport node address of the NAS, as written to ~/.ssh/config by `tsh config`"
  type        = string
  default     = "rainforest-nas.tp.rainforest.tools"
}

variable "nas_ssh_user" {
  description = "DSM account Teleport logs in as; it must be able to run docker"
  type        = string
}

variable "remote_write_url" {
  description = "Pi Prometheus remote_write endpoint over the tailnet"
  type        = string
  default     = "http://100.81.160.108:30090/api/v1/write"
}

variable "unifi_url" {
  type    = string
  default = "https://192.168.0.1"
}

variable "unifi_api_key" {
  description = "UniFi Network API key; leave empty to use the View Only admin below"
  type        = string
  default     = ""
  sensitive   = true
}

variable "unifi_user" {
  description = "Local View Only admin on the UCG Ultra"
  type        = string
  default     = ""
}

variable "unifi_pass" {
  type      = string
  default   = ""
  sensitive = true
}

variable "snmp_community" {
  description = "SNMP v2c community set in DSM and in the Nebula site settings"
  type        = string
  sensitive   = true
}

variable "ap_snmp_address" {
  description = "NWA130BE; the NWA50AX PRO has no SNMP and is only pinged"
  type        = string
  default     = "192.168.0.173"
}

variable "lan_ping_targets" {
  type = map(string)
  default = {
    ucg-ultra      = "192.168.0.1"
    usw-flex-xg    = "192.168.0.196"
    ap-nwa130be    = "192.168.0.173"
    ap-nwa50ax-pro = "192.168.0.54"
  }
}
