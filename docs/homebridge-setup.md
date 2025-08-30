# Homebridge Setup and Configuration

## Overview

This document describes the setup and configuration of Homebridge on the Raspberry Pi 5, including automatic firewall configuration and homepage integration.

## Infrastructure Components

### 1. Homebridge Module (`modules/homebridge/`)

The Homebridge module provisions:
- Docker container running `homebridge/homebridge:latest`
- Host networking mode (required for HomeKit discovery)
- Web UI on port 8581
- Persistent data volume
- UFW firewall rule automation

### 2. Automatic Firewall Configuration

The module includes automated UFW firewall management:

```terraform
resource "null_resource" "homebridge_firewall_rule" {
  triggers = {
    container_id = docker_container.homebridge.id
    web_port     = var.web_port
  }

  provisioner "remote-exec" {
    inline = [
      "sudo ufw allow ${var.web_port}/tcp comment 'Homebridge Web UI'",
      "echo 'Firewall rule added for Homebridge port ${var.web_port}'"
    ]
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "sudo ufw delete allow ${var.web_port}/tcp || echo 'Rule already deleted'",
      "echo 'Firewall rule removed for Homebridge port ${var.web_port}'"
    ]
  }
}
```

**Benefits:**
- Automatically opens port 8581 when Homebridge is deployed
- Removes the firewall rule when Homebridge is destroyed
- Eliminates manual firewall configuration
- Ensures consistency across deployments

### 3. Homepage Integration

Homebridge is automatically added to the homepage dashboard:

```yaml
- "Raspberry Pi 5 (IoT Platform)":
    - Homebridge:
        href: http://${raspberry_pi_hostname}:8581
        description: "HomeKit Bridge"
        icon: homebridge.png
        server: pi5-docker
        container: homebridge
```

## Configuration Variables

The Homebridge module accepts these variables:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `hostname` | Raspberry Pi hostname | `raspberrypi-5` | No |
| `pi_hostname` | SSH hostname for connection | - | Yes |
| `pi_user` | SSH user for connection | - | Yes |
| `pi_port` | SSH port for connection | `22` | No |
| `memory_limit` | Container memory limit (MB) | `512` | No |
| `web_port` | Web UI port | `8581` | No |
| `timezone` | Container timezone | `Asia/Taipei` | No |
| `log_opts` | Docker logging options | See defaults | No |

## Initial Setup Process

1. **Infrastructure Deployment**
   ```bash
   terraform apply
   ```

2. **Access Web UI**
   - URL: `http://raspberrypi-5.local:8581`
   - The firewall rule is automatically configured

3. **Complete Homebridge Setup**
   - Use the PIN from container logs: `207-91-627`
   - Or scan QR code: `X-HM://0023TB70RQ9G9`

4. **Install Wake-on-LAN Plugin**
   - Go to Plugins tab
   - Search for "homebridge-wol"
   - Install and configure with PC details

## Wake-on-LAN Configuration

### Prerequisites
- Target PC must have WoL enabled in BIOS/UEFI
- Network adapter must support WoL
- PC must be connected via Ethernet
- Need PC's MAC address

### Recommended Plugins
1. **homebridge-wol** - Simple wake switch
2. **homebridge-computer** - Advanced PC control with status monitoring

### Configuration Example
```json
{
  "platforms": [
    {
      "platform": "WakeOnLan",
      "devices": [
        {
          "name": "PC",
          "mac": "XX:XX:XX:XX:XX:XX",
          "ip": "192.168.1.100",
          "broadcastAddress": "192.168.1.255"
        }
      ]
    }
  ]
}
```

## HomeKit Integration

1. **Add Bridge to Home App**
   - Open iOS Home app
   - Tap "+" → Add Accessory
   - Scan QR code or enter PIN manually

2. **Device Management**
   - Devices appear as HomeKit switches
   - Control via Home app, Siri, or automations
   - Supports scenes and automations

## Troubleshooting

### Common Issues

1. **Web UI Not Accessible**
   ```bash
   # Check container status
   docker ps --filter name=homebridge
   
   # Check firewall status
   sudo ufw status | grep 8581
   
   # View container logs
   docker logs homebridge
   ```

2. **HomeKit Pairing Issues**
   - Ensure host networking is enabled
   - Check that port 51826 is accessible
   - Restart container if needed

3. **Wake-on-LAN Not Working**
   - Verify WoL is enabled in PC BIOS
   - Check network adapter settings
   - Test with wakeonlan utility first

### Log Locations
- Container logs: `docker logs homebridge`
- Homebridge logs: Inside container at `/homebridge/logs/`
- Configuration: `/homebridge/config.json`

## Security Considerations

1. **Network Security**
   - Homebridge uses host networking (required for HomeKit)
   - Web UI is accessible on local network only
   - Consider VPN for remote access

2. **HomeKit Security**
   - Uses encrypted communication
   - Requires device pairing
   - PIN-based authentication

3. **Firewall Management**
   - Only necessary ports are opened
   - Rules are automatically managed
   - Cleanup on infrastructure destruction

## Backup and Recovery

### Configuration Backup
```bash
# Backup Homebridge configuration
docker cp homebridge:/homebridge/config.json ~/homebridge-config-backup.json

# Backup entire data volume
docker run --rm -v homebridge_data:/data -v $(pwd):/backup alpine tar czf /backup/homebridge-backup.tar.gz /data
```

### Recovery
```bash
# Restore configuration
docker cp ~/homebridge-config-backup.json homebridge:/homebridge/config.json

# Restart container
docker restart homebridge
```

## Integration with Other Services

### HomeAssistant Integration
- Can discover Homebridge devices
- Allows advanced automation
- Provides additional device types

### Monitoring Integration
- Container health checks via Docker
- Homepage dashboard integration
- Prometheus metrics (if configured)

## Updates and Maintenance

### Container Updates
```bash
# Terraform will handle updates
terraform apply

# Manual update (if needed)
docker pull homebridge/homebridge:latest
docker restart homebridge
```

### Plugin Updates
- Updates managed via Web UI
- Automatic update notifications
- Backup before major updates

## References

- [Homebridge Documentation](https://homebridge.io/)
- [Homebridge Wiki](https://github.com/homebridge/homebridge/wiki)
- [HomeKit Specification](https://developer.apple.com/homekit/)
- [Wake-on-LAN Plugin](https://github.com/AlexGustafsson/homebridge-wol)