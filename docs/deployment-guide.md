# Deployment Guide

This guide covers the 3-layer architecture deployment for the Raspberry Pi 5 IoT platform with production monitoring.

## Overview

The deployment uses a clean 3-layer architecture with automatic dependency management:

1. **Layer 1 (Ansible)**: Infrastructure setup - K3s cluster, system hardening, kubeconfig management
2. **Layer 2 (Terraform)**: All workloads - Docker services + Kubernetes monitoring with proper CRD dependencies  
3. **Layer 3 (Future)**: Application management and custom integrations

## Prerequisites

- Raspberry Pi 5 with SSH access and Ansible inventory configured
- Terraform installed locally with Helm provider
- Valid terraform.tfvars configuration
- kubectl installed locally for cluster management

## Layer 1: Infrastructure Setup (Ansible)

### What Gets Deployed
- **K3s Kubernetes cluster** with proper ARM64 configuration
- **System hardening** with UFW firewall and fail2ban
- **Kubeconfig management** with automatic local fetch for Terraform
- **Namespace and storage setup** for monitoring workloads

### K3s API access naming (required)
To make Terraform/kubectl work from any machine on the same LAN (and optionally via Tailscale), Ansible enforces:

- __Certificate SANs__: Manage `/etc/rancher/k3s/config.yaml` to include:
  - `raspberrypi-5.local`
  - `raspberrypi-5`
  - `localhost`
- __Kubeconfig server URL__: Normalize `/etc/rancher/k3s/k3s.yaml` to `server: https://raspberrypi-5.local:6443` and fetch to controller as `~/.kube/config-raspberrypi-5`.

Notes:
- `.local` relies on mDNS. Ensure Bonjour (macOS) or Avahi/`nss-mdns` (Linux) is available on client machines.
- If accessing over Tailscale, add your MagicDNS name to K3s `tls-san`, rotate certs, and use that name in kubeconfig.

### Deploy Infrastructure
```bash
# Deploy infrastructure layer
ansible-playbook -i ansible/inventory.yml ansible/playbooks/k3s-install.yml

# Validate infrastructure
ansible-playbook -i ansible/inventory.yml ansible/playbooks/validate-setup.yml
```

### Post-Layer 1 Verification
```bash
# Check K3s cluster
kubectl get nodes --kubeconfig ~/.kube/config-raspberrypi-5

# Verify cluster components
kubectl get pods -A --kubeconfig ~/.kube/config-raspberrypi-5
```

## Layer 2: Workloads Deployment (Terraform)

### What Gets Deployed
**Docker Services:**
- **HomeAssistant**: Smart home automation platform with HACS support
- **Homebridge**: HomeKit bridge for non-HomeKit devices with automated firewall management
- **Pi-hole**: Network-wide DNS ad blocking with Tailscale support
- **Homepage**: Service dashboard with integrated monitoring
- **Watchtower**: Container auto-updates
- **OpenSpeedTest**: Network speed testing

**Kubernetes Monitoring Stack:**
- **Prometheus Stack**: Metrics collection with CRD installation
- **Grafana**: Dashboards with pre-configured homelab views  
- **Loki + Promtail**: Centralized logging for containers and K8s
- **AlertManager**: Custom homelab alerting rules
- **ServiceMonitors**: Integration between services and monitoring

### Deploy All Workloads
```bash
# Single deployment with dependency management
terraform plan   # Review all changes
terraform apply  # Deploy everything with proper sequencing
```

### Post-Layer 2 Verification
```bash
# Check Docker services
ssh rainforest@raspberrypi-5.local 'docker ps'

# Check Kubernetes monitoring
kubectl get pods -n monitoring --kubeconfig ~/.kube/config-raspberrypi-5

# Access all services
echo "HomeAssistant: http://raspberrypi-5.local:8123"
echo "Homebridge: http://raspberrypi-5.local:8581"
echo "Pi-hole: http://raspberrypi-5.local:8080/admin"
echo "Homepage: http://raspberrypi-5.local:80"
echo "Grafana: http://raspberrypi-5.local:30080 (admin/admin123)"
echo "Prometheus: http://raspberrypi-5.local:30090"
echo "AlertManager: http://raspberrypi-5.local:30093"
```

## Architecture Benefits

### **Dependency Management**
- ✅ **Automatic CRD handling**: Prometheus deploys first, then Loki can use ServiceMonitor CRDs
- ✅ **No manual sequencing**: Single `terraform apply` handles everything
- ✅ **Clean state management**: No conflicts between layers

### **Layer Separation**  
- ✅ **Infrastructure vs Workloads**: Clear separation of concerns
- ✅ **Remote Helm management**: No need to install Helm on Pi
- ✅ **Scalable architecture**: Easy to add Layer 3 applications

### **Operational Benefits**
- ✅ **Single source of truth**: All workloads managed by Terraform
- ✅ **Rollback capabilities**: Terraform state management
- ✅ **Environment consistency**: Reproducible deployments

## Configuration Files

### Key Configuration Files
- `ansible/inventory.yml`: Pi connection details
- `terraform.tfvars`: Workload configuration (ports, resources, IPs)
- `main.tf`: Layer 2 workload definitions with dependencies

### Important Settings
```hcl
# Layer control
enable_k8s_cluster = true   # Enable Kubernetes monitoring
enable_hacs = true          # Enable HACS for HomeAssistant
enable_prometheus = true    # Enable Prometheus monitoring stack
enable_loki = true          # Enable Loki logging stack

# Kubeconfig management (set by Ansible)
k8s_config_path = "~/.kube/config-raspberrypi-5"
k8s_insecure_skip_tls_verify = false

# Service configuration
homebridge_web_port = 8581  # Homebridge web UI port
grafana_admin_password = "admin123"  # Change in production

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

### Layer 1 (Infrastructure) Issues
```bash
# Check K3s cluster status
ssh rainforest@raspberrypi-5 'systemctl status k3s'

# Validate Ansible deployment
ansible-playbook -i ansible/inventory.yml ansible/playbooks/validate-setup.yml

# Check kubeconfig connectivity
kubectl get nodes --kubeconfig ~/.kube/config-raspberrypi-5
```

### Layer 2 (Workload) Issues
```bash
# Check Docker services
ssh rainforest@raspberrypi-5 'docker ps'
ssh rainforest@raspberrypi-5 'docker logs <container-name>'

# Check Kubernetes monitoring
kubectl get pods -n monitoring --kubeconfig ~/.kube/config-raspberrypi-5
kubectl describe pod <pod-name> -n monitoring --kubeconfig ~/.kube/config-raspberrypi-5

# Check Terraform state
terraform state list | grep monitoring
```

### Common Issues
- **CRD conflicts**: Clean deployment resolves ServiceMonitor issues
- **Resource limits**: Pi 5 resource constraints may require tuning in terraform.tfvars
- **Network connectivity**: Check kubeconfig path and TLS settings
- **Storage issues**: Ensure sufficient disk space (20GB+ recommended)
- **Docker image downloads**: Pi network speed may slow initial deployment

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