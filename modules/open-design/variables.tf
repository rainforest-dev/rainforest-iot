variable "image_version" {
  description = "OpenDesign image tag (ghcr.io/nexu-io/od)"
  type        = string
  default     = "0.27.1"
}

variable "image_digest" {
  description = "Multi-arch index digest for image_version; pins the exact build"
  type        = string
  default     = "sha256:e60aec9fb7e07af9f11de58eff62a546c82421d3a24aa57a353b4c2808a1d85c"
}

variable "bind_ip" {
  description = "Host address the API is published on (the Pi's LAN IP, never 0.0.0.0)"
  type        = string

  validation {
    condition     = var.bind_ip != "0.0.0.0" && var.bind_ip != ""
    error_message = "bind_ip must be the Pi's LAN address, not 0.0.0.0."
  }
}

variable "api_token" {
  description = "OD_API_TOKEN required on every /api request (openssl rand -hex 32)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.api_token) >= 32
    error_message = "api_token must be at least 32 characters; generate one with `openssl rand -hex 32`."
  }
}

variable "allowed_origins" {
  description = "Browser origins allowed to call /api (OD_ALLOWED_ORIGINS)"
  type        = list(string)
  default     = []
}

variable "memory_limit" {
  description = "Memory limit for the OpenDesign container (MB)"
  type        = number
  default     = 384
}

variable "node_heap_mb" {
  description = "Node.js old-space heap cap inside the container (MB), kept well under memory_limit"
  type        = number
  default     = 192
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
