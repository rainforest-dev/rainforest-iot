# Homebridge Setup Guide

## Initial Setup
1. Access Homebridge web interface: `http://192.168.0.134:8581`
2. Complete the setup wizard
3. Homebridge will auto-generate secure HomeKit PIN and QR codes

## Wake-on-LAN Plugin Setup
1. Go to "Plugins" tab in Homebridge web UI
2. Search and install: `homebridge-wol` or `homebridge-computer`
3. Configure with your PC details:
   - **MAC Address**: `d8:43:ae:cb:e3:75` (Ethernet interface)
   - **IP/Hostname**: `rainforest-ubuntu` or `192.168.0.131`
   - **Name**: `Rainforest Ubuntu PC`

## Recommended Plugins
- `homebridge-wol` - Simple Wake-on-LAN switch
- `homebridge-computer` - Advanced PC control (wake, shutdown, status)
- `homebridge-config-ui-x` - Web interface (pre-installed)

## HomeKit Integration
1. Open iOS Home app
2. Tap "+" → "Add Accessory"
3. Scan QR code from Homebridge web interface
4. Or manually enter the PIN shown in web interface

## Security Notes
- Homebridge auto-generates unique HomeKit PINs
- No need to hardcode PINs in configuration
- Change default bridge username if desired for security