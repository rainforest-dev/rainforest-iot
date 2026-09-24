# Rainforest IoT Platform

Home automation and monitoring on a single Raspberry Pi 5. Ansible builds the machine, Terraform
puts the workloads on it.

## Architecture

```mermaid
flowchart TD
  subgraph L1["Layer 1 — Ansible, builds the machine"]
    H[UFW firewall and SSH lockdown]
    K[K3s cluster, ARM64]
    KC[kubeconfig fetched back to the laptop]
  end
  subgraph L2["Layer 2 — Terraform, places the workloads"]
    D[Docker: Home Assistant, Homebridge, Pi-hole, Homepage]
    CS[CrowdSec in Docker, plus a native firewall bouncer over SSH]
    MON[Helm: Prometheus, Grafana, Loki]
  end
  H --> K --> KC
  KC --> D
  KC --> CS
  KC --> MON
```

Ansible prepares the host: UFW rules, SSH configuration, the K3s install, and fetching the
kubeconfig back so the laptop can reach the cluster. Terraform places what runs on top, mostly as
Docker containers and Helm releases. Two pieces cross onto the host anyway: CrowdSec's firewall
bouncer has to edit iptables, so Terraform installs it natively over SSH, and Grafana Alloy's
config file is written to the host the same way.

Keeping that split mostly clean is what makes a single `terraform apply` safe. Terraform installs CRDs
before the charts that need them, so there is no manual sequencing, and rebuilding the host does
not mean rebuilding the workloads by hand.

A third layer for custom applications is sketched but not built.

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

# Complete infrastructure deployment (system hardening + K3s)
ansible-playbook -i ansible/inventory.yml ansible/site.yml

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

3. **Configure Services (Optional)**

```bash
# Set up Wake-on-LAN for Homebridge (automated)
ansible-playbook -i ansible/inventory-wol.yml ansible/playbooks/setup-homebridge-wol.yml
```

## Services

| Service           | Description                            | Port      | Status    |
| ----------------- | -------------------------------------- | --------- | --------- |
| **HomeAssistant** | Home automation platform               | 8123      | ✅ Active |
| **Homebridge**    | HomeKit bridge for non-HomeKit devices | 8581      | ✅ Active |
| **Homepage**      | Dashboard and service portal           | 80        | ✅ Active |
| **Pi-hole**       | DNS-based ad blocker                   | 8080      | ✅ Active |
| **OpenSpeedTest** | Network speed testing                  | 3000/3001 | ✅ Active |

## Security

- ✅ No privileged containers
- ✅ Resource limits on all containers
- ✅ Health checks and restart policies
- ✅ Read-only Docker socket mounts
- ✅ Minimal container capabilities
- ✅ Structured logging with rotation

## Configuration

### Home Assistant

1. Access HomeAssistant at `http://your-pi-hostname:8123`
2. Complete initial setup
3. **HACS Installation**: Automatically installed when `enable_hacs = true` (default)
   - Navigate to Settings → Devices & Services
   - Add HACS integration and authenticate with GitHub
   - See [docs/homeassistant-hacs-setup.md](docs/homeassistant-hacs-setup.md) for details

### Homebridge

1. Access Homebridge at `http://your-pi-hostname:8581`
2. Complete the setup wizard (auto-generates PIN and QR codes)
3. **Wake-on-LAN Setup**: Use automated Ansible playbook (recommended)
   ```bash
   # Automated SSH key setup for WoL functionality
   ansible-playbook -i ansible/inventory-wol.yml ansible/playbooks/setup-homebridge-wol.yml
   ```
4. Install Wake-on-LAN plugin via web UI:
   - Go to Plugins tab → Search "homebridge-wol" → Install
5. Add to iOS Home app using the QR code or PIN

**Detailed Setup Guides:**
- [Homebridge Infrastructure & Configuration](docs/homebridge-setup.md)
- [Wake-on-LAN Setup Guide](docs/homebridge-wol-manual-setup.md) - **Automated + Manual methods**

### USB devices

For Zigbee/Z-Wave dongles, set in `terraform.tfvars`:

```hcl
enable_usb_devices = true
enable_hacs = true  # Enable HACS installation (default)
```

## Maintenance

### Viewing logs

```bash
docker logs homeassistant
docker logs pihole
```

### Updating containers

Updates are managed via Terraform. To update a container:

```bash
docker pull ghcr.io/home-assistant/home-assistant:stable
terraform apply -replace=module.homeassistant.docker_container.homeassistant
```

### Backing up configuration

```bash
docker run --rm -v homeassistant_configuration:/source -v $(pwd):/backup alpine tar czf /backup/homeassistant-backup.tar.gz -C /source .
```

## Troubleshooting

### Container problems

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

### Terraform problems

```bash
# Check what Terraform wants to change
terraform plan

# Target specific module if needed
terraform apply -target=module.homepage

# Refresh state if containers changed outside Terraform
terraform refresh
```

### Network problems

- Ensure SSH access is working
- Check Docker context: `docker context ls`
- Verify Pi-hole DNS on port 8080 (not 80)
- Homepage host validation resolved automatically

## Configuration variables

Key options in `terraform.tfvars`:

### Connection settings

```hcl
raspberry_pi_hostname = "raspberrypi-5"  # Your Pi's hostname or IP
raspberry_pi_user = "rainforest"         # SSH username
raspberry_pi_port = 22                   # SSH port
```

### Hardware options

```hcl
enable_usb_devices = true     # Enable for Zigbee/Z-Wave dongles
homeassistant_memory = 1024   # Memory limit in MB
homebridge_memory = 512       # Homebridge memory limit in MB
```

### Network ports

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
