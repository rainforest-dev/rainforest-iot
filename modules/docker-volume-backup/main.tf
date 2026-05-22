terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

resource "docker_image" "backup" {
  name         = "offen/docker-volume-backup:${var.image_version}"
  keep_locally = true
}

# Nightly backup of all Pi5 Docker service volumes → MinIO (Mac Mini) → Synology.
#
# How it works:
#   1. Volumes are mounted read-only at /backup/<service>/
#   2. The container creates a tar.gz of each source directory
#   3. Archives are uploaded to MinIO using S3 path-style addressing
#   4. Before archiving, containers labelled with BACKUP_STOP_DURING_BACKUP_LABEL
#      are gracefully stopped, then restarted after the archive completes.
#      This is critical for Home Assistant whose SQLite recorder DB must be
#      quiesced before copying to avoid corrupt backups.
#
# To add a new service to this backup in the future:
#   1. Add its docker_volume as a new volumes{} block below
#   2. Add the stop label to the service container if it uses SQLite/leveldb
#
# To trigger a manual backup (useful for testing):
#   ssh rainforest@raspberrypi-5.local "docker exec docker-volume-backup backup"
resource "docker_container" "backup" {
  name    = "docker-volume-backup"
  image   = docker_image.backup.image_id
  restart = "unless-stopped"

  env = [
    # Cron schedule — default 03:00 daily, 1h after Velero's K3s backup
    "BACKUP_CRON_EXPRESSION=${var.backup_schedule}",

    # MinIO S3 target on Mac Mini
    "AWS_S3_BUCKET_NAME=${var.minio_bucket}",
    "AWS_ACCESS_KEY_ID=${var.minio_access_key}",
    "AWS_SECRET_ACCESS_KEY=${var.minio_secret_key}",
    "AWS_ENDPOINT=${var.minio_endpoint}",
    # Required for MinIO: use /<bucket>/<key> path format instead of virtual-hosted-style
    "AWS_S3_FORCE_PATH_STYLE=true",
    # Prefix all archives with "pi5/" so the bucket can also hold backups from
    # other hosts in the future without filename collisions
    "AWS_S3_PATH=pi5",

    # Retention: keep last N days, prune older archives automatically
    "BACKUP_RETENTION_DAYS=${var.retention_days}",

    # Label name used to identify containers that must be stopped before backup.
    # Any container with this label set to "true" is stopped, the backup runs,
    # then the container is restarted. Currently applied to: homeassistant.
    "BACKUP_STOP_DURING_BACKUP_LABEL=docker-volume-backup.stop-during-backup",

    # Include timestamp in archive filenames (e.g. backup-20260522-030001.tar.gz)
    "BACKUP_FILENAME=backup-%Y%m%d-%H%M%S.tar.gz",
  ]

  # Docker socket: required to stop/start containers during backup.
  # This grants the backup container API access to the Docker daemon —
  # effectively root-equivalent. Acceptable for a homelab single-node setup.
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }

  # ── Backup sources ────────────────────────────────────────────────────────
  # Each volume is mounted read-only inside /backup/<service>/.
  # The backup tool archives everything under /backup/ in a single tar.gz.

  # Home Assistant: /config — contains configuration.yaml, automations,
  # scripts, custom_components, and the SQLite recorder database (home-assistant_v2.db)
  volumes {
    volume_name    = "homeassistant_configuration"
    container_path = "/backup/homeassistant"
    read_only      = true
  }

  # Homebridge: /homebridge — contains config.json, persist/, and plugin state
  volumes {
    volume_name    = "homebridge_data"
    container_path = "/backup/homebridge"
    read_only      = true
  }

  # Pi-hole: /etc/pihole — gravity.db (ad lists), custom lists, settings
  volumes {
    volume_name    = "pihole"
    container_path = "/backup/pihole"
    read_only      = true
  }

  # Pi-hole dnsmasq: /etc/dnsmasq.d — local DNS records and DHCP config
  volumes {
    volume_name    = "pihole_dnsmasq"
    container_path = "/backup/pihole_dnsmasq"
    read_only      = true
  }

  # Music Assistant: /data — library metadata, provider configs, playlists
  volumes {
    volume_name    = "music_assistant_data"
    container_path = "/backup/music_assistant"
    read_only      = true
  }

  log_opts = var.log_opts
}
