# AI Coding Assistant Instructions

## Project Overview

This is a **3-layer IoT platform** for Raspberry Pi 5 using Ansible + Terraform + Kubernetes:

- **Layer 1 (Ansible)**: Infrastructure setup (K3s, system hardening, kubeconfig management)
- **Layer 2 (Terraform)**: Workload deployment (Docker services + K8s monitoring stack)
- **Layer 3 (Future)**: Application management and custom integrations

**Critical Architecture Pattern**: Automatic dependency management between Prometheus CRDs and downstream ServiceMonitors using `time_sleep` resources.

## Essential Development Commands

### Infrastructure Deployment (Required sequence)

```bash
# 1. Layer 1: Infrastructure setup
ansible-playbook -i ansible/inventory.yml ansible/playbooks/k3s-install.yml

# 2. Layer 2: Workload deployment with automatic dependency handling
terraform apply  # Handles Docker + K8s deployment ordering automatically

# 3. Service management
docker context use raspberrypi-5  # Switch to remote Pi Docker
kubectl --kubeconfig ~/.kube/config-raspberrypi-5 get pods -n monitoring
```

### Development Workflow

```bash
# Test changes safely
terraform plan
terraform apply -target=module.homepage  # Target specific services

# Clean deployment for dependency testing
terraform destroy && terraform apply

# Validate CRD dependency resolution
kubectl get servicemonitors -n monitoring --kubeconfig ~/.kube/config-raspberrypi-5
```

## Architecture Patterns

### Module Structure

- **Docker modules** (`modules/homeassistant/`, `modules/pi-hole/`): Use `docker` provider, include lifecycle rules to prevent unnecessary recreation
- **K8s modules** (`modules/prometheus-stack/`, `modules/loki-stack/`): Use `kubernetes` and `helm` providers with provider aliases
- **Integration modules** (`modules/monitoring-integrations/`): Deploy ServiceMonitors after CRDs exist

### Critical Dependency Pattern

```terraform
# In main.tf - ALWAYS follow this pattern for CRD dependencies:
module "prometheus_stack" {
  depends_on = [module.k3s_cluster]
}

resource "time_sleep" "wait_for_prometheus_crds" {
  depends_on      = [module.prometheus_stack]
  create_duration = "60s"
}

module "loki_stack" {
  depends_on = [time_sleep.wait_for_prometheus_crds]
}
```

### Provider Configuration

```terraform
# ALWAYS use provider aliases for multi-environment support
provider "docker" {
  alias = "raspberry-pi"
  host  = local.raspberry_pi_host
  ssh_opts = ["-o", "ServerAliveInterval=30"]  # SSH reliability
}

provider "kubernetes" {
  alias       = "k3s"
  config_path = var.k8s_config_path  # ~/.kube/config-raspberrypi-5
}
```

## Configuration Management

### Primary Configuration

- `terraform.tfvars` - Single source of truth for all deployment settings
- `terraform.tfvars.example` - Template with all configurable options
- `variables.tf` - Defaults and validation rules

### Variable Hierarchy (most specific wins)

1. `terraform.tfvars` (primary)
2. Module-specific variables
3. `variables.tf` defaults
4. `locals.tf` computed values

### Container Lifecycle Rules

```terraform
# Standard pattern for all Docker containers:
lifecycle {
  ignore_changes = [
    memory, memory_swap,  # Ignore Docker-managed attributes
  ]
  replace_triggered_by = [
    docker_image.service.image_id,  # Only recreate on image changes
  ]
}
```

## Service Architecture

### Docker Services (Layer 2)

- **HomeAssistant** (port 8123): Home automation with USB device support
- **Homebridge** (port 8581): HomeKit bridge with SSH key automation
- **Homepage** (port 80): Dashboard with dual-cluster K8s widgets
- **Pi-hole** (port 8080): DNS ad-blocking
- **OpenSpeedTest** (ports 3000/3001): Network speed testing

### Kubernetes Monitoring (Layer 2)

- **Prometheus** (NodePort 30090): Metrics collection with external scraping
- **Grafana** (NodePort 30080): Dashboards via ConfigMap sidecar pattern
- **Loki** (NodePort 30100): Log aggregation with Promtail
- **AlertManager** (NodePort 30093): Alert routing

## Development Guidelines

### Adding New Docker Services

1. Create module in `modules/<service-name>/` following existing pattern
2. Add provider configuration: `providers = { docker = docker.raspberry-pi }`
3. Include lifecycle rules and resource limits
4. Add module call to `main.tf` with dependency chain if needed

### Modifying Monitoring Stack

1. **Never modify CRD deployment order** - dependency chain is fragile
2. Test ServiceMonitor changes with clean deployment: `terraform destroy && terraform apply`
3. Use `kubectl get servicemonitors -n monitoring` to verify CRD availability

### Branch Strategy

- `main`: Production-ready configuration
- `rental-setup`: Current working branch (acton-3 module disabled)

### Configuration Testing

```bash
# Validate variable changes
terraform validate
terraform plan  # Check for unexpected changes

# Test connectivity
docker context ls
ansible raspberry_pi -m ping
```

## Troubleshooting Patterns

### Common Issues

- **ServiceMonitor CRD conflicts**: Resolved by `time_sleep` resource - clean deploy if issues persist
- **SSH connection timeouts**: Provider includes keepalive settings
- **Container recreation loops**: Check lifecycle rules in module definitions
- **Kubeconfig context**: Use `--kubeconfig ~/.kube/config-raspberrypi-5` for Pi cluster access

### Debug Commands

```bash
# Layer 1 issues
ssh rainforest@raspberrypi-5 'systemctl status k3s'
ansible-playbook -i ansible/inventory.yml ansible/playbooks/validate-setup.yml

# Layer 2 issues
docker context use raspberrypi-5 && docker ps
terraform apply -target=module.<service>
kubectl get pods --all-namespaces --kubeconfig ~/.kube/config-raspberrypi-5
```

## Security Considerations

- All containers run with minimal capabilities
- USB device access is opt-in via `enable_usb_devices`
- No privileged containers - specific capabilities only
- Logging rotation prevents disk space issues
- SSH-based deployment maintains air gap for Pi
