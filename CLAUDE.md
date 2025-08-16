# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a secure, containerized IoT platform for Raspberry Pi 5 using Terraform for Infrastructure as Code and Docker for containerized services. The platform deploys and manages various IoT services including HomeAssistant, Pi-hole, Homepage dashboard, Watchtower, and OpenSpeedTest via SSH-based remote management.

## Essential Commands

### Initial Setup
```bash
# Copy and configure connection settings
cp terraform.tfvars.example terraform.tfvars

# Create Docker context for remote Pi deployment
docker context create raspberrypi-5 --docker "host=ssh://raspberrypi-5"
```

### Core Terraform Operations
```bash
# Initialize Terraform
terraform init

# Plan deployment (safe to run repeatedly)
terraform plan

# Apply infrastructure changes
terraform apply

# Destroy infrastructure
terraform destroy

# Target specific module for changes
terraform apply -target=module.homepage

# Replace specific service container (rarely needed)
terraform apply -replace=module.homeassistant.docker_container.homeassistant
```

### Service Management
```bash
# View container logs on remote Pi
docker logs homeassistant
docker logs pihole
docker logs watchtower

# Check container status
docker ps -a

# Manual container update
docker pull ghcr.io/home-assistant/home-assistant:stable
```

### Backup Operations
```bash
# Backup HomeAssistant configuration
docker run --rm -v homeassistant_configuration:/source -v $(pwd):/backup alpine tar czf /backup/homeassistant-backup.tar.gz -C /source .
```

## Architecture

### Infrastructure Pattern
- **Remote Deployment**: Uses Docker provider with SSH connection to Raspberry Pi
- **Modular Design**: Each service is a separate Terraform module in `modules/` directory
- **Security Hardened**: No privileged containers, resource limits, minimal capabilities
- **Configuration Driven**: All customization via `terraform.tfvars`
- **Lifecycle Management**: Prevents unnecessary container recreation, only updates when needed
- **Connection Reliability**: SSH keepalive settings prevent timeouts during operations

### Key Components
- **main.tf**: Root module orchestrating all service modules
- **variables.tf**: Input variable definitions with defaults
- **locals.tf**: Computed values including SSH connection strings and common configs
- **modules/**: Service-specific Terraform modules (homeassistant, pi-hole, homepage, watchtower, openspeedtest)

### Service Modules Structure
Each module in `modules/` contains:
- `main.tf`: Docker resources (image, container, volumes)
- `variables.tf`: Module-specific input variables
- Configuration files where applicable

### Connection Architecture
```
Client Machine (Terraform) --SSH--> Raspberry Pi (Docker Engine)
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

| Service | Port | Purpose |
|---------|------|---------|
| HomeAssistant | 8123 | Home automation web interface |
| Homepage | 80 | Dashboard and service portal |
| Pi-hole | 8080 | DNS ad-blocker web interface |
| OpenSpeedTest | 3000/3001 | Network speed testing (HTTP/HTTPS) |

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

#### Container Recreation Errors
```bash
# If containers show as needing replacement unnecessarily:
terraform plan  # Check what changes are proposed

# For state mismatches, target specific modules:
terraform apply -target=module.homepage

# For SSH timeout issues, check connection:
docker context use raspberrypi-5
docker ps  # Verify remote connection works
```

#### Homepage Host Validation
The Homepage service includes `HOMEPAGE_ALLOWED_HOSTS` environment variable to prevent host validation errors when accessing the dashboard.

#### Memory Limit Detection
Lifecycle rules ignore memory limit differences between Terraform config and runtime values, preventing false-positive recreation triggers.

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