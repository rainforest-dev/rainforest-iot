# Homebridge Wake-on-LAN Setup Guide

## Overview

This guide covers both automated (Ansible) and manual setup methods for Homebridge Wake-on-LAN functionality. The Ansible method is recommended for new deployments and multiple target machines.

## 🚀 Quick Setup (Recommended)

### Automated Setup with Ansible

For new deployments or multiple target machines, use the Ansible playbook:

```bash
# Run the automated SSH key setup
ansible-playbook -i ansible/inventory-wol.yml ansible/playbooks/setup-homebridge-wol.yml

# Or for comprehensive setup with WoL configuration
ansible-playbook -i ansible/inventory-wol.yml ansible/playbooks/homebridge-ssh-setup.yml
```

This will:
- Generate SSH keys in the Homebridge container
- Distribute public keys to target machines  
- Test SSH connections and sudo access
- Provide Homebridge configuration snippets

### Add Target Machines

Edit the playbook's `target_hosts` variable to add more machines:

```yaml
target_hosts:
  - { host: "192.168.100.10", user: "rainforest", name: "rainforest-ubuntu" }
  - { host: "192.168.100.20", user: "user2", name: "machine2" }
  # Add more as needed
```

---

## 📋 Manual Setup (Legacy)

This section covers the manual setup steps that were required before the Ansible automation was available.

## Prerequisites

- Raspberry Pi 5 running Homebridge (deployed via Terraform)
- Target machine (rainforest-ubuntu) with Ethernet connection
- Both machines on the same network segment for WoL

## Architecture

```
┌─────────────────┐    Ethernet     ┌─────────────────┐
│  Raspberry Pi   │◄───────────────►│ rainforest-     │
│                 │ 192.168.100.5   │ ubuntu          │
│ - Homebridge    │                 │ 192.168.100.10  │
│ - WiFi Internet │                 │                 │
│ - Ethernet WoL  │                 │ - WiFi Internet │
└─────────────────┘                 │ - Ethernet WoL  │
                                    └─────────────────┘
```

## Step 1: Configure Dual Network Setup

### 1.1 Configure rainforest-ubuntu Ethernet Interface

```bash
# Backup current configuration
sudo cp /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.backup

# Configure static IP for Ethernet
sudo tee /etc/netplan/50-cloud-init.yaml << 'EOF'
network:
  version: 2
  ethernets:
    enp5s0:
      addresses:
        - 192.168.100.10/24
      dhcp4: false
      optional: true
EOF

# Apply configuration
sudo netplan apply
```

### 1.2 Configure Raspberry Pi Ethernet Interface

```bash
# Configure Ethernet interface with NetworkManager
sudo nmcli connection modify 'Wired connection 1' ipv4.method manual ipv4.addresses 192.168.100.5/24

# Activate the connection
sudo nmcli connection up 'Wired connection 1'
```

### 1.3 Verify Dual Network Configuration

**On rainforest-ubuntu:**
```bash
ip addr show  # Should show both WiFi (192.168.0.x) and Ethernet (192.168.100.10)
ping -c 2 8.8.8.8  # Test internet via WiFi
ping -c 2 192.168.100.5  # Test Ethernet connection to Pi
```

**On Raspberry Pi:**
```bash
ip addr show  # Should show both WiFi (192.168.0.x) and Ethernet (192.168.100.5)
ping -c 2 8.8.8.8  # Test internet via WiFi
ping -c 2 192.168.100.10  # Test Ethernet connection to Ubuntu
```

## Step 2: SSH Key Setup

### 2.1 Generate SSH Key on Raspberry Pi

```bash
# Generate SSH key if not exists
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''
```

### 2.2 Copy Public Key to Ubuntu

Since `ssh-copy-id` may have host key verification issues, manually copy the key:

```bash
# On Pi: Get the public key
cat ~/.ssh/id_ed25519.pub

# On Ubuntu: Add key to authorized_keys
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPPcMDnlHtU4OArj82Ns72SRi/gGWLtytBmaE20idoxw rainforest@raspberrypi-5' >> ~/.ssh/authorized_keys
```

### 2.3 Test SSH Connection

```bash
# From Pi to Ubuntu (should work without password)
ssh rainforest@192.168.100.10 'hostname'
```

## Step 3: Configure Wake-on-LAN

### 3.1 Enable WoL in NetworkManager (Ubuntu)

The issue with WoL not working is that NetworkManager overrides the WoL setting. Fix this:

```bash
# Find the active Ethernet connection
sudo nmcli connection show --active | grep ethernet

# Enable WoL in NetworkManager (replace 'netplan-enp5s0' with your connection name)
sudo nmcli connection modify 'netplan-enp5s0' 802-3-ethernet.wake-on-lan magic

# Restart the connection
sudo nmcli connection up 'netplan-enp5s0'

# Verify WoL is enabled
sudo ethtool enp5s0 | grep 'Wake-on'
# Should show: Wake-on: g
```

### 3.2 Remove Redundant WoL Service

Since NetworkManager now handles WoL properly, remove the manual service:

```bash
# Disable the manual WoL service (if it exists)
sudo systemctl disable wol-enable.service
sudo systemctl stop wol-enable.service
```

### 3.3 Configure Passwordless Sudo for Shutdown

```bash
# On Ubuntu: Allow passwordless shutdown
echo 'rainforest ALL=(ALL) NOPASSWD: /sbin/shutdown' | sudo tee /etc/sudoers.d/homebridge-shutdown

# Test from Pi
ssh rainforest@192.168.100.10 'sudo shutdown --help'
```

## Step 4: Configure Homebridge Container SSH Access

### 4.1 Copy SSH Keys to Container

The Homebridge container needs access to SSH keys to execute shutdown commands:

```bash
# Create SSH directory in container
docker exec homebridge mkdir -p /homebridge/.ssh

# Copy private key to container
docker cp ~/.ssh/id_ed25519 homebridge:/homebridge/.ssh/id_ed25519

# Copy public key to container
docker cp ~/.ssh/id_ed25519.pub homebridge:/homebridge/.ssh/id_ed25519.pub

# Set proper permissions in container
docker exec homebridge chmod 600 /homebridge/.ssh/id_ed25519
docker exec homebridge chmod 644 /homebridge/.ssh/id_ed25519.pub
docker exec homebridge chown -R abc:abc /homebridge/.ssh
```

### 4.2 Add Known Hosts Entry

```bash
# Accept host key in container
docker exec homebridge ssh -o StrictHostKeyChecking=no rainforest@192.168.100.10 'hostname'
```

## Step 5: Homebridge Configuration

### 5.1 Correct Plugin Configuration

Add this to Homebridge accessories configuration:

```json
{
  "accessory": "NetworkDevice",
  "name": "rainforest-ubuntu",
  "manufacturer": "homebridge-wol",
  "model": "NetworkDevice",
  "mac": "d8:43:ae:cb:e3:75",
  "host": "192.168.100.10",
  "broadcastAddress": "192.168.100.255",
  "pingInterval": 2,
  "pingsToChange": 5,
  "pingTimeout": 1,
  "wakeGraceTime": 45,
  "shutdownGraceTime": 15,
  "shutdownCommand": "ssh rainforest@192.168.100.10 'sudo shutdown -h now'",
  "logLevel": "Info"
}
```

## Step 6: Testing

### 6.1 Test Wake-on-LAN

```bash
# From Pi: Test WoL command
wakeonlan -i 192.168.100.255 d8:43:ae:cb:e3:75

# Wait 15-30 seconds, then test if Ubuntu is online
ping -c 1 192.168.100.10
```

### 6.2 Test Shutdown from Container

```bash
# Test shutdown from Homebridge container
docker exec homebridge ssh rainforest@192.168.100.10 'sudo shutdown -h now'
```

## Troubleshooting

### Common Issues

1. **WoL not working**: Check BIOS settings, ensure NetworkManager WoL is set to 'magic'
2. **SSH connection refused**: Verify SSH keys are properly copied to container
3. **Permission denied on shutdown**: Check sudoers configuration
4. **Host key verification failed**: Accept host key in container with StrictHostKeyChecking=no

### Verification Commands

```bash
# Check WoL status
sudo ethtool enp5s0 | grep Wake-on

# Check NetworkManager WoL setting
sudo nmcli connection show 'netplan-enp5s0' | grep wake

# Test SSH from container
docker exec homebridge ssh rainforest@192.168.100.10 'hostname'

# Check Homebridge logs
docker logs homebridge --tail 20
```

## Network Configuration Details

### IP Assignments
- **Pi WiFi**: `192.168.0.134/24` (DHCP, internet access)
- **Pi Ethernet**: `192.168.100.5/24` (static, direct connection)
- **Ubuntu WiFi**: `192.168.0.131/24` (DHCP, internet access)  
- **Ubuntu Ethernet**: `192.168.100.10/24` (static, direct connection)

### MAC Addresses
- **Pi Ethernet**: `2c:cf:67:3d:3f:3c`
- **Ubuntu Ethernet**: `d8:43:ae:cb:e3:75` (used for WoL)

## Security Considerations

- SSH keys are stored in Homebridge container volume
- Passwordless sudo is limited to shutdown command only
- Network isolation between WiFi and Ethernet segments
- Consider firewall rules if needed

## Limitations

- This setup cannot be fully automated in Terraform due to:
  - Container SSH key management complexity
  - NetworkManager configuration timing
  - Cross-machine SSH setup requirements
  - BIOS-level WoL settings

## Maintenance

- SSH keys persist across container restarts (stored in volume)
- NetworkManager WoL setting persists across reboots
- Monitor Homebridge logs for connection issues
- Periodically test WoL functionality