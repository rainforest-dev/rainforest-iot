# Deployment Guide

This guide covers the two-step deployment process for the Raspberry Pi 5 IoT platform with production monitoring.

## Overview

The deployment is split into two phases for safety and modularity:

1. **Phase 1**: Docker Services (HomeAssistant, Pi-hole, Homepage, etc.)
2. **Phase 2**: Kubernetes Monitoring Stack (Prometheus, Grafana, Loki)

## Prerequisites

- Raspberry Pi 5 with SSH access
- Docker installed on Pi 5
- Terraform installed locally
- Valid terraform.tfvars configuration

## Phase 1: Docker Services Deployment

### What Gets Deployed
- **HomeAssistant**: Smart home automation platform
- **Pi-hole**: Network-wide DNS ad blocking with Tailscale support
- **Homepage**: Service dashboard
- **Watchtower**: Container auto-updates
- **OpenSpeedTest**: Network speed testing

### Deploy Docker Services
```bash
# Ensure K8s is disabled for Phase 1
# In terraform.tfvars:
enable_k8s_cluster = false

# Deploy Docker services
terraform plan   # Review changes
terraform apply  # Deploy
```

### Post-Phase 1 Verification
```bash
# Check service status
ssh rainforest@raspberrypi-5 'docker ps'

# Verify Pi-hole is working
curl -I http://raspberrypi-5:8080/admin

# Test Homepage dashboard
curl -I http://raspberrypi-5:80
```

## Phase 2: Kubernetes Monitoring Stack

### Prerequisites for Phase 2
K3s must be installed on the Raspberry Pi 5:

```bash
# SSH to Pi 5
ssh rainforest@raspberrypi-5

# Install K3s
curl -sfL https://get.k3s.io | sh -

# Copy kubeconfig for remote access (optional)
sudo cat /etc/rancher/k3s/k3s.yaml
# Copy contents to ~/.kube/config on your local machine
# Update server: https://raspberrypi-5:6443
```

### What Gets Deployed in Phase 2
- **K3s Cluster**: Foundation with namespaces, storage, security policies
- **Prometheus Stack**: Metrics collection, alerting, visualization
- **Grafana**: Dashboards with pre-configured homelab views
- **Loki + Promtail**: Centralized logging for containers and K8s
- **AlertManager**: Custom homelab alerting rules

### Deploy Monitoring Stack
```bash
# Enable K8s in terraform.tfvars:
enable_k8s_cluster = true

# Deploy full stack
terraform plan   # Review K8s resources
terraform apply  # Deploy monitoring
```

### Post-Phase 2 Verification
```bash
# Check K8s cluster
kubectl get nodes
kubectl get pods -A

# Access monitoring services
echo "Grafana: http://raspberrypi-5:30080 (admin/admin123)"
echo "Prometheus: http://raspberrypi-5:30090"
echo "Loki: http://raspberrypi-5:30100"
echo "AlertManager: http://raspberrypi-5:30093"
```

## Alternative: Pure Helm Deployment

If you prefer using Helm directly instead of Terraform for the monitoring stack, see [helm-deployment.md](./helm-deployment.md).

## Configuration Files

### Key Configuration Files
- `terraform.tfvars`: Main configuration (ports, resources, IPs)
- `variables.tf`: Variable definitions with defaults
- `main.tf`: Infrastructure definitions

### Important Settings
```hcl
# Phase control
enable_k8s_cluster = false  # Phase 1
enable_k8s_cluster = true   # Phase 2

# Pi-hole network configuration
pihole_network_interface = "eth0"
pihole_server_ip = ""  # Auto-detect
tailscale_ip = ""      # Set your Tailscale IP

# Monitoring resource limits (optimized for Pi 5)
monitoring_resource_limits = {
  prometheus_cpu_limit = "500m"
  prometheus_memory_limit = "512Mi"
  grafana_cpu_limit = "200m"
  grafana_memory_limit = "256Mi"
  # ... see terraform.tfvars for full configuration
}
```

## Troubleshooting

### Phase 1 Issues
```bash
# Check Docker service status
ssh rainforest@raspberrypi-5 'systemctl status docker'

# View container logs
ssh rainforest@raspberrypi-5 'docker logs pihole'
ssh rainforest@raspberrypi-5 'docker logs homeassistant'
```

### Phase 2 Issues
```bash
# Check K3s status
ssh rainforest@raspberrypi-5 'systemctl status k3s'

# Check pod status
kubectl describe pod <pod-name> -n monitoring

# View pod logs
kubectl logs <pod-name> -n monitoring
```

### Common Issues
- **Connection refused**: Ensure K3s is running before Phase 2
- **Resource limits**: Pi 5 resource constraints may require tuning
- **DNS issues**: Check Pi-hole configuration and network settings
- **Storage issues**: Ensure sufficient disk space (20GB+ recommended)

## Monitoring Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Mac Mini M4   │    │ Raspberry Pi 5  │    │  Future PC      │
│                 │    │                 │    │                 │
│ Docker Services │────│ K3s Monitoring  │────│ GitHub Runner   │
│ (Homelab Apps)  │    │ Stack (LGTM)    │    │ (Planned)       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        └───────────────────────┼───────────────────────┘
                                │
                    ┌─────────────────┐
                    │    Grafana      │
                    │   Dashboards    │
                    │ (Unified View)  │
                    └─────────────────┘
```

## Next Steps

After successful deployment:
1. Configure Grafana dashboards for your specific needs
2. Set up AlertManager notifications (email, Slack, etc.)
3. Add custom monitoring targets
4. Implement log retention policies
5. Set up automated backups for persistent volumes

## Security Considerations

- Change default Grafana password in production
- Configure proper network policies in K8s
- Set up Pi-hole admin password
- Consider enabling HTTPS with proper certificates
- Review resource quotas and limits regularly