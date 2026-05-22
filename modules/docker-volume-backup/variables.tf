variable "image_version" {
  description = "offen/docker-volume-backup image version"
  type        = string
  default     = "v2.43.0"
}

variable "minio_endpoint" {
  description = "Mac Mini MinIO S3 endpoint. Must be the LAN IP — Tailscale is not available inside the Pi5 Docker network."
  type        = string
  default     = "http://192.168.0.126:9000"
}

variable "minio_bucket" {
  description = "MinIO bucket name for Pi5 Docker volume backups"
  type        = string
  default     = "pi5-docker-backup"
}

variable "minio_access_key" {
  description = "MinIO root user"
  type        = string
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO root password"
  type        = string
  sensitive   = true
}

variable "backup_schedule" {
  description = "Cron expression for backup schedule. Default is 3 AM daily — 1 hour after Velero's K3s backup."
  type        = string
  default     = "0 3 * * *"
}

variable "retention_days" {
  description = "Number of daily backups to retain in MinIO"
  type        = number
  default     = 7
}

variable "log_opts" {
  description = "Docker logging options (max-size / max-file). Matches the pattern used by all other Pi5 modules."
  type        = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}
