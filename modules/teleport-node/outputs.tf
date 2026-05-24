output "container_name" {
  description = "Name of the Teleport node Docker container"
  value       = docker_container.teleport_node.name
}

output "node_name" {
  description = "Teleport node name (use with: tsh ls)"
  value       = var.node_name
}

output "registered_apps" {
  description = "Apps registered with the Teleport cluster"
  value       = keys(var.apps)
}

output "tsh_login_cmd" {
  description = "Command to log in and list apps via tsh"
  value       = "tsh login --proxy=${var.teleport_proxy_address} && tsh apps ls"
}
