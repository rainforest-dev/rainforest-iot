# Ansible Homelab Automation

This directory contains Ansible playbooks for managing your Raspberry Pi 5 homelab infrastructure.

## **Ansible vs Terraform Comparison**

| Tool | Purpose | Best For | In Your Stack |
|------|---------|----------|---------------|
| **Terraform** | Infrastructure Provisioning | Creating resources | Docker containers, K8s resources |
| **Ansible** | Configuration Management | Configuring systems | OS setup, K3s install, security |

## **Quick Start**

### 1. Install Ansible
```bash
# macOS
brew install ansible

# Ubuntu/Debian  
sudo apt update && sudo apt install ansible

# Python pip
pip install ansible
```

### 2. Test Connection
```bash
cd ansible/
ansible raspberry_pi -m ping
```

### 3. Complete Setup (Recommended)
```bash
# Full homelab setup in one command
ansible-playbook site.yml

# This runs:
# 1. System preparation & package updates
# 2. Security hardening (SSH, firewall, fail2ban)
# 3. K3s installation with Pi 5 optimizations
```

### 4. Individual Playbooks
```bash
# System preparation only
ansible-playbook playbooks/system-prep.yml

# Security hardening only
ansible-playbook playbooks/system-hardening.yml

# K3s installation only
ansible-playbook playbooks/k3s-install.yml

# Validate everything is working
ansible-playbook playbooks/validate-setup.yml
```

### 5. Quick Health Check
```bash
# Run validation without changes
ansible-playbook playbooks/validate-setup.yml --check
```

## **Available Playbooks**

### 🚀 k3s-install.yml
- Installs K3s on Raspberry Pi 5
- Configures memory cgroups  
- Sets up kubectl access
- **Alternative to**: Manual K3s installation

### 🔒 system-hardening.yml  
- SSH security configuration
- Firewall (UFW) setup
- Fail2Ban intrusion prevention
- Automatic security updates
- System monitoring scripts

## **Integration with Terraform**

**Recommended Workflow:**
```bash
# 1. System preparation (Ansible)
ansible-playbook playbooks/system-hardening.yml

# 2. K3s installation (Ansible OR manual)
ansible-playbook playbooks/k3s-install.yml

# 3. Infrastructure deployment (Terraform)
terraform apply  # Docker services + K8s monitoring
```

## **K3s API access naming (.local and TLS SANs)**

Ansible ensures kubectl/Terraform can access the API from any LAN machine by:

- __Managing K3s certificate SANs__: Deploys `/etc/rancher/k3s/config.yaml` with `tls-san` including:
  - `{{ inventory_hostname }}.local`
  - `{{ inventory_hostname }}`
  - `localhost`
  Cert changes trigger a handler to rotate certs and restart K3s.

- __Normalizing kubeconfig server__: Rewrites the server URL to `https://{{ inventory_hostname }}.local:6443` in:
  - `/etc/rancher/k3s/k3s.yaml` (on the Pi)
  - `/home/{{ ansible_user }}/.kube/config` (on the Pi)
  Then fetches it to the controller as `~/.kube/config-{{ inventory_hostname }}`.

Notes:
- `.local` relies on mDNS. Ensure Bonjour (macOS) or Avahi/`nss-mdns` (Linux) on client machines.
- For Tailscale access, add your MagicDNS name to `k3s_tls_sans` and update kubeconfig accordingly.

## **Inventory Structure**

```yaml
raspberry_pi:
  hosts:
    raspberrypi-5:
      pi_model: "5"
      memory_gb: 8

mac_mini:
  hosts:
    mac-mini-m4:
      docker_host: "dockerproxy.orb.local:2375"
```

## **Custom Variables**

Edit `inventory.yml` to customize:
- SSH keys and users
- Network configuration  
- Security settings
- Monitoring preferences

## **Security Features**

- ✅ SSH hardening (key-only, no root)
- ✅ Firewall with minimal open ports
- ✅ Intrusion detection (Fail2Ban)
- ✅ Automatic security updates
- ✅ System monitoring and alerting
- ✅ Log rotation and cleanup

## **Monitoring Integration**

The system-hardening playbook creates:
- `/var/log/homelab-status.log` - System metrics
- `/usr/local/bin/homelab-monitor.sh` - Monitoring script
- Cron job running every 15 minutes

This integrates with your Prometheus/Loki stack for comprehensive monitoring.

## **Advanced Usage**

### Run on Specific Hosts
```bash
ansible-playbook -l raspberrypi-5 playbooks/k3s-install.yml
```

### Dry Run (Check Mode)
```bash
ansible-playbook --check playbooks/system-hardening.yml
```

### Override Variables
```bash
ansible-playbook -e "ufw_enabled=false" playbooks/system-hardening.yml
```

### Generate SSH Key for Automation
```bash
ssh-keygen -t ed25519 -f ~/.ssh/homelab_ed25519
ssh-copy-id -i ~/.ssh/homelab_ed25519.pub rainforest@raspberrypi-5
```

## **Future Expansion**

This Ansible setup scales to:
- Multiple Raspberry Pis
- PC GitHub runners  
- Mac mini configuration
- Automated backups
- Certificate management
- Service health checks