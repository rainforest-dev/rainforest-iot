variable "namespace" {
  type    = string
  default = "velero"
}

variable "chart_version" {
  description = "Velero Helm chart version"
  type        = string
  default     = "12.0.1"
}

variable "minio_endpoint" {
  description = "Mac Mini MinIO S3 endpoint (LAN direct, not Tailscale)"
  type        = string
  default     = "http://192.168.0.126:9000"
}

variable "minio_bucket" {
  description = "MinIO bucket name for Velero backups"
  type        = string
  default     = "velero"
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
  description = "Cron schedule for daily backup"
  type        = string
  default     = "0 2 * * *"
}

variable "backup_ttl" {
  description = "How long to retain backups"
  type        = string
  default     = "168h0m0s"
}
