output "containers" {
  description = "Container names running on the site host"
  value = [
    docker_container.alloy.name,
    docker_container.unpoller.name,
    docker_container.speedtest.name,
  ]
}

output "alloy_config" {
  description = "Rendered Alloy configuration (contains no secrets; they are read from env)"
  value       = local.alloy_config
}
