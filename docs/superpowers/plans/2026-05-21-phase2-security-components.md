# Phase 2: New Security Components — CrowdSec, Ntopng, Blackbox Exporter

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add CrowdSec intrusion detection, Ntopng traffic analysis, and Blackbox Exporter endpoint monitoring to the RPi — all feeding metrics into Prometheus.

**Architecture:** CrowdSec runs as two Docker containers (Agent+LAPI and Firewall Bouncer) on the RPi, sharing a Docker network with Pi-hole. Ntopng runs in host-network mode so it can see all LAN traffic on eth0. Blackbox Exporter is added to the existing `kube-prometheus-stack` Helm chart via `values` in `modules/prometheus-stack/main.tf`; its probe targets are defined in `modules/monitoring-integrations/main.tf`.

**Tech Stack:** Terraform Docker provider, crowdsecurity/crowdsec, crowdsecurity/firewall-bouncer-iptables, ntop/ntopng, Prometheus Blackbox Exporter (bundled in kube-prometheus-stack)

**Spec:** `docs/superpowers/specs/2026-05-21-homelab-security-monitoring-design.md` — Phase 2

---

## File Map

| Action | File |
|---|---|
| Create | `modules/crowdsec/main.tf` |
| Create | `modules/crowdsec/variables.tf` |
| Create | `modules/crowdsec/outputs.tf` |
| Create | `modules/crowdsec/versions.tf` |
| Create | `modules/ntopng/main.tf` |
| Create | `modules/ntopng/variables.tf` |
| Create | `modules/ntopng/outputs.tf` |
| Create | `modules/ntopng/versions.tf` |
| Modify | `modules/prometheus-stack/main.tf` — enable blackbox exporter in Helm values |
| Modify | `modules/prometheus-stack/variables.tf` — add blackbox probe target variables |
| Modify | `modules/monitoring-integrations/main.tf` — add CrowdSec + Ntopng scrape targets + blackbox probe rules |
| Modify | `modules/monitoring-integrations/variables.tf` — add new target variables |
| Modify | `main.tf` — wire in crowdsec + ntopng modules |
| Modify | `variables.tf` — add crowdsec + ntopng version variables |
| Modify | `terraform.tfvars` — add version values |

---

## Task 1: Create CrowdSec module

**Goal:** CrowdSec detects brute-force, port-scans, and bad IPs from the community blocklist; the bouncer drops matching traffic via iptables.

- [ ] **Step 1: Create `modules/crowdsec/versions.tf`**

```hcl
terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}
```

- [ ] **Step 2: Create `modules/crowdsec/variables.tf`**

```hcl
variable "project_name" {
  type    = string
  default = "homelab"
}

variable "crowdsec_version" {
  description = "CrowdSec Agent image version"
  type        = string
  default     = "v1.6.3"
}

variable "bouncer_version" {
  description = "CrowdSec Firewall Bouncer image version"
  type        = string
  default     = "v0.0.29"
}

variable "timezone" {
  type    = string
  default = "Asia/Taipei"
}

variable "log_opts" {
  type = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}

variable "whitelist_cidrs" {
  description = "CIDRs to never block (LAN, loopback)"
  type        = list(string)
  default     = ["192.168.0.0/24", "127.0.0.1/32"]
}

variable "log_paths" {
  description = "Host log paths to monitor for intrusion signals"
  type        = list(string)
  default = [
    "/var/log/auth.log",
    "/var/log/syslog",
  ]
}
```

- [ ] **Step 3: Create `modules/crowdsec/main.tf`**

```hcl
resource "docker_image" "crowdsec" {
  name         = "crowdsecurity/crowdsec:${var.crowdsec_version}"
  keep_locally = true
}

resource "docker_image" "bouncer" {
  name         = "crowdsecurity/firewall-bouncer-iptables:${var.bouncer_version}"
  keep_locally = true
}

resource "docker_network" "crowdsec" {
  name = "${var.project_name}-crowdsec"
}

# CrowdSec Agent + LAPI
resource "docker_container" "crowdsec" {
  name  = "${var.project_name}-crowdsec"
  image = docker_image.crowdsec.image_id

  restart = "unless-stopped"

  # CrowdSec exposes Prometheus metrics on 6060 and LAPI on 8080
  ports {
    internal = 6060
    external = 6060
    protocol = "tcp"
  }
  ports {
    internal = 8080
    external = 6081   # LAPI — not exposed publicly, LAN-only
    protocol = "tcp"
  }

  env = [
    "TZ=${var.timezone}",
    "COLLECTIONS=crowdsecurity/linux crowdsecurity/sshd crowdsecurity/nginx",
    "CUSTOM_HOSTNAME=${var.project_name}-crowdsec",
  ]

  # Mount host log directories for parsing
  dynamic "volumes" {
    for_each = var.log_paths
    content {
      host_path      = volumes.value
      container_path = volumes.value
      read_only      = true
    }
  }

  # Persist CrowdSec database and config between restarts
  volumes {
    volume_name    = docker_volume.crowdsec_data.name
    container_path = "/var/lib/crowdsec/data"
  }

  networks_advanced {
    name = docker_network.crowdsec.name
  }

  memory = 256

  log_driver = "json-file"
  log_opts   = var.log_opts

  healthcheck {
    test         = ["CMD", "cscli", "version"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "60s"
  }
}

# Firewall Bouncer — executes iptables DROP rules for banned IPs
resource "docker_container" "crowdsec_bouncer" {
  name  = "${var.project_name}-crowdsec-bouncer"
  image = docker_image.bouncer.image_id

  restart = "unless-stopped"

  # Bouncer needs to add iptables rules on the host
  capabilities {
    add = ["NET_ADMIN", "NET_RAW"]
  }

  network_mode = "host"

  env = [
    "TZ=${var.timezone}",
    "CROWDSEC_LAPI_URL=http://127.0.0.1:6081",
    "CROWDSEC_LAPI_KEY=",   # Set after first run via: docker exec homelab-crowdsec cscli bouncers add firewall-bouncer
    "GID=1000",
  ]

  memory = 64

  log_driver = "json-file"
  log_opts   = var.log_opts
}

resource "docker_volume" "crowdsec_data" {
  name = "${var.project_name}-crowdsec-data"
  labels {
    label = "project"
    value = var.project_name
  }
}
```

> **Note on bouncer API key:** The bouncer needs a key generated by the CrowdSec LAPI. After first `terraform apply`, generate and set it:
> ```bash
> # SSH to RPi:
> docker exec homelab-crowdsec cscli bouncers add firewall-bouncer
> # Copy the printed key, then set CROWDSEC_LAPI_KEY in the bouncer container env and re-apply.
> ```

- [ ] **Step 4: Create `modules/crowdsec/outputs.tf`**

```hcl
output "metrics_endpoint" {
  description = "CrowdSec Prometheus metrics endpoint"
  value       = "http://localhost:6060/metrics"
}

output "lapi_endpoint" {
  description = "CrowdSec LAPI endpoint"
  value       = "http://localhost:6081"
}
```

- [ ] **Step 5: Add version variables to root `variables.tf`**

```hcl
variable "crowdsec_version" {
  description = "CrowdSec Agent Docker image version"
  type        = string
  default     = "v1.6.3"   # Check https://github.com/crowdsecurity/crowdsec/releases
}

variable "crowdsec_bouncer_version" {
  description = "CrowdSec Firewall Bouncer image version"
  type        = string
  default     = "v0.0.29"  # Check https://github.com/crowdsecurity/cs-firewall-bouncer/releases
}
```

- [ ] **Step 6: Wire module in root `main.tf`**

```hcl
module "crowdsec" {
  source = "./modules/crowdsec"

  providers = {
    docker = docker.raspberry-pi
  }

  project_name     = "homelab"
  crowdsec_version = var.crowdsec_version
  bouncer_version  = var.crowdsec_bouncer_version
  timezone         = var.timezone
  log_opts         = local.common_log_opts
}
```

- [ ] **Step 7: Set versions in `terraform.tfvars`**

```hcl
crowdsec_version         = "v1.6.3"   # Replace with latest from Step 5
crowdsec_bouncer_version = "v0.0.29"  # Replace with latest from Step 5
```

- [ ] **Step 8: Validate and plan**

```bash
cd /Users/rainforest/Repositories/rainforest-iot
terraform validate
terraform plan -target=module.crowdsec
```

Expected: plan shows 4 new resources (2 images, 2 containers, 1 network, 1 volume).

- [ ] **Step 9: Apply and verify**

```bash
terraform apply -target=module.crowdsec

ssh rainforest@raspberrypi-5.local "docker ps | grep crowdsec"
```

Expected: `homelab-crowdsec` and `homelab-crowdsec-bouncer` both `Up`.

- [ ] **Step 10: Register bouncer API key**

```bash
# Generate the key
ssh rainforest@raspberrypi-5.local \
  "docker exec homelab-crowdsec cscli bouncers add firewall-bouncer"
```

Copy the printed key, then update the bouncer `CROWDSEC_LAPI_KEY` env in `modules/crowdsec/main.tf` — add a variable for it:

In `modules/crowdsec/variables.tf`:
```hcl
variable "bouncer_api_key" {
  description = "CrowdSec LAPI key for the firewall bouncer"
  type        = string
  sensitive   = true
  default     = ""
}
```

In `modules/crowdsec/main.tf`, change the bouncer env line:
```hcl
"CROWDSEC_LAPI_KEY=${var.bouncer_api_key}",
```

In root `variables.tf`:
```hcl
variable "crowdsec_bouncer_api_key" {
  type      = string
  sensitive = true
  default   = ""
}
```

In root `main.tf`, add to module block:
```hcl
bouncer_api_key = var.crowdsec_bouncer_api_key
```

In `terraform.tfvars`:
```hcl
crowdsec_bouncer_api_key = "<key from cscli bouncers add>"
```

Re-apply:
```bash
terraform apply -target=module.crowdsec
```

- [ ] **Step 11: Verify metrics endpoint is reachable**

```bash
curl http://raspberrypi-5.local:6060/metrics | grep cs_
```

Expected: metrics including `cs_active_decisions`, `cs_alerts`, `cs_parsers`.

- [ ] **Step 12: Commit**

```bash
git add modules/crowdsec/ main.tf variables.tf terraform.tfvars
git commit -m "feat: add CrowdSec IDS module (agent + firewall bouncer)"
```

---

## Task 2: Create Ntopng module

**Goal:** Deep-packet inspection of all LAN traffic for bandwidth analysis, top talkers, and anomaly detection — visible in Grafana.

- [ ] **Step 1: Create `modules/ntopng/versions.tf`**

```hcl
terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}
```

- [ ] **Step 2: Create `modules/ntopng/variables.tf`**

```hcl
variable "project_name" {
  type    = string
  default = "homelab"
}

variable "image_version" {
  description = "Ntopng Docker image version tag"
  type        = string
  default     = "stable"   # ntop/ntopng:stable is their rolling stable release
}

variable "timezone" {
  type    = string
  default = "Asia/Taipei"
}

variable "log_opts" {
  type = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}

variable "web_port" {
  description = "Ntopng web UI port"
  type        = number
  default     = 3001   # 3000 conflicts with Grafana if forwarded; using 3001
}

variable "interface" {
  description = "Network interface to monitor (must match RPi eth0 name)"
  type        = string
  default     = "eth0"
}
```

- [ ] **Step 3: Create `modules/ntopng/main.tf`**

```hcl
resource "docker_image" "ntopng" {
  name         = "ntop/ntopng:${var.image_version}"
  keep_locally = true
}

resource "docker_volume" "ntopng_data" {
  name = "${var.project_name}-ntopng-data"
  labels {
    label = "project"
    value = var.project_name
  }
}

resource "docker_container" "ntopng" {
  name  = "${var.project_name}-ntopng"
  image = docker_image.ntopng.image_id

  restart = "unless-stopped"

  # REQUIRED: host network mode to see all LAN traffic on eth0.
  # Without this, ntopng only sees its own container bridge traffic.
  network_mode = "host"

  command = [
    "--interface=${var.interface}",
    "--http-port=${var.web_port}",
    "--community",     # Community (free) mode
    "--disable-login=0",
    "--data-dir=/var/lib/ntopng",
  ]

  env = [
    "TZ=${var.timezone}",
  ]

  volumes {
    volume_name    = docker_volume.ntopng_data.name
    container_path = "/var/lib/ntopng"
  }

  memory = 512

  log_driver = "json-file"
  log_opts   = var.log_opts

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://localhost:${var.web_port}/"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }
}
```

- [ ] **Step 4: Create `modules/ntopng/outputs.tf`**

```hcl
output "web_url" {
  description = "Ntopng web UI URL"
  value       = "http://localhost:${var.web_port}"
}
```

- [ ] **Step 5: Add version variable to root `variables.tf`**

```hcl
variable "ntopng_image_version" {
  description = "Ntopng Docker image version"
  type        = string
  default     = "stable"
}

variable "ntopng_web_port" {
  description = "Ntopng web UI port"
  type        = number
  default     = 3001
}
```

- [ ] **Step 6: Wire module in root `main.tf`**

```hcl
module "ntopng" {
  source = "./modules/ntopng"

  providers = {
    docker = docker.raspberry-pi
  }

  project_name  = "homelab"
  image_version = var.ntopng_image_version
  web_port      = var.ntopng_web_port
  timezone      = var.timezone
  log_opts      = local.common_log_opts
}
```

- [ ] **Step 7: Set values in `terraform.tfvars`**

```hcl
ntopng_image_version = "stable"
ntopng_web_port      = 3001
```

- [ ] **Step 8: Validate and plan**

```bash
terraform validate
terraform plan -target=module.ntopng
```

Expected: plan shows 1 new image, 1 container, 1 volume.

- [ ] **Step 9: Apply and verify**

```bash
terraform apply -target=module.ntopng

ssh rainforest@raspberrypi-5.local "docker ps | grep ntopng"
```

Expected: `homelab-ntopng` running. Give it 30s to start, then:

```bash
# Test web UI is responsive
curl -s -o /dev/null -w "%{http_code}" http://raspberrypi-5.local:3001/
```

Expected: `200` or `302` (redirect to login).

- [ ] **Step 10: Add Ntopng to Teleport app access**

In root `main.tf`, add to `teleport_node.apps`:

```hcl
apps = {
  "pihole"    = { ... }  # existing
  "homebridge" = { ... } # existing
  "ntopng"    = {
    uri         = "http://localhost:${var.ntopng_web_port}"
    description = "Ntopng LAN traffic analysis (admin)"
  }
}
```

```bash
terraform apply -target=module.teleport_node
```

- [ ] **Step 11: Commit**

```bash
git add modules/ntopng/ main.tf variables.tf terraform.tfvars
git commit -m "feat: add Ntopng LAN traffic analysis module"
```

---

## Task 3: Add Blackbox Exporter to prometheus-stack

**Goal:** Prometheus actively probes each service endpoint every 30s — uptime and latency visible in Grafana without deploying a separate Uptime Kuma instance.

- [ ] **Step 1: Understand how Blackbox Exporter is exposed in kube-prometheus-stack**

The chart bundles `prometheus-blackbox-exporter` as a subchart. It is enabled via Helm values.

Check the existing Helm values in `modules/prometheus-stack/main.tf`:
```bash
grep -n "blackbox\|prometheus-blackbox" \
  modules/prometheus-stack/main.tf | head -20
```

If no mention exists, the exporter is not yet enabled.

- [ ] **Step 2: Add blackbox exporter Helm values to `modules/prometheus-stack/main.tf`**

Find the `helm_release.prometheus_stack` resource and add to the `values` block. Locate the closing `})` of the outer `yamlencode({...})` call and add before it:

```hcl
# Blackbox Exporter - HTTP/ICMP synthetic monitoring
prometheusBlackboxExporter = {
  enabled = true
}

# Prometheus scrape configs for blackbox probes
prometheus = {
  prometheusSpec = {
    additionalScrapeConfigs = [
      {
        job_name       = "blackbox-http"
        metrics_path   = "/probe"
        params         = { module = ["http_2xx"] }
        static_configs = [{ targets = var.blackbox_http_targets }]
        relabel_configs = [
          {
            source_labels = ["__address__"]
            target_label  = "__param_target"
          },
          {
            source_labels = ["__param_target"]
            target_label  = "instance"
          },
          {
            target_label = "__address__"
            replacement  = "prometheus-prometheus-blackbox-exporter.${var.namespace}.svc.cluster.local:9115"
          },
        ]
      },
      {
        job_name       = "blackbox-icmp"
        metrics_path   = "/probe"
        params         = { module = ["icmp"] }
        static_configs = [{ targets = var.blackbox_icmp_targets }]
        relabel_configs = [
          {
            source_labels = ["__address__"]
            target_label  = "__param_target"
          },
          {
            source_labels = ["__param_target"]
            target_label  = "instance"
          },
          {
            target_label = "__address__"
            replacement  = "prometheus-prometheus-blackbox-exporter.${var.namespace}.svc.cluster.local:9115"
          },
        ]
      },
    ]
  }
}
```

> **Important:** `additionalScrapeConfigs` in Helm values is separate from the `additionalScrapeConfigs` Secret defined in `main.tf`. You may already have a Secret-based approach; check whether the chart's `prometheus.prometheusSpec.additionalScrapeConfigs` field or `additionalScrapeConfigsSecret` is used. If a Secret is already in use, append blackbox job entries to the existing Secret template `templates/additional-scrape-configs.yaml.tpl` instead.

Check existing approach:
```bash
grep -n "additionalScrapeConfig" modules/prometheus-stack/main.tf
```

If using the Secret template approach, add to `templates/additional-scrape-configs.yaml.tpl`:

```yaml
- job_name: "blackbox-http"
  metrics_path: /probe
  params:
    module: [http_2xx]
  static_configs:
    - targets:
      %{~ for t in blackbox_http_targets ~}
      - "${t}"
      %{~ endfor ~}
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: "prometheus-prometheus-blackbox-exporter.${namespace}.svc.cluster.local:9115"

- job_name: "blackbox-icmp"
  metrics_path: /probe
  params:
    module: [icmp]
  static_configs:
    - targets:
      %{~ for t in blackbox_icmp_targets ~}
      - "${t}"
      %{~ endfor ~}
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: "prometheus-prometheus-blackbox-exporter.${namespace}.svc.cluster.local:9115"
```

- [ ] **Step 3: Add target variables to `modules/prometheus-stack/variables.tf`**

```hcl
variable "blackbox_http_targets" {
  description = "HTTP/HTTPS endpoints for Blackbox Exporter to probe"
  type        = list(string)
  default     = []
}

variable "blackbox_icmp_targets" {
  description = "IP addresses for ICMP ping probes"
  type        = list(string)
  default     = []
}
```

- [ ] **Step 4: Add target variables to root `variables.tf`**

```hcl
variable "blackbox_http_targets" {
  description = "HTTP/HTTPS endpoints for Blackbox Exporter synthetic monitoring"
  type        = list(string)
  default = [
    "https://homeassistant.rainforest.tools",
    "https://n8n.rainforest.tools",
    "https://open-webui.rainforest.tools",
    "http://raspberrypi-5.local:30080",
    "http://raspberrypi-5.local:8080",
  ]
}

variable "blackbox_icmp_targets" {
  description = "IP addresses for ICMP ping probes"
  type        = list(string)
  default     = ["192.168.0.1", "1.1.1.1"]
}
```

- [ ] **Step 5: Pass target variables in root `main.tf`**

Find the `module "prometheus_stack"` block and add:

```hcl
module "prometheus_stack" {
  # ... existing vars ...
  blackbox_http_targets = var.blackbox_http_targets
  blackbox_icmp_targets = var.blackbox_icmp_targets
}
```

- [ ] **Step 6: Validate and plan**

```bash
terraform validate
terraform plan -target=module.prometheus_stack
```

Expected: plan shows update to `helm_release.prometheus_stack` values (enabling `prometheusBlackboxExporter`).

- [ ] **Step 7: Apply and verify**

```bash
terraform apply -target=module.prometheus_stack

kubectl get pods -n monitoring | grep blackbox
```

Expected: `prometheus-prometheus-blackbox-exporter-...` pod in Running state.

```bash
# Test a probe manually
kubectl port-forward -n monitoring svc/prometheus-prometheus-blackbox-exporter 9115:9115 &
curl "http://localhost:9115/probe?target=https://homeassistant.rainforest.tools&module=http_2xx"
```

Expected: `probe_success 1` in the metrics output.

- [ ] **Step 8: Commit**

```bash
git add modules/prometheus-stack/ variables.tf main.tf
git commit -m "feat: enable Blackbox Exporter for synthetic endpoint monitoring"
```

---

## Task 4: Add CrowdSec and Ntopng scrape targets to monitoring-integrations

**Goal:** Prometheus scrapes CrowdSec metrics (port 6060) and Ntopng traffic stats.

- [ ] **Step 1: Add scrape jobs to `modules/monitoring-integrations/main.tf`**

Find the `kubernetes_config_map.additional_scrape_configs` resource and add two entries to the `yamlencode` list (after the existing pi-hole entry):

```hcl
# CrowdSec metrics
{
  job_name = "crowdsec"
  static_configs = [
    {
      targets = ["${var.raspberry_pi_hostname}:6060"]
      labels  = { instance = "raspberry-pi-5", service = "crowdsec" }
    }
  ]
  metrics_path    = "/metrics"
  scrape_interval = "30s"
},

# Ntopng — community edition doesn't expose Prometheus natively.
# Monitor via blackbox HTTP probe for now (uptime check).
# If ntopng-enterprise is used later, add InfluxDB bridge here.
{
  job_name = "ntopng-health"
  static_configs = [
    {
      targets = ["${var.raspberry_pi_hostname}:${var.ntopng_port}"]
      labels  = { instance = "raspberry-pi-5", service = "ntopng" }
    }
  ]
  metrics_path    = "/"
  scrape_interval = "60s"
},
```

- [ ] **Step 2: Add variable to `modules/monitoring-integrations/variables.tf`**

```hcl
variable "ntopng_port" {
  description = "Ntopng web UI port (for health check)"
  type        = number
  default     = 3001
}
```

- [ ] **Step 3: Pass variable from root `main.tf`**

```hcl
module "monitoring_integrations" {
  # ... existing ...
  ntopng_port = var.ntopng_web_port
}
```

- [ ] **Step 4: Validate and apply**

```bash
terraform validate
terraform plan -target=module.monitoring_integrations
terraform apply -target=module.monitoring_integrations
```

- [ ] **Step 5: Verify Prometheus is scraping CrowdSec**

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &

# Query for CrowdSec metrics
curl -s "http://localhost:9090/api/v1/query?query=cs_active_decisions" | \
  python3 -m json.tool | grep '"status"'
```

Expected: `"status": "success"` with data values.

- [ ] **Step 6: Commit**

```bash
git add modules/monitoring-integrations/
git commit -m "feat: add CrowdSec and Ntopng scrape targets to Prometheus"
```

---

## Phase 2 Complete — Verification Checklist

```bash
# CrowdSec running
ssh rainforest@raspberrypi-5.local "docker ps | grep crowdsec"
# Expected: homelab-crowdsec and homelab-crowdsec-bouncer both Up

# CrowdSec metrics
curl http://raspberrypi-5.local:6060/metrics | grep cs_active_decisions

# Ntopng running
ssh rainforest@raspberrypi-5.local "docker ps | grep ntopng"
curl -s -o /dev/null -w "%{http_code}" http://raspberrypi-5.local:3001/

# Blackbox Exporter pod running
kubectl get pods -n monitoring | grep blackbox

# Prometheus has CrowdSec target
curl -s "http://localhost:9090/api/v1/targets" | \
  python3 -m json.tool | grep crowdsec
```
