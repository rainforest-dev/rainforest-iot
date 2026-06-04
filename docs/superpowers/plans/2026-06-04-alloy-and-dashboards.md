# Alloy Pi + Observability Dashboards Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy Grafana Alloy on the Pi to ship Pi Docker and K3s pod logs to Loki, then add four Grafana dashboards covering personal analytics (AI/automation, home/music, storage/reading) and security (HA login attempts).

**Architecture:** Alloy runs as a Docker container on the Pi, mounting the Docker socket for container logs and `/var/log/pods` for K3s pod logs. It pushes to local Loki (NodePort 30100) and Prometheus (NodePort 30090). Dashboards are Grafana JSON files provisioned via the existing `modules/prometheus-stack/dashboards/` Terraform pattern.

**Tech Stack:** Grafana Alloy v1.8.2, Terraform kreuzwerker/docker provider (SSH remote), River config language, LogQL (Loki), PromQL (Prometheus)

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `modules/grafana-alloy-pi/main.tf` | Create | Docker container resource for Alloy on Pi |
| `modules/grafana-alloy-pi/alloy.river` | Create | Pi-side Alloy pipeline: Docker logs, K3s pod logs, system metrics |
| `modules/grafana-alloy-pi/variables.tf` | Create | Input variables |
| `modules/grafana-alloy-pi/outputs.tf` | Create | Alloy UI URL |
| `modules/grafana-alloy-pi/versions.tf` | Create | Docker provider constraint |
| `main.tf` | Modify | Wire module |
| `variables.tf` | Modify | Add alloy_pi_version variable |
| `modules/prometheus-stack/dashboards/ai-automation.json` | Create | AI & Automation analytics dashboard |
| `modules/prometheus-stack/dashboards/home-music.json` | Create | Home & Music analytics dashboard |
| `modules/prometheus-stack/dashboards/ha-security.json` | Create | HA failed login attempts security dashboard |

---

## Task 1: Create grafana-alloy-pi module

**Files:**
- Create: `modules/grafana-alloy-pi/versions.tf`
- Create: `modules/grafana-alloy-pi/variables.tf`
- Create: `modules/grafana-alloy-pi/outputs.tf`
- Create: `modules/grafana-alloy-pi/main.tf`
- Create: `modules/grafana-alloy-pi/alloy.river`

- [ ] **Step 1: Create versions.tf**

```hcl
# modules/grafana-alloy-pi/versions.tf
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}
```

- [ ] **Step 2: Create variables.tf**

```hcl
# modules/grafana-alloy-pi/variables.tf
variable "project_name" {
  type    = string
  default = "homelab"
}

variable "image_version" {
  description = "Grafana Alloy Docker image version"
  type        = string
  default     = "v1.8.2"
}

variable "prometheus_url" {
  description = "Local Prometheus remote_write endpoint (NodePort on Pi)"
  type        = string
  default     = "http://192.168.0.128:30090/api/v1/write"
}

variable "loki_url" {
  description = "Local Loki push endpoint (NodePort on Pi)"
  type        = string
  default     = "http://192.168.0.128:30100/loki/api/v1/push"
}

variable "log_opts" {
  type = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}
```

- [ ] **Step 3: Create outputs.tf**

```hcl
# modules/grafana-alloy-pi/outputs.tf
output "ui_url" {
  description = "Grafana Alloy debug UI (accessible on Pi LAN)"
  value       = "http://192.168.0.128:12346"
}
```

- [ ] **Step 4: Create main.tf**

Note: This module uses the Pi's Docker provider (SSH remote), matching the pattern used by other Pi Docker modules like `modules/pi-hole/main.tf`.

```hcl
# modules/grafana-alloy-pi/main.tf
resource "docker_image" "alloy" {
  name         = "grafana/alloy:${var.image_version}"
  keep_locally = true
}

resource "docker_container" "alloy" {
  name  = "${var.project_name}-alloy-pi"
  image = docker_image.alloy.image_id

  restart = "unless-stopped"

  command = [
    "run",
    "--server.http.listen-addr=0.0.0.0:12345",
    "--storage.path=/var/lib/alloy",
    "/etc/alloy/alloy.river",
  ]

  env = [
    "PROMETHEUS_REMOTE_WRITE_URL=${var.prometheus_url}",
    "LOKI_PUSH_URL=${var.loki_url}",
  ]

  volumes {
    host_path      = "/opt/homelab/alloy/alloy.river"
    container_path = "/etc/alloy/alloy.river"
    read_only      = true
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  volumes {
    host_path      = "/var/log/pods"
    container_path = "/var/log/pods"
    read_only      = true
  }

  ports {
    internal = 12345
    external = 12346
    protocol = "tcp"
  }

  memory = 192

  log_driver = "json-file"
  log_opts   = var.log_opts

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://localhost:12345/-/healthy"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }
}
```

Note: Port 12346 on the Pi (not 12345) to avoid conflict if Mac Mini Alloy is ever accessed via tunnel. The alloy.river is provisioned to `/opt/homelab/alloy/alloy.river` on the Pi via a `null_resource` (see Task 2).

- [ ] **Step 5: Create alloy.river**

```river
// modules/grafana-alloy-pi/alloy.river

// ─── Prometheus: Pi system metrics ──────────────────────────────────────────

prometheus.exporter.unix "pi" {}

prometheus.scrape "unix" {
  targets         = prometheus.exporter.unix.pi.targets
  forward_to      = [prometheus.remote_write.local.receiver]
  scrape_interval = "30s"
  job_name        = "pi-node-alloy"
}

prometheus.remote_write "local" {
  endpoint {
    url = env("PROMETHEUS_REMOTE_WRITE_URL")

    queue_config {
      max_samples_per_send = 1000
      batch_send_deadline  = "5s"
    }
  }
}

// ─── Loki: Pi Docker container logs (HA, MA, Homebridge, Pi-hole) ───────────

discovery.docker "running" {
  host = "unix:///var/run/docker.sock"
}

loki.source.docker "containers" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.docker.running.targets
  forward_to = [loki.write.local.receiver]
}

// ─── Loki: K3s pod logs (Prometheus, Loki, Grafana, Alertmanager) ───────────

local.file_match "k3s_pods" {
  path_targets = [{
    __path__ = "/var/log/pods/**/*.log"
    job      = "k3s-pods"
  }]
}

loki.source.file "k3s_pods" {
  targets    = local.file_match.k3s_pods.targets
  forward_to = [loki.write.local.receiver]
}

// ─── Loki: Push to local Loki ────────────────────────────────────────────────

loki.write "local" {
  endpoint {
    url = env("LOKI_PUSH_URL")
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add modules/grafana-alloy-pi/
git commit -m "feat: add grafana-alloy-pi module for Pi log and metric collection"
```

---

## Task 2: Provision alloy.river to Pi and wire module

**Files:**
- Modify: `main.tf`
- Modify: `variables.tf`

The Pi Docker provider is SSH-based. The alloy.river config must be copied to the Pi before the container starts. Look at how `modules/pi-hole/main.tf` handles SSH file provisioning — use the same `null_resource` + `connection` pattern.

- [ ] **Step 1: Add variable to variables.tf**

```hcl
variable "alloy_pi_version" {
  description = "Grafana Alloy version for Pi deployment"
  type        = string
  default     = "v1.8.2"
}
```

- [ ] **Step 2: Add provisioner + module to main.tf**

```hcl
# Copy alloy.river to Pi before container starts
resource "null_resource" "alloy_pi_config" {
  triggers = {
    config_hash = filemd5("${path.module}/modules/grafana-alloy-pi/alloy.river")
  }

  connection {
    type        = "ssh"
    host        = var.raspberry_pi_ip
    user        = var.raspberry_pi_user
    private_key = file("~/.ssh/id_ed25519")
    port        = var.raspberry_pi_ssh_port
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p /opt/homelab/alloy"]
  }

  provisioner "file" {
    source      = "${path.module}/modules/grafana-alloy-pi/alloy.river"
    destination = "/opt/homelab/alloy/alloy.river"
  }
}

module "grafana_alloy_pi" {
  source     = "./modules/grafana-alloy-pi"
  depends_on = [null_resource.alloy_pi_config]

  providers = {
    docker = docker.pi
  }

  project_name   = var.project_name
  image_version  = var.alloy_pi_version
  prometheus_url = "http://${var.raspberry_pi_ip}:30090/api/v1/write"
  loki_url       = "http://${var.raspberry_pi_ip}:30100/loki/api/v1/push"
  log_opts       = {}
}
```

- [ ] **Step 3: Commit**

```bash
git add main.tf variables.tf
git commit -m "feat: wire grafana-alloy-pi into root config with SSH provisioner"
```

---

## Task 3: Deploy Pi Alloy and verify

- [ ] **Step 1: Plan**

```bash
terraform plan
```

Expected: `1 null_resource` + `1 docker_image` + `1 docker_container` to add

- [ ] **Step 2: Apply**

```bash
terraform apply
```

- [ ] **Step 3: Verify Alloy healthy on Pi**

```bash
ssh rainforest@192.168.0.128 "curl -s http://localhost:12346/-/healthy"
```

Expected: `Alloy is Healthy.`

- [ ] **Step 4: Verify Pi Docker logs in Loki**

Open Grafana at `http://192.168.0.128:30080`. Explore → Loki:

```logql
{job="docker", container="homeassistant"} | limit 20
```

Expected: Home Assistant log lines

- [ ] **Step 5: Verify K3s pod logs in Loki**

```logql
{job="k3s-pods"} | limit 20
```

Expected: log lines from Prometheus/Loki/Grafana pods on the Pi

- [ ] **Step 6: Commit**

```bash
git commit --allow-empty -m "chore: alloy pi deployment verified"
```

---

## Task 4: AI & Automation dashboard

**Files:**
- Create: `modules/prometheus-stack/dashboards/ai-automation.json`

This dashboard uses Loki log-count queries (no custom Prometheus metrics needed — cAdvisor provides resource usage, Loki counts log events as a proxy for activity).

- [ ] **Step 1: Create ai-automation.json**

```json
{
  "annotations": {"list": []},
  "editable": true,
  "graphTooltip": 0,
  "panels": [
    {
      "collapsed": false,
      "gridPos": {"h": 1, "w": 24, "x": 0, "y": 0},
      "id": 1,
      "title": "n8n Workflows",
      "type": "row"
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "green", "value": null}]}}, "overrides": []},
      "gridPos": {"h": 4, "w": 6, "x": 0, "y": 1},
      "id": 2,
      "options": {"colorMode": "background", "graphMode": "none", "reduceOptions": {"calcs": ["sum"]}},
      "title": "n8n Executions (24h)",
      "type": "stat",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "sum(count_over_time({namespace=\"homelab\"} |= \"Execution\" | json [24h]))", "legendFormat": "executions", "refId": "A"}]
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "green", "value": null}, {"color": "red", "value": 1}]}}, "overrides": []},
      "gridPos": {"h": 4, "w": 6, "x": 6, "y": 1},
      "id": 3,
      "options": {"colorMode": "background", "graphMode": "none", "reduceOptions": {"calcs": ["sum"]}},
      "title": "n8n Errors (24h)",
      "type": "stat",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "sum(count_over_time({namespace=\"homelab\"} |= \"ERROR\" [24h]))", "legendFormat": "errors", "refId": "A"}]
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {}},
      "gridPos": {"h": 6, "w": 12, "x": 12, "y": 1},
      "id": 4,
      "options": {"dedupStrategy": "none", "enableLogDetails": true, "showTime": true, "sortOrder": "Descending"},
      "title": "n8n Recent Logs",
      "type": "logs",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "{namespace=\"homelab\", pod=~\"n8n.*\"}", "refId": "A"}]
    },
    {
      "collapsed": false,
      "gridPos": {"h": 1, "w": 24, "x": 0, "y": 7},
      "id": 5,
      "title": "Whisper STT",
      "type": "row"
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "green", "value": null}]}}, "overrides": []},
      "gridPos": {"h": 4, "w": 6, "x": 0, "y": 8},
      "id": 6,
      "options": {"colorMode": "background", "graphMode": "none", "reduceOptions": {"calcs": ["sum"]}},
      "title": "Transcription Requests (24h)",
      "type": "stat",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "sum(count_over_time({container=\"homelab-whisper\"} |= \"transcription\" [24h]))", "refId": "A"}]
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {}},
      "gridPos": {"h": 6, "w": 18, "x": 6, "y": 8},
      "id": 7,
      "options": {"dedupStrategy": "none", "enableLogDetails": true, "showTime": true, "sortOrder": "Descending"},
      "title": "Whisper Recent Logs",
      "type": "logs",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "{container=\"homelab-whisper\"}", "refId": "A"}]
    },
    {
      "collapsed": false,
      "gridPos": {"h": 1, "w": 24, "x": 0, "y": 14},
      "id": 8,
      "title": "Open WebUI & Flowise",
      "type": "row"
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {}},
      "gridPos": {"h": 6, "w": 12, "x": 0, "y": 15},
      "id": 9,
      "options": {"dedupStrategy": "none", "enableLogDetails": true, "showTime": true, "sortOrder": "Descending"},
      "title": "Open WebUI Recent Logs",
      "type": "logs",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "{namespace=\"homelab\", pod=~\"open-webui.*\"}", "refId": "A"}]
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {}},
      "gridPos": {"h": 6, "w": 12, "x": 12, "y": 15},
      "id": 10,
      "options": {"dedupStrategy": "none", "enableLogDetails": true, "showTime": true, "sortOrder": "Descending"},
      "title": "Flowise Recent Logs",
      "type": "logs",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "{namespace=\"homelab\", pod=~\".*flowise.*\"}", "refId": "A"}]
    }
  ],
  "refresh": "5m",
  "schemaVersion": 38,
  "tags": ["homelab", "analytics", "ai"],
  "templating": {"list": []},
  "time": {"from": "now-24h", "to": "now"},
  "timezone": "browser",
  "title": "AI & Automation",
  "uid": "homelab-ai-automation",
  "version": 1
}
```

Note: `${loki_uid}` will be replaced by the Terraform template with the actual Loki datasource UID. Check how existing dashboards handle this in `modules/prometheus-stack/main.tf` — look for `templatefile` or `replace` calls on the JSON.

- [ ] **Step 2: Verify the JSON is valid**

```bash
python3 -c "import json; json.load(open('modules/prometheus-stack/dashboards/ai-automation.json'))" && echo "Valid JSON"
```

Expected: `Valid JSON`

- [ ] **Step 3: Commit**

```bash
git add modules/prometheus-stack/dashboards/ai-automation.json
git commit -m "feat: add AI & Automation Grafana dashboard"
```

---

## Task 5: Home & Music dashboard

**Files:**
- Create: `modules/prometheus-stack/dashboards/home-music.json`

- [ ] **Step 1: Create home-music.json**

```json
{
  "annotations": {"list": []},
  "editable": true,
  "graphTooltip": 0,
  "panels": [
    {
      "collapsed": false,
      "gridPos": {"h": 1, "w": 24, "x": 0, "y": 0},
      "id": 1,
      "title": "Home Assistant",
      "type": "row"
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "green", "value": null}]}}, "overrides": []},
      "gridPos": {"h": 4, "w": 6, "x": 0, "y": 1},
      "id": 2,
      "options": {"colorMode": "background", "graphMode": "none", "reduceOptions": {"calcs": ["sum"]}},
      "title": "Automations Fired (24h)",
      "type": "stat",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "sum(count_over_time({container=\"homeassistant\"} |= \"Executing script\" [24h]))", "refId": "A"}]
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "green", "value": null}, {"color": "orange", "value": 1}]}}, "overrides": []},
      "gridPos": {"h": 4, "w": 6, "x": 6, "y": 1},
      "id": 3,
      "options": {"colorMode": "background", "graphMode": "none", "reduceOptions": {"calcs": ["sum"]}},
      "title": "HA Errors (24h)",
      "type": "stat",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "sum(count_over_time({container=\"homeassistant\"} |= \"ERROR\" [24h]))", "refId": "A"}]
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {}},
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 1},
      "id": 4,
      "options": {"dedupStrategy": "none", "enableLogDetails": true, "showTime": true, "sortOrder": "Descending"},
      "title": "HA Recent Logs",
      "type": "logs",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "{container=\"homeassistant\"} | level != \"debug\"", "refId": "A"}]
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {}},
      "gridPos": {"h": 6, "w": 12, "x": 0, "y": 5},
      "id": 5,
      "options": {"dedupStrategy": "none", "enableLogDetails": true, "showTime": true, "sortOrder": "Descending"},
      "title": "Google Home Commands",
      "type": "logs",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "{container=\"homeassistant\"} |= \"google_assistant\"", "refId": "A"}]
    },
    {
      "collapsed": false,
      "gridPos": {"h": 1, "w": 24, "x": 0, "y": 11},
      "id": 6,
      "title": "Music Assistant",
      "type": "row"
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "green", "value": null}]}}, "overrides": []},
      "gridPos": {"h": 4, "w": 6, "x": 0, "y": 12},
      "id": 7,
      "options": {"colorMode": "background", "graphMode": "none", "reduceOptions": {"calcs": ["sum"]}},
      "title": "Tracks Played (24h)",
      "type": "stat",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "sum(count_over_time({container=\"music-assistant-server\"} |= \"Playing\" [24h]))", "refId": "A"}]
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {}},
      "gridPos": {"h": 6, "w": 18, "x": 6, "y": 12},
      "id": 8,
      "options": {"dedupStrategy": "none", "enableLogDetails": true, "showTime": true, "sortOrder": "Descending"},
      "title": "Music Assistant Recent Logs",
      "type": "logs",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "{container=\"music-assistant-server\"}", "refId": "A"}]
    }
  ],
  "refresh": "5m",
  "schemaVersion": 38,
  "tags": ["homelab", "analytics", "home"],
  "templating": {"list": []},
  "time": {"from": "now-24h", "to": "now"},
  "timezone": "browser",
  "title": "Home & Music",
  "uid": "homelab-home-music",
  "version": 1
}
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -c "import json; json.load(open('modules/prometheus-stack/dashboards/home-music.json'))" && echo "Valid JSON"
```

- [ ] **Step 3: Commit**

```bash
git add modules/prometheus-stack/dashboards/home-music.json
git commit -m "feat: add Home & Music Grafana dashboard"
```

---

## Task 6: HA Security dashboard

**Files:**
- Create: `modules/prometheus-stack/dashboards/ha-security.json`

- [ ] **Step 1: Create ha-security.json**

```json
{
  "annotations": {"list": []},
  "editable": true,
  "graphTooltip": 0,
  "panels": [
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "green", "value": null}, {"color": "orange", "value": 5}, {"color": "red", "value": 20}]}}, "overrides": []},
      "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
      "id": 1,
      "options": {"colorMode": "background", "graphMode": "none", "reduceOptions": {"calcs": ["sum"]}},
      "title": "Failed Login Attempts (24h)",
      "type": "stat",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "sum(count_over_time({container=\"homeassistant\"} |= \"invalid authentication\" [24h]))", "refId": "A"}]
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "green", "value": null}, {"color": "red", "value": 1}]}}, "overrides": []},
      "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
      "id": 2,
      "options": {"colorMode": "background", "graphMode": "none", "reduceOptions": {"calcs": ["sum"]}},
      "title": "Banned IPs (24h)",
      "type": "stat",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "sum(count_over_time({container=\"homeassistant\"} |= \"ban\" [24h]))", "refId": "A"}]
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {"custom": {"fillOpacity": 10}, "color": {"mode": "palette-classic"}}},
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
      "id": 3,
      "options": {"tooltip": {"mode": "single"}},
      "title": "Failed Login Attempts Over Time",
      "type": "timeseries",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "sum(count_over_time({container=\"homeassistant\"} |= \"invalid authentication\" [5m]))", "legendFormat": "failed logins", "refId": "A"}]
    },
    {
      "datasource": {"type": "loki", "uid": "${loki_uid}"},
      "fieldConfig": {"defaults": {}},
      "gridPos": {"h": 10, "w": 24, "x": 0, "y": 8},
      "id": 4,
      "options": {"dedupStrategy": "none", "enableLogDetails": true, "showTime": true, "sortOrder": "Descending"},
      "title": "HA Authentication Log (failed attempts)",
      "type": "logs",
      "targets": [{"datasource": {"type": "loki", "uid": "${loki_uid}"}, "expr": "{container=\"homeassistant\"} |= \"invalid authentication\"", "refId": "A"}]
    }
  ],
  "refresh": "5m",
  "schemaVersion": 38,
  "tags": ["homelab", "security"],
  "templating": {"list": []},
  "time": {"from": "now-24h", "to": "now"},
  "timezone": "browser",
  "title": "HA Security",
  "uid": "homelab-ha-security",
  "version": 1
}
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -c "import json; json.load(open('modules/prometheus-stack/dashboards/ha-security.json'))" && echo "Valid JSON"
```

- [ ] **Step 3: Commit**

```bash
git add modules/prometheus-stack/dashboards/ha-security.json
git commit -m "feat: add HA Security Grafana dashboard"
```

---

## Task 7: Wire dashboards into Terraform and deploy

- [ ] **Step 1: Check how existing dashboards are provisioned in prometheus-stack**

```bash
grep -n "dashboard\|ConfigMap\|grafana" modules/prometheus-stack/main.tf | head -30
```

Find the `kubernetes_config_map` resource that provisions dashboards and add the three new JSON files to it, following the exact same pattern as existing entries.

- [ ] **Step 2: Apply**

```bash
terraform apply
```

- [ ] **Step 3: Verify dashboards appear in Grafana**

Open `http://192.168.0.128:30080`. Go to **Dashboards**. Confirm these three appear:
- AI & Automation
- Home & Music
- HA Security

- [ ] **Step 4: Spot-check one panel**

Open **HA Security** dashboard. The "Failed Login Attempts (24h)" stat panel should show a number > 0 (we saw many failed attempts from Taiwan IPs in the logs).

If it shows 0, open **Explore → Loki** and run:
```logql
{container="homeassistant"} |= "invalid authentication" | limit 5
```
If that returns results, the LogQL query in the dashboard may need tuning (the container label might differ — check the actual label with `{job="docker"} | limit 1`).

- [ ] **Step 5: Commit**

```bash
git add modules/prometheus-stack/main.tf
git commit -m "feat: provision AI/Automation, Home/Music, HA Security dashboards in Grafana"
```
