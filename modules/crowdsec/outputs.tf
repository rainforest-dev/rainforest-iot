output "metrics_endpoint" {
  description = "CrowdSec Prometheus metrics endpoint"
  value       = "http://localhost:6060/metrics"
}

output "lapi_endpoint" {
  description = "CrowdSec LAPI endpoint"
  value       = "http://localhost:6081"
}
