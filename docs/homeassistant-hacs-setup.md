# Home Assistant HACS Setup Guide

## Overview

HACS (Home Assistant Community Store) is automatically installed with your HomeAssistant deployment when `enable_hacs = true` in your Terraform configuration.

## Automatic Installation

HACS is installed automatically via Terraform when the HomeAssistant container starts. The installation script:

1. Downloads the latest HACS release
2. Installs it to `/config/custom_components/hacs`
3. Configures it for immediate use

## Initial Setup

After deployment, complete HACS setup:

1. **Access HomeAssistant**: `http://raspberrypi-5.local:8123`

2. **Navigate to HACS**:

   - Go to Settings → Devices & Services
   - Click "Add Integration"
   - Search for "HACS"
   - Click to configure

3. **GitHub Authentication**:

   - You'll need to authenticate with GitHub
   - Follow the OAuth flow to grant HACS access
   - This allows HACS to download community integrations

4. **Complete Configuration**:
   - Accept the terms and conditions
   - Select your country
   - HACS will download the repository list

## What HACS Provides

### 🔌 Integrations

- **Custom Components**: Extended functionality for HomeAssistant
- **Device Support**: Additional device integrations
- **Service Integrations**: Connect to external services

### 🎨 Frontend Elements

- **Lovelace Cards**: Custom dashboard cards
- **Themes**: Beautiful UI themes
- **Icons**: Extended icon sets

### 🤖 AppDaemon Apps

- **Automation Apps**: Advanced automation scripts
- **Custom Logic**: Complex automation scenarios

## Popular HACS Integrations

### Recommended Integrations

- **Frigate**: NVR with AI object detection
- **Node-RED**: Visual automation editor
- **MQTT Discovery**: Enhanced MQTT support
- **Xiaomi Cloud Map Extractor**: Vacuum map support

### Recommended Frontend

- **Mushroom Cards**: Modern, minimalist cards
- **Mini Graph Card**: Compact sensor graphs
- **Button Card**: Customizable action buttons
- **Auto-Entities**: Dynamic entity lists

## Configuration

### Enable/Disable HACS

In `terraform.tfvars`:

```hcl
enable_hacs = true  # Enable HACS installation
```

### Manual Installation (if needed)

If automatic installation fails:

```bash
# Connect to container
docker exec -it homeassistant bash

# Install HACS manually
cd /config
wget -O - https://get.hacs.xyz | bash -

# Restart HomeAssistant
exit
docker restart homeassistant
```

## Troubleshooting

### HACS Not Appearing

1. Check if installation completed:

   ```bash
   docker exec homeassistant ls -la /config/custom_components/
   ```

2. Restart HomeAssistant:

   ```bash
   docker restart homeassistant
   ```

3. Check logs:
   ```bash
   docker logs homeassistant | grep -i hacs
   ```

### GitHub Rate Limiting

- HACS may hit GitHub API rate limits
- Authenticate with GitHub token for higher limits
- Configure personal access token in HACS settings

### Integration Installation Issues

- Clear browser cache and reload
- Restart HomeAssistant after installing integrations
- Check HomeAssistant logs for errors

## Security Considerations

### GitHub Authentication

- HACS requires GitHub OAuth for downloading
- Only grants read access to public repositories
- No access to your private repositories

### Custom Components

- Review custom integrations before installation
- Community components may have security implications
- Keep integrations updated via HACS

### Network Access

- HACS requires internet access to GitHub
- Downloads happen during installation
- Consider firewall rules if needed

## Backup and Updates

### HACS Updates

- HACS updates itself automatically
- Updates appear in HACS interface
- Restart HomeAssistant after HACS updates

### Integration Updates

- Check HACS regularly for updates
- Update integrations through HACS interface
- Test automations after major updates

### Backup Configuration

```bash
# Backup custom components
docker run --rm -v homeassistant_configuration:/source -v $(pwd):/backup \
  alpine tar czf /backup/hacs-backup.tar.gz -C /source custom_components
```

## Resources

- [HACS Documentation](https://hacs.xyz/)
- [HACS GitHub](https://github.com/hacs/integration)
- [HomeAssistant Community Forum](https://community.home-assistant.io/)
- [HACS Discord](https://discord.gg/apgchf8)
