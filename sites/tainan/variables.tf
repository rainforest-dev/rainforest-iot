variable "nas_ssh_host" {
  description = "Teleport node address of the NAS, as written to ~/.ssh/config by `tsh config`, e.g. <nas>.<teleport-proxy>"
  type        = string
}

variable "nas_ssh_user" {
  description = "DSM account Teleport logs in as; it must be able to run docker"
  type        = string
}

variable "remote_write_url" {
  description = "Pi Prometheus remote_write endpoint over the tailnet"
  type        = string
}

variable "unifi_url" {
  description = "UCG Ultra, through its gateway address on the NAS's VLAN, e.g. https://<work-vlan-gateway>"
  type        = string
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

variable "snmp_v3_username" {
  description = "SNMPv3 user set in DSM (authPriv, SHA + AES)"
  type        = string
  default     = "alloy"
}

variable "snmp_v3_auth_password" {
  type      = string
  sensitive = true
}

variable "snmp_v3_priv_password" {
  type      = string
  sensitive = true
}

variable "ap_snmp_auth" {
  description = "v3 if the Nebula site SNMP is set to the same SNMPv3 user, otherwise v2"
  type        = string
  default     = "v2"
}

variable "ap_snmp_community" {
  description = "SNMP v2c community set in the Nebula site settings, used when ap_snmp_auth is v2"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ap_snmp_address" {
  description = "NWA130BE; the NWA50AX PRO has no SNMP and is only pinged"
  type        = string
}

variable "lan_ping_targets" {
  description = "Site devices to ping: name => LAN address"
  type        = map(string)
}
