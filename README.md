# Rainforest IoT Platform

A secure, containerized IoT platform for Raspberry Pi 5 using Terraform and Docker.

## Architecture

- **Infrastructure as Code**: Terraform modules for reproducible deployments
- **Containerized Services**: Docker containers with security hardening
- **Remote Management**: SSH-based deployment from client machine
- **Modular Design**: Independent service modules for easy maintenance
- **Smart Lifecycle Management**: Prevents unnecessary container recreation
- **Connection Reliability**: SSH keepalive for stable remote operations

## Prerequisites

- Raspberry Pi 5 with Docker installed
- SSH access configured
- Terraform >= 1.0 installed on client machine

## Quick Start

1. **Configure Connection**
```bash
# Copy and edit configuration
cp terraform.tfvars.example terraform.tfvars

# Edit your Pi's hostname/IP in terraform.tfvars:
# raspberry_pi_hostname = "your-pi-hostname"  # or IP like "192.168.1.100"
```

2. **Create Docker Context**
```bash
# Use your actual hostname or IP
docker context create raspberrypi-5 --docker "host=ssh://raspberrypi-5"
```

3. **Deploy Infrastructure**
```bash
terraform init
terraform plan    # Safe to run repeatedly
terraform apply   # Only updates what changed
```

## Services

| Service | Description | Port | Status |
|---------|-------------|------|--------|
| **HomeAssistant** | Home automation platform | 8123 | ✅ Active |
| **Homepage** | Dashboard and service portal | 80 | ✅ Active |
| **Pi-hole** | DNS-based ad blocker | 8080 | ✅ Active |
| **Watchtower** | Automatic container updates | - | ✅ Active |
| **OpenSpeedTest** | Network speed testing | 3000/3001 | ✅ Active |

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
3. Install HACS (optional):
```bash
docker exec -it homeassistant bash
wget -O - https://get.hacs.xyz | bash -
```

### USB Device Support
For Zigbee/Z-Wave dongles, set in `terraform.tfvars`:
```hcl
enable_usb_devices = true
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
enable_usb_devices = true    # Enable for Zigbee/Z-Wave dongles
homeassistant_memory = 1024  # Memory limit in MB
```

### Network Ports
```hcl
homepage_port = 80           # Dashboard port
pihole_web_port = 8080      # Pi-hole admin interface
openspeedtest_ports = {
  http  = 3000
  https = 3001
}
```

See `variables.tf` for all customizable options.