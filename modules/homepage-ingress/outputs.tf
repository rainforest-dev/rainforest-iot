output "ingress_hostname" {
  description = "Homepage ingress hostname"
  value       = var.raspberry_pi_hostname
}

output "service_name" {
  description = "Homepage service name"
  value       = kubernetes_service.homepage.metadata[0].name
}

output "namespace" {
  description = "Homepage ingress namespace"
  value       = kubernetes_namespace.homepage_ingress.metadata[0].name
}