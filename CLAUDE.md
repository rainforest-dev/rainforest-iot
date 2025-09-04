# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a production-grade IoT platform for Raspberry Pi 5 using a 3-layer architecture:
- **Layer 1 (Ansible)**: Infrastructure setup - K3s Kubernetes cluster, system hardening, kubeconfig management  
- **Layer 2 (Terraform)**: Workloads - Docker services + Kubernetes monitoring with automatic dependency management
- **Layer 3 (Future)**: Application management and custom integrations

The platform deploys IoT services (HomeAssistant, Pi-hole, Homepage, Watchtower, OpenSpeedTest) plus production monitoring (Prometheus, Grafana, Loki, AlertManager) with proper CRD dependency handling.

## Essential Commands

### Layer 1: Infrastructure Setup (Ansible)
```bash
# Configure Ansible inventory first
# Edit ansible/inventory.yml with your Pi's IP/hostname

# Deploy K3s cluster and system hardening
ansible-playbook -i ansible/inventory.yml ansible/playbooks/k3s-install.yml

# Validate infrastructure deployment
ansible-playbook -i ansible/inventory.yml ansible/playbooks/validate-setup.yml

# Check K3s cluster from Pi kubeconfig
kubectl get nodes --kubeconfig ~/.kube/config-raspberrypi-5
```

### Layer 2: Workloads Deployment (Terraform)
```bash
# Configure Terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration

# Create Docker context for remote Pi deployment
docker context create raspberrypi-5 --docker "host=ssh://raspberrypi-5"

# Deploy all workloads with dependency management
terraform init
terraform plan    # Safe to run repeatedly
terraform apply   # Deploy with automatic sequencing

# Target specific modules if needed
terraform apply -target=module.homepage
terraform apply -target=module.prometheus_stack

# Clean deployment (useful for testing)
terraform destroy && terraform apply
```

### Service Management
```bash
# Docker services (Layer 2)
docker logs homeassistant
docker logs pihole
docker logs watchtower
docker ps -a

# Kubernetes monitoring (Layer 2)
kubectl get pods -n monitoring --kubeconfig ~/.kube/config-raspberrypi-5
kubectl logs -f deployment/prometheus-server -n monitoring --kubeconfig ~/.kube/config-raspberrypi-5
kubectl describe pod <pod-name> -n monitoring --kubeconfig ~/.kube/config-raspberrypi-5

# Access monitoring services
echo "Grafana: http://raspberrypi-5:30080 (admin/admin123)"
echo "Prometheus: http://raspberrypi-5:30090"
echo "AlertManager: http://raspberrypi-5:30093"
```

### Backup Operations
```bash
# Backup HomeAssistant configuration
docker run --rm -v homeassistant_configuration:/source -v $(pwd):/backup alpine tar czf /backup/homeassistant-backup.tar.gz -C /source .
```

## Architecture

### 3-Layer Architecture Benefits
- ✅ **Automatic dependency management**: CRDs installed before usage (Prometheus → Loki ServiceMonitors)
- ✅ **Clean layer separation**: Infrastructure vs workloads vs applications
- ✅ **Single deployment command**: No manual sequencing required
- ✅ **Production monitoring**: Full observability stack included
- ✅ **Remote Helm deployment**: No need to install Helm on Pi
- ✅ **Scalable architecture**: Easy to add Layer 3 applications

### Key Components
**Layer 1 (Ansible)**:
- `ansible/playbooks/k3s-install.yml`: K3s cluster setup + kubeconfig fetch
- `ansible/playbooks/validate-setup.yml`: Infrastructure validation
- `ansible/inventory.yml`: Pi connection configuration

**Layer 2 (Terraform)**:
- `main.tf`: Orchestrates Docker services + K8s monitoring with dependencies
- `modules/prometheus-stack/`: Production monitoring stack with CRD management
- `modules/loki-stack/`: Centralized logging with Promtail
- `modules/monitoring-integrations/`: ServiceMonitors after CRD availability
- `modules/<service>/`: Docker service modules (homeassistant, pi-hole, etc.)

### Dependency Flow
```
Ansible (K3s + kubeconfig) → Terraform (Prometheus Stack) → time_sleep(60s) → Loki + ServiceMonitors
                           → Docker Services (HomeAssistant, Pi-hole, etc.)
```

### Connection Architecture
```
Local Machine (Ansible/Terraform) --SSH--> Raspberry Pi 5 (K3s + Docker)
                ↓
        ~/.kube/config-raspberrypi-5 (Pi cluster access)
        ~/.kube/config (Docker Desktop - preserved)
```

## Configuration Management

### Primary Configuration File
Edit `terraform.tfvars` for all deployments:
- Connection settings (hostname, user, port)
- Service ports and resource limits
- Feature toggles (USB devices, memory limits)
- Timezone and logging preferences

### Variable Hierarchy
1. `terraform.tfvars` (primary configuration)
2. `variables.tf` (defaults)
3. `locals.tf` (computed values)
4. Module variables (service-specific)

### Security Configuration
- Resource limits on all containers (memory, logging)
- No privileged containers - specific capabilities only
- Read-only mounts where possible
- Health checks and restart policies

## Service Ports

**Docker Services:**
| Service | Port | Purpose |
|---------|------|---------|
| HomeAssistant | 8123 | Home automation web interface |
| Homepage | 80 | Dashboard and service portal |
| Pi-hole | 8080 | DNS ad-blocker web interface |
| OpenSpeedTest | 3000/3001 | Network speed testing (HTTP/HTTPS) |

**Kubernetes Monitoring:**
| Service | Port | Purpose |
|---------|------|---------|
| Prometheus | 30090 | Metrics collection and queries |
| Grafana | 30080 | Dashboards and visualization |
| AlertManager | 30093 | Alert management and routing |
| Loki | 30100 | Log aggregation (internal) |

## Development Workflow

### Adding New Services
1. Create new module in `modules/<service-name>/`
2. Add module definition in `main.tf`
3. Add service-specific variables to `variables.tf`
4. Update `terraform.tfvars.example` with new configuration options

### Modifying Existing Services
1. Edit module files in `modules/<service>/`
2. Update variables if needed
3. Test with `terraform plan`
4. Apply changes with `terraform apply`

### Branch Strategy
- `main`: Production-ready configuration
- `rental-setup`: Current branch with rental-specific modifications (acton-3 module disabled)

## Terraform Best Practices & Troubleshooting

### Container Lifecycle Management
The infrastructure includes smart lifecycle rules that prevent unnecessary container recreation:

- **Automatic Image Updates**: Containers only recreate when Docker images change
- **Configuration Changes**: Most config updates happen in-place without downtime
- **State Drift Protection**: Ignores Docker-managed attributes that don't affect functionality
- **SSH Reliability**: Connection keepalive prevents timeouts during operations

### Common Issues & Solutions

#### Layer 1 (Infrastructure) Issues
```bash
# K3s cluster problems
ssh rainforest@raspberrypi-5 'systemctl status k3s'
ansible-playbook -i ansible/inventory.yml ansible/playbooks/validate-setup.yml

# Kubeconfig connectivity issues
kubectl get nodes --kubeconfig ~/.kube/config-raspberrypi-5
```

#### Layer 2 (Workload) Issues
```bash
# Docker service issues
docker context use raspberrypi-5
docker ps  # Verify remote connection works
terraform apply -target=module.homepage  # Target specific module

# Kubernetes monitoring issues
kubectl get pods -n monitoring --kubeconfig ~/.kube/config-raspberrypi-5

# CRD dependency issues (resolved by time_sleep)
# Clean deployment usually resolves ServiceMonitor CRD conflicts:
terraform destroy && terraform apply
```

#### Architecture-Specific Solutions
- **ServiceMonitor CRD conflicts**: The `time_sleep` resource ensures Prometheus CRDs exist before Loki ServiceMonitors deploy
- **Kubeconfig separation**: Pi cluster access via `~/.kube/config-raspberrypi-5`, Docker Desktop preserved at `~/.kube/config`
- **Clean deployment validation**: Always test with `terraform destroy && terraform apply` to verify dependency management works

### Infrastructure Recovery
```bash
# If infrastructure state is corrupted:
terraform refresh  # Sync state with reality
terraform plan     # Review proposed changes
terraform apply    # Apply only necessary changes
```

## Security Considerations

- All containers run with minimal required capabilities
- USB device access is opt-in via `enable_usb_devices` variable
- Logging rotation configured to prevent disk space issues
- No hardcoded secrets - all configuration via variables
- SSH-based deployment maintains air gap from internet for Pi
- Provider SSH configuration includes security best practices