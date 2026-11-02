variable "ssh_host" {
  description = "~/.ssh/config alias of the Pi 4; the entry holds the address and the relay through the NAS"
  type        = string
  default     = "rpi4-tainan"
}

variable "homeassistant_version" {
  type    = string
  default = "2026.10.4"
}

variable "shairport_version" {
  type    = string
  default = "5.6.2"
}

variable "openspeedtest_version" {
  type    = string
  default = "v2.0.8"
}
