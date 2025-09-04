terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Create namespace for Homepage ingress
resource "kubernetes_namespace" "homepage_ingress" {
  metadata {
    name = "homepage-ingress"
  }
}

# External service pointing to Docker container on host network
resource "kubernetes_service" "homepage_external" {
  metadata {
    name      = "homepage-external"
    namespace = kubernetes_namespace.homepage_ingress.metadata[0].name
  }

  spec {
    type          = "ExternalName"
    external_name = var.raspberry_pi_hostname
    port {
      port        = 80
      target_port = 8888
    }
  }
}

# Alternative: Endpoint-based service for more control
resource "kubernetes_endpoints" "homepage" {
  metadata {
    name      = "homepage"
    namespace = kubernetes_namespace.homepage_ingress.metadata[0].name
  }

  subset {
    address {
      ip = var.raspberry_pi_ip
    }
    port {
      port = 8888
    }
  }
}

resource "kubernetes_service" "homepage" {
  metadata {
    name      = "homepage"
    namespace = kubernetes_namespace.homepage_ingress.metadata[0].name
  }

  spec {
    port {
      port        = 80
      target_port = 8888
    }
    type = "ClusterIP"
  }
}

# Homepage Ingress
resource "kubernetes_ingress_v1" "homepage" {
  metadata {
    name      = "homepage"
    namespace = kubernetes_namespace.homepage_ingress.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
    }
  }

  spec {
    rule {
      host = var.raspberry_pi_hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.homepage.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    # Also support access via short hostname
    rule {
      host = element(split(".", var.raspberry_pi_hostname), 0)

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.homepage.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}