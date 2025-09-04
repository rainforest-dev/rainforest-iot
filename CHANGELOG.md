# Infrastructure Changelog

## 2025-08-30 - HACS Integration & Documentation Updates

### Added

- **HACS (Home Assistant Community Store) Support**
  - Automatic installation when `enable_hacs = true` (default)
  - Integration with HomeAssistant container startup process
  - Comprehensive setup documentation in `docs/homeassistant-hacs-setup.md`

- **Enhanced Terraform Configuration**
  - Updated `terraform.tfvars.example` with all current variables
  - Added Kubernetes monitoring configuration options
  - Included Homebridge configuration variables
  - Added homepage dashboard customization options

- **Improved Documentation Structure**
  - Updated README.md with HACS installation instructions
  - Enhanced deployment guide with current service architecture
  - Added monitoring service URLs and configuration details

### Technical Implementation

#### HACS Installation Process
- Automatic download and installation via container init script
- Configuration persistence in HomeAssistant volume
- GitHub OAuth integration for community store access

#### Documentation Improvements
- Comprehensive variable documentation in `terraform.tfvars.example`
- Updated service port mappings
- Enhanced troubleshooting sections

### Files Modified
- `terraform.tfvars.example` - Added missing variables and configurations
- `README.md` - Updated with HACS support and current features
- `docs/deployment-guide.md` - Enhanced with current architecture
- `docs/homeassistant-hacs-setup.md` - Comprehensive HACS documentation

---

## 2025-08-31 - Homebridge Firewall Automation & Homepage Integration

### Added

- **Automated UFW Firewall Management for Homebridge**

  - `null_resource.homebridge_firewall_rule` in Homebridge module
  - Automatically opens port 8581/tcp when Homebridge is deployed
  - Automatically removes firewall rule when Homebridge is destroyed
  - Eliminates manual firewall configuration step

- **Homepage Dashboard Integration**

  - Added Homebridge to "Raspberry Pi 5 (IoT Platform)" section
  - Accessible at `http://raspberrypi-5.local:8581`
  - Integrated with Docker container monitoring

- **Enhanced Module Variables**
  - Added `pi_hostname`, `pi_user`, `pi_port` variables to Homebridge module
  - Enables SSH provisioner for firewall management
  - Maintains backward compatibility

### Technical Implementation

#### Firewall Automation

```terraform
resource "null_resource" "homebridge_firewall_rule" {
  triggers = {
    container_id = docker_container.homebridge.id
    web_port     = var.web_port
  }

  provisioner "remote-exec" {
    inline = [
      "sudo ufw allow ${var.web_port}/tcp comment 'Homebridge Web UI'",
    ]
    connection {
      type = "ssh"
      host = var.pi_hostname
      user = var.pi_user
      port = var.pi_port
    }
  }
}
```

#### Homepage Integration

```yaml
- Homebridge:
    href: http://${raspberry_pi_hostname}:8581
    description: "HomeKit Bridge"
    icon: homebridge.png
    server: pi5-docker
    container: homebridge
```

### Benefits

1. **Zero-Configuration Deployment**: Firewall rules are managed automatically
2. **Consistent Infrastructure**: No manual post-deployment steps required
3. **Better Monitoring**: Homebridge visible in central dashboard
4. **Cleanup on Destroy**: Firewall rules are removed when infrastructure is torn down

### Files Modified

- `modules/homebridge/main.tf` - Added firewall provisioner
- `modules/homebridge/variables.tf` - Added SSH connection variables
- `main.tf` - Updated Homebridge module call with new variables
- `modules/homepage/templates/services.yaml.tpl` - Added Homebridge service entry
- `docs/homebridge-setup.md` - Comprehensive documentation

### Breaking Changes

None - all changes are backward compatible.

### Migration Notes

Existing deployments will automatically get the firewall rule on next `terraform apply`.
No manual intervention required.

---

## Previous Changes

[Previous changelog entries would go here...]
