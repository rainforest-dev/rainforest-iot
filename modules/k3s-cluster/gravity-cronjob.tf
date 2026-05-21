resource "kubernetes_secret" "pi_ssh_key" {
  metadata {
    name      = "pi-ssh-key"
    namespace = "default"
  }

  data = {
    id_rsa = var.pi_ssh_private_key
  }

  type = "Opaque"
}

resource "kubernetes_cron_job_v1" "pihole_gravity_update" {
  metadata {
    name      = "pihole-gravity-update"
    namespace = "default"
  }

  spec {
    schedule                      = "0 3 * * 0"
    concurrency_policy            = "Forbid"
    failed_jobs_history_limit     = 3
    successful_jobs_history_limit = 1

    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            restart_policy = "OnFailure"

            container {
              name  = "gravity-update"
              image = "alpine:3.19"

              command = [
                "/bin/sh", "-c",
                "apk add --no-cache openssh-client && ssh -o StrictHostKeyChecking=no -i /ssh/id_rsa ${var.pi_user}@${var.pi_hostname} 'docker exec pihole pihole -g'"
              ]

              volume_mount {
                name       = "ssh-key"
                mount_path = "/ssh"
                read_only  = true
              }
            }

            volume {
              name = "ssh-key"
              secret {
                secret_name  = kubernetes_secret.pi_ssh_key.metadata[0].name
                default_mode = "0400"
              }
            }
          }
        }
      }
    }
  }
}
