# Phase 4: Persistence + Scheduling — Velero, rsync, Dashboards, Resource Quotas

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the homelab survive an RPi SD card failure: K3s PVCs backed up via Velero to Mac Mini MinIO (which syncs to NAS via Synology Drive), raw rsync of K3s local storage every 6 hours, all Grafana dashboards in git so they restore on `terraform apply`, CrowdSec signatures auto-updated daily, and K3s network policies + resource quotas enabled.

**Architecture:** Velero runs inside K3s on RPi; it writes PVC snapshots to Mac Mini MinIO (`http://192.168.0.126:9000`) over LAN — no Tailscale required. The RPi rsync targets the Mac Mini directly over LAN as well. All Grafana dashboard JSON lives in `modules/prometheus-stack/dashboards/` and is loaded via labeled ConfigMaps (the existing Grafana sidecar already watches for these). CrowdSec and rsync run via systemd timers managed by Ansible.

**Tech Stack:** Terraform Helm provider, velero/velero, Ansible, systemd, rsync

**Spec:** `docs/superpowers/specs/2026-05-21-homelab-security-monitoring-design.md` — Phase 4

---

## File Map

**rainforest-iot**

| Action | File |
|---|---|
| Create | `modules/velero/main.tf` |
| Create | `modules/velero/variables.tf` |
| Create | `modules/velero/outputs.tf` |
| Create | `modules/velero/versions.tf` |
| Create | `modules/prometheus-stack/dashboards/pihole-stats.json` |
| Create | `modules/prometheus-stack/dashboards/crowdsec-events.json` |
| Create | `modules/prometheus-stack/dashboards/blackbox-uptime.json` |
| Create | `modules/prometheus-stack/dashboards/resource-comparison.json` |
| Modify | `modules/prometheus-stack/main.tf` — add ConfigMap resources for new dashboards |
| Create | `ansible/playbooks/setup-backup.yml` — RPi rsync + CrowdSec hub update timers |
| Modify | `main.tf` — add velero module |
| Modify | `variables.tf` — add velero variables |
| Modify | `terraform.tfvars` — enable network policies + resource quotas; add velero config |

---

## Task 1: Grafana dashboards as code

**Goal:** All monitoring dashboards survive an RPi rebuild — `terraform apply` restores them automatically.

The existing pattern: `modules/prometheus-stack/main.tf` creates `kubernetes_config_map` resources with label `grafana_dashboard = "1"`. Grafana's sidecar watches for these labels and auto-imports the JSON. **Important:** Set `"id": null` in all dashboard JSON — the sidecar sets the database ID on import.

- [ ] **Step 1: Export existing dashboards from live Grafana**

For each dashboard you want to preserve, navigate to Grafana → Dashboard → Share → Export → Save to file:

1. `homelab-overview` — already in git at `modules/prometheus-stack/dashboards/homelab-overview.json` ✓
2. `kubernetes-cluster` — already in git at `modules/prometheus-stack/dashboards/kubernetes-cluster.json` ✓
3. Any other dashboards you've created manually (check Grafana → Dashboards list)

For each exported JSON, set `"id": null` at the top level before saving.

- [ ] **Step 2: Create Pi-hole stats dashboard JSON**

Save to `modules/prometheus-stack/dashboards/pihole-stats.json`:

```json
{
  "id": null,
  "title": "Pi-hole Statistics",
  "tags": ["homelab", "dns", "security"],
  "timezone": "browser",
  "schemaVersion": 39,
  "panels": [
    {
      "id": 1,
      "title": "Domains Blocked",
      "type": "stat",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [{
        "expr": "pihole_domains_being_blocked",
        "legendFormat": "Blocked domains"
      }],
      "gridPos": { "x": 0, "y": 0, "w": 6, "h": 4 }
    },
    {
      "id": 2,
      "title": "Queries Today",
      "type": "stat",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [{
        "expr": "pihole_dns_queries_today",
        "legendFormat": "DNS queries"
      }],
      "gridPos": { "x": 6, "y": 0, "w": 6, "h": 4 }
    },
    {
      "id": 3,
      "title": "Ads Blocked Today",
      "type": "stat",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [{
        "expr": "pihole_ads_blocked_today",
        "legendFormat": "Blocked today"
      }],
      "gridPos": { "x": 12, "y": 0, "w": 6, "h": 4 }
    },
    {
      "id": 4,
      "title": "Block Rate %",
      "type": "stat",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [{
        "expr": "pihole_ads_percentage_today",
        "legendFormat": "Block %"
      }],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "thresholds": {
            "steps": [
              { "color": "green", "value": null },
              { "color": "yellow", "value": 20 },
              { "color": "red", "value": 50 }
            ]
          }
        }
      },
      "gridPos": { "x": 18, "y": 0, "w": 6, "h": 4 }
    },
    {
      "id": 5,
      "title": "DNS Query Rate (per minute)",
      "type": "timeseries",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [{
        "expr": "rate(pihole_dns_queries_today[5m]) * 60",
        "legendFormat": "Queries/min"
      }],
      "gridPos": { "x": 0, "y": 4, "w": 24, "h": 8 }
    }
  ],
  "time": { "from": "now-24h", "to": "now" },
  "refresh": "1m"
}
```

- [ ] **Step 3: Create CrowdSec events dashboard JSON**

Save to `modules/prometheus-stack/dashboards/crowdsec-events.json`:

```json
{
  "id": null,
  "title": "CrowdSec Security Events",
  "tags": ["homelab", "security", "crowdsec"],
  "timezone": "browser",
  "schemaVersion": 39,
  "panels": [
    {
      "id": 1,
      "title": "Active Decisions (Banned IPs)",
      "type": "stat",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [{ "expr": "cs_active_decisions", "legendFormat": "Banned IPs" }],
      "fieldConfig": {
        "defaults": {
          "thresholds": {
            "steps": [
              { "color": "green", "value": null },
              { "color": "orange", "value": 1 },
              { "color": "red", "value": 10 }
            ]
          }
        }
      },
      "gridPos": { "x": 0, "y": 0, "w": 8, "h": 4 }
    },
    {
      "id": 2,
      "title": "Alerts (last 1h)",
      "type": "stat",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [{ "expr": "increase(cs_alerts[1h])", "legendFormat": "Alerts" }],
      "gridPos": { "x": 8, "y": 0, "w": 8, "h": 4 }
    },
    {
      "id": 3,
      "title": "Parsed Lines Rate",
      "type": "stat",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [{ "expr": "rate(cs_parsed_count[5m])", "legendFormat": "Lines/s" }],
      "gridPos": { "x": 16, "y": 0, "w": 8, "h": 4 }
    },
    {
      "id": 4,
      "title": "Decisions Over Time",
      "type": "timeseries",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        { "expr": "cs_active_decisions", "legendFormat": "Active bans" },
        { "expr": "increase(cs_alerts[5m])", "legendFormat": "New alerts" }
      ],
      "gridPos": { "x": 0, "y": 4, "w": 24, "h": 8 }
    }
  ],
  "time": { "from": "now-24h", "to": "now" },
  "refresh": "1m"
}
```

- [ ] **Step 4: Create Blackbox Exporter uptime dashboard JSON**

Save to `modules/prometheus-stack/dashboards/blackbox-uptime.json`:

```json
{
  "id": null,
  "title": "Service Uptime (Blackbox Exporter)",
  "tags": ["homelab", "uptime", "monitoring"],
  "timezone": "browser",
  "schemaVersion": 39,
  "panels": [
    {
      "id": 1,
      "title": "Service Status",
      "type": "table",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [{
        "expr": "probe_success",
        "legendFormat": "{{instance}}",
        "instant": true
      }],
      "fieldConfig": {
        "defaults": {
          "mappings": [
            { "options": { "0": { "text": "DOWN", "color": "red" }, "1": { "text": "UP", "color": "green" } }, "type": "value" }
          ]
        }
      },
      "gridPos": { "x": 0, "y": 0, "w": 12, "h": 8 }
    },
    {
      "id": 2,
      "title": "Probe Duration (ms)",
      "type": "table",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [{
        "expr": "probe_duration_seconds * 1000",
        "legendFormat": "{{instance}}",
        "instant": true
      }],
      "fieldConfig": { "defaults": { "unit": "ms" } },
      "gridPos": { "x": 12, "y": 0, "w": 12, "h": 8 }
    },
    {
      "id": 3,
      "title": "SSL Certificate Expiry (days)",
      "type": "table",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [{
        "expr": "(probe_ssl_earliest_cert_expiry - time()) / 86400",
        "legendFormat": "{{instance}}",
        "instant": true
      }],
      "fieldConfig": {
        "defaults": {
          "unit": "d",
          "thresholds": {
            "steps": [
              { "color": "red", "value": null },
              { "color": "orange", "value": 14 },
              { "color": "green", "value": 30 }
            ]
          }
        }
      },
      "gridPos": { "x": 0, "y": 8, "w": 24, "h": 8 }
    }
  ],
  "time": { "from": "now-24h", "to": "now" },
  "refresh": "5m"
}
```

- [ ] **Step 5: Create resource comparison dashboard JSON**

Save to `modules/prometheus-stack/dashboards/resource-comparison.json`:

```json
{
  "id": null,
  "title": "Mac Mini vs RPi Resource Comparison",
  "tags": ["homelab", "resources"],
  "timezone": "browser",
  "schemaVersion": 39,
  "panels": [
    {
      "id": 1,
      "title": "CPU Usage %",
      "type": "timeseries",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        {
          "expr": "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode='idle',job='mac-mini-node'}[5m])) * 100)",
          "legendFormat": "Mac Mini"
        },
        {
          "expr": "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode='idle',job='rpi-node'}[5m])) * 100)",
          "legendFormat": "RPi 5"
        }
      ],
      "fieldConfig": { "defaults": { "unit": "percent", "max": 100 } },
      "gridPos": { "x": 0, "y": 0, "w": 12, "h": 8 }
    },
    {
      "id": 2,
      "title": "Memory Usage %",
      "type": "timeseries",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        {
          "expr": "100 * (1 - (node_memory_MemAvailable_bytes{job='mac-mini-node'} / node_memory_MemTotal_bytes{job='mac-mini-node'}))",
          "legendFormat": "Mac Mini"
        },
        {
          "expr": "100 * (1 - (node_memory_MemAvailable_bytes{job='rpi-node'} / node_memory_MemTotal_bytes{job='rpi-node'}))",
          "legendFormat": "RPi 5"
        }
      ],
      "fieldConfig": { "defaults": { "unit": "percent", "max": 100 } },
      "gridPos": { "x": 12, "y": 0, "w": 12, "h": 8 }
    }
  ],
  "time": { "from": "now-6h", "to": "now" },
  "refresh": "30s"
}
```

- [ ] **Step 6: Add ConfigMap resources to `modules/prometheus-stack/main.tf`**

Following the existing pattern (see `kubernetes_config_map.grafana_dashboard_homelab_overview`), add one resource per new dashboard:

```hcl
resource "kubernetes_config_map" "grafana_dashboard_pihole" {
  metadata {
    name      = "grafana-pihole-stats"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "pihole-stats.json" = file("${path.module}/dashboards/pihole-stats.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_crowdsec" {
  metadata {
    name      = "grafana-crowdsec-events"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "crowdsec-events.json" = file("${path.module}/dashboards/crowdsec-events.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_blackbox" {
  metadata {
    name      = "grafana-blackbox-uptime"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "blackbox-uptime.json" = file("${path.module}/dashboards/blackbox-uptime.json")
  }
}

resource "kubernetes_config_map" "grafana_dashboard_resource_comparison" {
  metadata {
    name      = "grafana-resource-comparison"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "resource-comparison.json" = file("${path.module}/dashboards/resource-comparison.json")
  }
}
```

- [ ] **Step 7: Validate and apply**

```bash
cd /Users/rainforest/Repositories/rainforest-iot
terraform validate
terraform plan -target=module.prometheus_stack
terraform apply -target=module.prometheus_stack
```

- [ ] **Step 8: Verify dashboards appear in Grafana**

Open Grafana at `http://raspberrypi-5.local:30080`. Navigate to Dashboards. Expected: 4 new dashboards appear (Pi-hole Statistics, CrowdSec Security Events, Service Uptime, Mac Mini vs RPi).

- [ ] **Step 9: Commit**

```bash
git add modules/prometheus-stack/
git commit -m "feat: add monitoring dashboards as code (pihole, crowdsec, uptime, resources)"
```

---

## Task 2: Create Velero K3s backup module

**Goal:** K3s PVCs automatically backed up daily to Mac Mini MinIO, retained for 7 days, restorable after SD card failure.

- [ ] **Step 1: Look up the latest Velero Helm chart version**

```bash
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update
helm search repo velero --versions | head -5
```

Note the latest chart version (e.g. `7.3.0`) and app version (e.g. `v1.15.0`).

- [ ] **Step 2: Create `modules/velero/versions.tf`**

```hcl
terraform {
  required_providers {
    kubernetes = {
      source                = "hashicorp/kubernetes"
      version               = "~> 2.24"
      configuration_aliases = [kubernetes]
    }
    helm = {
      source                = "hashicorp/helm"
      version               = "~> 2.12"
      configuration_aliases = [helm]
    }
  }
}
```

- [ ] **Step 3: Create `modules/velero/variables.tf`**

```hcl
variable "namespace" {
  type    = string
  default = "velero"
}

variable "chart_version" {
  description = "Velero Helm chart version"
  type        = string
  default     = "7.3.0"   # Update to latest from Step 1
}

variable "minio_endpoint" {
  description = "Mac Mini MinIO S3 endpoint (LAN direct, not Tailscale)"
  type        = string
  default     = "http://192.168.0.126:9000"
}

variable "minio_bucket" {
  description = "MinIO bucket name for Velero backups"
  type        = string
  default     = "velero"
}

variable "minio_access_key" {
  description = "MinIO root user"
  type        = string
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO root password"
  type        = string
  sensitive   = true
}

variable "backup_schedule" {
  description = "Cron schedule for daily backup"
  type        = string
  default     = "0 2 * * *"   # 02:00 daily
}

variable "backup_ttl" {
  description = "How long to retain backups"
  type        = string
  default     = "168h0m0s"    # 7 days
}
```

- [ ] **Step 4: Create `modules/velero/main.tf`**

```hcl
resource "kubernetes_namespace" "velero" {
  metadata {
    name = var.namespace
  }
}

# Velero needs MinIO credentials stored as a Kubernetes Secret
resource "kubernetes_secret" "velero_credentials" {
  metadata {
    name      = "velero-s3-credentials"
    namespace = kubernetes_namespace.velero.metadata[0].name
  }

  data = {
    "cloud" = <<-EOT
      [default]
      aws_access_key_id = ${var.minio_access_key}
      aws_secret_access_key = ${var.minio_secret_key}
    EOT
  }

  type = "Opaque"
}

resource "helm_release" "velero" {
  name       = "velero"
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  version    = var.chart_version
  namespace  = kubernetes_namespace.velero.metadata[0].name

  values = [
    yamlencode({
      # Use AWS S3-compatible provider (works with MinIO)
      initContainers = [
        {
          name  = "velero-plugin-for-aws"
          image = "velero/velero-plugin-for-aws:v1.10.0"
          volumeMounts = [
            { mountPath = "/target", name = "plugins" }
          ]
        }
      ]

      configuration = {
        backupStorageLocation = [
          {
            name     = "default"
            provider = "aws"
            bucket   = var.minio_bucket
            config = {
              region                = "minio"
              s3ForcePathStyle      = "true"
              s3Url                 = var.minio_endpoint
              publicUrl             = var.minio_endpoint
            }
            credential = {
              name = kubernetes_secret.velero_credentials.metadata[0].name
              key  = "cloud"
            }
          }
        ]

        volumeSnapshotLocation = [
          {
            name     = "default"
            provider = "aws"
            config = {
              region = "minio"
            }
          }
        ]
      }

      # Resource limits — Velero runs infrequently, keep footprint small
      resources = {
        requests = { cpu = "50m",  memory = "64Mi"  }
        limits   = { cpu = "500m", memory = "256Mi" }
      }

      # Node agent (for file-level PVC backup without CSI snapshots)
      nodeAgent = {
        enabled = true
        podVolumePath = "/var/lib/kubelet/pods"
        resources = {
          requests = { cpu = "25m",  memory = "32Mi"  }
          limits   = { cpu = "250m", memory = "128Mi" }
        }
      }
    })
  ]

  depends_on = [kubernetes_secret.velero_credentials]
}

# Daily backup schedule — all namespaces, 7-day retention
resource "kubernetes_manifest" "velero_schedule" {
  depends_on = [helm_release.velero]

  manifest = {
    apiVersion = "velero.io/v1"
    kind       = "Schedule"
    metadata = {
      name      = "daily-full-backup"
      namespace = kubernetes_namespace.velero.metadata[0].name
    }
    spec = {
      schedule          = var.backup_schedule
      useOwnerReferencesInBackup = false
      template = {
        ttl                   = var.backup_ttl
        includedNamespaces    = ["*"]
        storageLocation       = "default"
        volumeSnapshotLocations = ["default"]
      }
    }
  }
}
```

- [ ] **Step 5: Create `modules/velero/outputs.tf`**

```hcl
output "schedule_name" {
  value = "daily-full-backup"
}
```

- [ ] **Step 6: Create MinIO `velero` bucket before applying**

The bucket must exist in MinIO before Velero first runs. Use the MinIO web console at `http://localhost:9001` (or `https://minio.rainforest.tools`):

1. Log in with MinIO root credentials
2. Create bucket named `velero`
3. Disable versioning (not needed for Velero)

Or via CLI:
```bash
# If mc (MinIO client) is installed:
mc alias set homelab http://192.168.0.126:9000 <access_key> <secret_key>
mc mb homelab/velero
```

- [ ] **Step 7: Add variables to root `variables.tf`**

```hcl
variable "velero_chart_version" {
  type    = string
  default = "7.3.0"
}

variable "minio_access_key" {
  description = "MinIO root user for Velero S3 access"
  type        = string
  sensitive   = true
  default     = "minioadmin"
}

variable "minio_secret_key" {
  description = "MinIO root password for Velero S3 access"
  type        = string
  sensitive   = true
}
```

Add to `terraform.tfvars`:
```hcl
minio_access_key = "<minio root user>"
minio_secret_key = "<minio root password>"
```

> Get MinIO credentials from the rainforest-homelab Terraform state:
> ```bash
> cd /Users/rainforest/Repositories/rainforest-homelab
> terraform output minio_root_password
> ```

- [ ] **Step 8: Wire module in root `main.tf`**

```hcl
module "velero" {
  count  = var.enable_k8s_cluster ? 1 : 0
  source = "./modules/velero"
  depends_on = [module.k3s_cluster]

  providers = {
    kubernetes = kubernetes.k3s
    helm       = helm.k3s
  }

  chart_version    = var.velero_chart_version
  minio_endpoint   = "http://${var.mac_mini_ip}:9000"
  minio_access_key = var.minio_access_key
  minio_secret_key = var.minio_secret_key
}
```

- [ ] **Step 9: Validate and apply**

```bash
terraform validate
terraform plan -target=module.velero
terraform apply -target=module.velero
```

- [ ] **Step 10: Verify Velero is running**

```bash
kubectl get pods -n velero
kubectl get backupstoragelocation -n velero
```

Expected: Velero pod `Running`, storage location `Available`.

- [ ] **Step 11: Trigger a manual test backup**

```bash
# Install velero CLI first if needed:
brew install velero

velero backup create test-backup --include-namespaces monitoring --wait \
  --kubeconfig <path-to-rpi-kubeconfig>
```

Expected: backup status `Completed`.

```bash
velero backup describe test-backup
velero backup logs test-backup
```

Also verify the backup appears in MinIO at `http://localhost:9001/buckets/velero/`.

- [ ] **Step 12: Clean up test backup**

```bash
velero backup delete test-backup --confirm
```

- [ ] **Step 13: Commit**

```bash
git add modules/velero/ main.tf variables.tf
git commit -m "feat: add Velero K3s PVC backup to Mac Mini MinIO (daily, 7-day retention)"
```

---

## Task 3: RPi → Mac Mini rsync + CrowdSec hub update via Ansible

**Goal:** Raw K3s storage backed up to Mac Mini every 6 hours; CrowdSec signatures updated daily.

- [ ] **Step 1: Verify SSH key-based auth from Mac Mini to RPi**

```bash
ssh -o PasswordAuthentication=no rainforest@raspberrypi-5.local echo "ok"
```

If this asks for a password, set up key auth:
```bash
ssh-copy-id rainforest@raspberrypi-5.local
```

- [ ] **Step 2: Verify SSH key-based auth from RPi to Mac Mini**

```bash
ssh rainforest@raspberrypi-5.local \
  "ssh -o PasswordAuthentication=no rainforest@192.168.0.126 echo ok"
```

If this fails, copy the RPi's public key to the Mac Mini:
```bash
ssh rainforest@raspberrypi-5.local "cat ~/.ssh/id_rsa.pub"
# Paste the output into ~/.ssh/authorized_keys on Mac Mini
```

- [ ] **Step 3: Create Ansible playbook `ansible/playbooks/setup-backup.yml`**

```yaml
---
- name: Configure backup timers on Raspberry Pi
  hosts: raspberry_pi
  become: yes

  vars:
    mac_mini_ip: "192.168.0.126"
    mac_mini_user: "rainforest"
    backup_dest: "~/homelab-backups/rpi-k3s"
    rsync_source: "/var/lib/rancher/k3s/storage/"

  tasks:
    # ── rsync timer ────────────────────────────────────────────────────────────

    - name: Create backup destination directory on Mac Mini
      become: no
      shell: |
        ssh -o StrictHostKeyChecking=no \
          {{ mac_mini_user }}@{{ mac_mini_ip }} \
          "mkdir -p {{ backup_dest }}"

    - name: Write rsync backup script
      copy:
        dest: /usr/local/bin/rpi-backup-rsync.sh
        mode: "0755"
        content: |
          #!/bin/bash
          set -euo pipefail
          rsync -az --delete \
            {{ rsync_source }} \
            {{ mac_mini_user }}@{{ mac_mini_ip }}:{{ backup_dest }}/
          echo "$(date): rsync backup completed" >> /var/log/homelab-backup.log

    - name: Create rsync systemd service unit
      copy:
        dest: /etc/systemd/system/homelab-rsync-backup.service
        content: |
          [Unit]
          Description=RPi K3s storage rsync backup to Mac Mini
          After=network-online.target
          Wants=network-online.target

          [Service]
          Type=oneshot
          User=root
          ExecStart=/usr/local/bin/rpi-backup-rsync.sh
          StandardOutput=journal
          StandardError=journal

    - name: Create rsync systemd timer unit
      copy:
        dest: /etc/systemd/system/homelab-rsync-backup.timer
        content: |
          [Unit]
          Description=RPi K3s rsync backup — every 6 hours
          Requires=homelab-rsync-backup.service

          [Timer]
          OnBootSec=10min
          OnUnitActiveSec=6h
          Persistent=true

          [Install]
          WantedBy=timers.target

    - name: Enable and start rsync timer
      systemd:
        name: homelab-rsync-backup.timer
        state: started
        enabled: yes
        daemon_reload: yes

    # ── CrowdSec hub update timer ──────────────────────────────────────────────

    - name: Write CrowdSec hub update script
      copy:
        dest: /usr/local/bin/crowdsec-hub-update.sh
        mode: "0755"
        content: |
          #!/bin/bash
          set -euo pipefail
          docker exec homelab-crowdsec cscli hub update
          docker exec homelab-crowdsec cscli hub upgrade
          echo "$(date): CrowdSec hub updated" >> /var/log/homelab-backup.log

    - name: Create CrowdSec update systemd service unit
      copy:
        dest: /etc/systemd/system/crowdsec-hub-update.service
        content: |
          [Unit]
          Description=Update CrowdSec hub parsers and scenarios
          After=docker.service
          Requires=docker.service

          [Service]
          Type=oneshot
          User=root
          ExecStart=/usr/local/bin/crowdsec-hub-update.sh
          StandardOutput=journal
          StandardError=journal

    - name: Create CrowdSec update systemd timer
      copy:
        dest: /etc/systemd/system/crowdsec-hub-update.timer
        content: |
          [Unit]
          Description=Daily CrowdSec hub update at 04:00
          Requires=crowdsec-hub-update.service

          [Timer]
          OnCalendar=*-*-* 04:00:00
          Persistent=true

          [Install]
          WantedBy=timers.target

    - name: Enable and start CrowdSec update timer
      systemd:
        name: crowdsec-hub-update.timer
        state: started
        enabled: yes
        daemon_reload: yes

    # ── Verification ──────────────────────────────────────────────────────────

    - name: List active timers
      command: systemctl list-timers --all
      register: timers_output
      changed_when: false

    - name: Show timer status
      debug:
        msg: "{{ timers_output.stdout_lines | select('search', 'homelab|crowdsec') | list }}"
```

- [ ] **Step 4: Run the playbook**

```bash
cd /Users/rainforest/Repositories/rainforest-iot
ansible-playbook -i ansible/inventory.yml ansible/playbooks/setup-backup.yml
```

Expected: all tasks `ok` or `changed`, no failures.

- [ ] **Step 5: Verify timers are active**

```bash
ssh rainforest@raspberrypi-5.local \
  "systemctl list-timers | grep -E 'homelab|crowdsec'"
```

Expected: two timer entries showing `Next` trigger times.

- [ ] **Step 6: Trigger rsync manually to test**

```bash
ssh rainforest@raspberrypi-5.local "sudo /usr/local/bin/rpi-backup-rsync.sh"
```

Then verify on Mac Mini:
```bash
ls ~/homelab-backups/rpi-k3s/
```

Expected: K3s storage files present.

- [ ] **Step 7: Trigger CrowdSec update manually to test**

```bash
ssh rainforest@raspberrypi-5.local "sudo /usr/local/bin/crowdsec-hub-update.sh"
```

Expected: output showing CrowdSec updating parsers and scenarios, no errors.

- [ ] **Step 8: Commit**

```bash
git add ansible/playbooks/setup-backup.yml
git commit -m "feat: add RPi rsync + CrowdSec hub update systemd timers via Ansible"
```

---

## Task 4: Enable K3s network policies and resource quotas

**Goal:** Pods can't communicate across namespaces unexpectedly; each namespace has resource guardrails.

- [ ] **Step 1: Update `terraform.tfvars`**

```hcl
# Change these two lines from false to true:
k8s_enable_network_policies = true
k8s_enable_resource_quotas  = true
```

- [ ] **Step 2: Plan and review the diff**

```bash
cd /Users/rainforest/Repositories/rainforest-iot
terraform plan -target=module.k3s_cluster
```

Review the plan carefully. Expected: new `kubernetes_network_policy` and `kubernetes_resource_quota` resources for each namespace.

- [ ] **Step 3: Check that existing workloads still allow necessary cross-namespace traffic**

The `monitoring` namespace (Prometheus) needs to scrape pods in other namespaces. Confirm the `k3s-cluster` module's network policy allows egress from `monitoring` to all namespaces, or that pod-scraping uses `PodMonitor` resources with appropriate `namespaceSelector`.

```bash
grep -rn "NetworkPolicy\|networkPolicy" modules/k3s-cluster/
```

If no cross-namespace egress rule exists for Prometheus, add one before enabling:

```hcl
# In modules/k3s-cluster/ network policy for monitoring namespace:
# Allow Prometheus to scrape pods in any namespace
egress {
  to {
    namespace_selector {}  # empty = all namespaces
  }
  ports {
    port     = "metrics"
    protocol = "TCP"
  }
}
```

- [ ] **Step 4: Apply**

```bash
terraform apply -target=module.k3s_cluster
```

- [ ] **Step 5: Verify Prometheus is still scraping after network policy is applied**

```bash
kubectl get networkpolicies -A
kubectl get resourcequotas -A

# Port-forward Prometheus and check targets:
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &
curl -s "http://localhost:9090/api/v1/targets" | \
  python3 -m json.tool | grep '"health"' | sort | uniq -c
```

Expected: all targets showing `"health": "up"`. If any targets drop to `down`, add network policy exceptions for those namespaces.

- [ ] **Step 6: Commit**

```bash
git add terraform.tfvars
git commit -m "feat: enable K3s network policies and resource quotas"
```

---

## Phase 4 Complete — Verification Checklist

```bash
# Dashboards visible in Grafana (open browser at http://raspberrypi-5.local:30080)
kubectl get configmap -n monitoring | grep grafana
# Expected: grafana-pihole-stats, grafana-crowdsec-events, grafana-blackbox-uptime, grafana-resource-comparison

# Velero backup schedule active
kubectl get schedule -n velero
# Expected: daily-full-backup with schedule "0 2 * * *"

# Velero storage location available
kubectl get backupstoragelocation -n velero
# Expected: default with PHASE=Available

# rsync timer active on RPi
ssh rainforest@raspberrypi-5.local "systemctl is-active homelab-rsync-backup.timer"
# Expected: active

# CrowdSec update timer active
ssh rainforest@raspberrypi-5.local "systemctl is-active crowdsec-hub-update.timer"
# Expected: active

# Network policies applied
kubectl get networkpolicies -A | wc -l
# Expected: > 0

# Resource quotas applied
kubectl get resourcequotas -A | wc -l
# Expected: > 0
```

---

## Full Project Complete — Summary

All four phases delivered:

| Phase | What was built |
|---|---|
| Phase 1 | Version pinning, secrets, Pi-hole threat blocklists + exporter |
| Phase 2 | CrowdSec IDS, Ntopng traffic analysis, Blackbox Exporter uptime |
| Phase 3 | Grafana Alloy (Mac Mini), Grafana MCP, Flowise removal, Synology backup bridge |
| Phase 4 | Velero K3s backups, rsync timers, dashboards as code, K3s hardening |
