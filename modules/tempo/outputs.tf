output "otlp_http_endpoint_port" {
  description = "NodePort of Tempo's OTLP/HTTP receiver"
  value       = kubernetes_service.otlp_http.spec[0].port[0].node_port
}

output "query_url" {
  description = "In-cluster URL Grafana uses to query Tempo"
  value       = "http://tempo.${var.namespace}.svc:3200"
}
