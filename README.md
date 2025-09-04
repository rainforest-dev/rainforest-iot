# Rainforest IoT Platform

A production-grade IoT platform for Raspberry Pi 5 using 3-layer architecture with Ansible, Terraform, and Kubernetes.

## Architecture

**🏗️ Layer 1 (Ansible)** - Infrastructure

- **K3s Kubernetes cluster** with ARM64 optimization
- **System hardening** with UFW firewall and fail2ban
- **Kubeconfig management** with automatic local fetch

**🐳 Layer 2 (Terraform)** - Workloads

- **Docker services**: HomeAssistant, Homebridge, Pi-hole, Homepage, Watchtower
- **Kubernetes monitoring**: Prometheus, Grafana, Loki with dependency management
- **Remote Helm deployment** with automatic CRD handling

**🚀 Layer 3 (Future)** - Applications

- Custom application deployments and integrations

### Key Benefits

- ✅ **Automatic dependency management** - CRDs installed before usage
- ✅ **Clean layer separation** - Infrastructure vs workloads
- ✅ **Single deployment command** - No manual sequencing required
- ✅ **Production monitoring** - Full observability stack included

## Prerequisites

- Raspberry Pi 5 with SSH access
- Ansible inventory configured (`ansible/inventory.yml`)
- Terraform >= 1.0 with Helm provider
- kubectl for cluster management

## Quick Start

1. **Setup Infrastructure (Layer 1)**

```bash
# Configure Ansible inventory
# Edit ansible/inventory.yml with your Pi's IP/hostname

# Deploy K3s cluster and hardening
ansible-playbook -i ansible/inventory.yml ansible/playbooks/k3s-install.yml

# Validate infrastructure
ansible-playbook -i ansible/inventory.yml ansible/playbooks/validate-setup.yml
```

2. **Deploy Workloads (Layer 2)**

```bash
# Configure Terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration

# Create Docker context for remote deployment
docker context create raspberrypi-5 --docker "host=ssh://raspberrypi-5"

# Deploy all workloads with dependency management
terraform init
terraform plan    # Safe to run repeatedly
terraform apply   # Deploy with automatic sequencing
```

## Services

| Service           | Description                            | Port      | Status    |
| ----------------- | -------------------------------------- | --------- | --------- |
| **HomeAssistant** | Home automation platform               | 8123      | ✅ Active |
| **Homebridge**    | HomeKit bridge for non-HomeKit devices | 8581      | ✅ Active |
| **Homepage**      | Dashboard and service portal           | 80        | ✅ Active |
| **Pi-hole**       | DNS-based ad blocker                   | 8080      | ✅ Active |
| **Watchtower**    | Automatic container updates            | -         | ✅ Active |
| **OpenSpeedTest** | Network speed testing                  | 3000/3001 | ✅ Active |

## Security Features

- ✅ No privileged containers
- ✅ Resource limits on all containers
- ✅ Health checks and restart policies
- ✅ Read-only Docker socket mounts
- ✅ Minimal container capabilities
- ✅ Structured logging with rotation

## Configuration

### HomeAssistant Setup

1. Access HomeAssistant at `http://your-pi-hostname:8123`
2. Complete initial setup
3. **HACS Installation**: Automatically installed when `enable_hacs = true` (default)
   - Navigate to Settings → Devices & Services
   - Add HACS integration and authenticate with GitHub
   - See [docs/homeassistant-hacs-setup.md](docs/homeassistant-hacs-setup.md) for details

### Homebridge Setup

1. Access Homebridge at `http://your-pi-hostname:8581`
2. Complete the setup wizard (auto-generates PIN and QR codes)
3. Install Wake-on-LAN plugin:
   - Go to Plugins tab
   - Search for "homebridge-wol"
   - Configure with your PC's MAC address
4. Add to iOS Home app using the QR code or PIN

See detailed setup guide: [docs/homebridge-setup.md](docs/homebridge-setup.md)

### USB Device Support

For Zigbee/Z-Wave dongles, set in `terraform.tfvars`:

```hcl
enable_usb_devices = true
enable_hacs = true  # Enable HACS installation (default)
```

## Maintenance

### View Logs

```bash
docker logs homeassistant
docker logs pihole
```

### Update Containers

Watchtower automatically updates containers daily. Manual update:

```bash
docker pull ghcr.io/home-assistant/home-assistant:stable
terraform apply -replace=module.homeassistant.docker_container.homeassistant
```

### Backup Configuration

```bash
docker run --rm -v homeassistant_configuration:/source -v $(pwd):/backup alpine tar czf /backup/homeassistant-backup.tar.gz -C /source .
```

## Troubleshooting

### Container Issues

```bash
# Check container status
docker ps -a

# View container logs
docker logs <container-name>

# Apply only necessary changes (recommended)
terraform plan && terraform apply

# Force container replacement (rarely needed)
terraform apply -replace=module.<service>.docker_container.<container>
```

### Terraform Issues

```bash
# Check what Terraform wants to change
terraform plan

# Target specific module if needed
terraform apply -target=module.homepage

# Refresh state if containers changed outside Terraform
terraform refresh
```

### Network Issues

- Ensure SSH access is working
- Check Docker context: `docker context ls`
- Verify Pi-hole DNS on port 8080 (not 80)
- Homepage host validation resolved automatically

## Configuration Variables

Key options in `terraform.tfvars`:

### Connection Settings

```hcl
raspberry_pi_hostname = "raspberrypi-5"  # Your Pi's hostname or IP
raspberry_pi_user = "rainforest"         # SSH username
raspberry_pi_port = 22                   # SSH port
```

### Hardware Options

```hcl
enable_usb_devices = true     # Enable for Zigbee/Z-Wave dongles
homeassistant_memory = 1024   # Memory limit in MB
homebridge_memory = 512       # Homebridge memory limit in MB
```

### Network Ports

```hcl
homepage_port = 80           # Dashboard port
pihole_web_port = 8080       # Pi-hole admin interface
homebridge_web_port = 8581   # Homebridge web UI
openspeedtest_ports = {
  http  = 3000
  https = 3001
}
```

See `variables.tf` for all customizable options.
