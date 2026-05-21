resource "kubernetes_namespace" "velero" {
  metadata {
    name = var.namespace
  }
}

# Velero needs MinIO credentials stored as a Kubernetes Secret
resource "kubernetes_secret" "velero_credentials" {
  metadata {
    name      = "velero-s3-credentials"
    namespace = kubernetes_namespace.velero.metadata[0].name
  }

  data = {
    "cloud" = <<-EOT
      [default]
      aws_access_key_id = ${var.minio_access_key}
      aws_secret_access_key = ${var.minio_secret_key}
    EOT
  }

  type = "Opaque"
}

resource "helm_release" "velero" {
  name       = "velero"
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  version    = var.chart_version
  namespace  = kubernetes_namespace.velero.metadata[0].name

  values = [
    yamlencode({
      credentials = {
        useSecret = false
      }

      initContainers = [
        {
          name  = "velero-plugin-for-aws"
          image = "velero/velero-plugin-for-aws:v1.13.1"
          volumeMounts = [
            { mountPath = "/target", name = "plugins" }
          ]
        }
      ]

      configuration = {
        backupStorageLocation = [
          {
            name     = "default"
            provider = "aws"
            bucket   = var.minio_bucket
            config = {
              region           = "minio"
              s3ForcePathStyle = "true"
              s3Url            = var.minio_endpoint
              publicUrl        = var.minio_endpoint
            }
            credential = {
              name = kubernetes_secret.velero_credentials.metadata[0].name
              key  = "cloud"
            }
          }
        ]

        volumeSnapshotLocation = [
          {
            name     = "default"
            provider = "aws"
            config = {
              region = "minio"
            }
          }
        ]
      }

      resources = {
        requests = { cpu = "50m", memory = "64Mi" }
        limits   = { cpu = "500m", memory = "256Mi" }
      }

      nodeAgent = {
        enabled       = true
        podVolumePath = "/var/lib/kubelet/pods"
        resources = {
          requests = { cpu = "25m", memory = "32Mi" }
          limits   = { cpu = "250m", memory = "128Mi" }
        }
      }

      schedules = {
        daily-full-backup = {
          disabled                   = false
          schedule                   = var.backup_schedule
          useOwnerReferencesInBackup = false
          template = {
            ttl                     = var.backup_ttl
            includedNamespaces      = ["*"]
            storageLocation         = "default"
            volumeSnapshotLocations = ["default"]
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_secret.velero_credentials]
}
