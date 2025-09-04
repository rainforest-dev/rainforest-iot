variable "raspberry_pi_hostname" {
  description = "Raspberry Pi hostname for ingress"
  type        = string
  default     = "raspberrypi-5.local"
}

variable "raspberry_pi_ip" {
  description = "Raspberry Pi IP address for endpoints"
  type        = string
  default     = "127.0.0.1"
}