# Phase 1: Foundation — Version Pinning, Secrets, Pi-hole Enhancement

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all `:latest`/`:main` image tags to pinned versions, move secrets out of git, and enhance Pi-hole with threat blocklists and a Prometheus exporter.

**Architecture:** Version numbers are centralised in `terraform.tfvars` and referenced via variables in each module. Secrets are marked `sensitive = true` in `variables.tf`. Pi-hole gains a sidecar exporter container and three threat blocklists injected via environment variable.

**Tech Stack:** Terraform, Docker provider, Helm, Kubernetes provider, Pi-hole, pihole-exporter

**Spec:** `docs/superpowers/specs/2026-05-21-homelab-security-monitoring-design.md` — Phase 1

---

## File Map

**rainforest-iot**

| Action | File |
|---|---|
| Modify | `terraform.tfvars` — add pinned version variables |
| Modify | `variables.tf` — declare version variables; mark passwords sensitive |
| Modify | `modules/pi-hole/main.tf` — pin image, add exporter container, inject blocklists |
| Modify | `modules/pi-hole/variables.tf` — add exporter + blocklist vars |
| Modify | `modules/homeassistant/main.tf` — pin image version var |
| Modify | `modules/homeassistant/variables.tf` — add image_version var |
| Modify | `modules/homebridge/main.tf` — pin image version var |
| Modify | `modules/homebridge/variables.tf` — add image_version var |
| Modify | `modules/homepage/main.tf` — pin image version var |
| Modify | `modules/homepage/variables.tf` — add image_version var |
| Modify | `modules/openspeedtest/main.tf` — pin image version var |
| Modify | `modules/openspeedtest/variables.tf` — add image_version var |
| Modify | `modules/monitoring-integrations/main.tf` — add Pi-hole exporter scrape target |
| Create | `modules/k3s-cluster/gravity-cronjob.tf` — weekly Pi-hole gravity update |
| Verify | `.gitignore` — ensure `terraform.tfvars` and `*.tfvars` are excluded |

**rainforest-homelab** (worktree: `goofy-northcutt-72b552`)

| Action | File |
|---|---|
| Modify | `modules/open-webui/main.tf` — fix `:main` → pinned version |
| Modify | `modules/cloudflare-tunnel/main.tf` — pin cloudflared version |
| Modify | `variables.tf` — mark `grafana_admin_password` (and similar) sensitive |
| Verify | `.gitignore` — `terraform.tfvars` excluded |

---

## Task 1: Verify and fix .gitignore in both repos

**Goal:** Ensure no secrets can accidentally enter git.

- [ ] **Step 1: Check rainforest-iot .gitignore**

```bash
cd /Users/rainforest/Repositories/rainforest-iot
cat .gitignore | grep -E "tfvars|\.env|secret"
```

Expected output should include `terraform.tfvars` or `*.tfvars`. If missing, add it.

- [ ] **Step 2: Add if missing (rainforest-iot)**

```bash
# Only run if Step 1 shows tfvars is NOT excluded
echo "terraform.tfvars" >> .gitignore
echo "*.tfvars.backup" >> .gitignore
```

- [ ] **Step 3: Check rainforest-homelab .gitignore**

```bash
cd /Users/rainforest/Repositories/rainforest-homelab
cat .gitignore | grep -E "tfvars|\.env|secret"
```

- [ ] **Step 4: Add if missing (rainforest-homelab)**

```bash
# Only run if Step 3 shows tfvars is NOT excluded
echo "terraform.tfvars" >> .gitignore
```

- [ ] **Step 5: Verify terraform.tfvars is NOT tracked by git**

```bash
cd /Users/rainforest/Repositories/rainforest-iot
git status terraform.tfvars
# Expected: "nothing to commit" or "Untracked files" — NOT "modified" or "new file"

cd /Users/rainforest/Repositories/rainforest-homelab
git status terraform.tfvars
```

If `terraform.tfvars` shows as tracked in either repo, run:
```bash
git rm --cached terraform.tfvars
git commit -m "chore: stop tracking terraform.tfvars"
```

> ⚠️ If sensitive values (passwords, tokens) are already in git history, use `git filter-repo --path terraform.tfvars --invert-paths` to scrub history. **Back up the repo first. This rewrites history.**

- [ ] **Step 6: Commit .gitignore changes**

```bash
cd /Users/rainforest/Repositories/rainforest-iot
git add .gitignore
git commit -m "chore: ensure terraform.tfvars excluded from git"
```

---

## Task 2: Fix secrets — mark sensitive variables (rainforest-iot)

**Goal:** Terraform will no longer print `grafana_admin_password` in plan/apply output.

- [ ] **Step 1: Find all password/secret variables in variables.tf**

```bash
cd /Users/rainforest/Repositories/rainforest-iot
grep -n "password\|token\|secret\|api_key" variables.tf | grep -v "#"
```

Note each variable name found.

- [ ] **Step 2: Add `sensitive = true` to each**

For each password/secret variable found, add `sensitive = true`. Example for `grafana_admin_password`:

```hcl
# variables.tf
variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true   # ← add this line
}
```

Also add for: `pihole_api_token`, `teleport_auth_token`, and any other secrets found.

- [ ] **Step 3: Update terraform.tfvars with a strong password**

Generate a strong password:
```bash
openssl rand -base64 24
```

Replace `"admin123"` with the generated value in `terraform.tfvars`:
```hcl
grafana_admin_password = "<generated-strong-password>"
```

- [ ] **Step 4: Validate**

```bash
cd /Users/rainforest/Repositories/rainforest-iot
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 5: Confirm plan does not expose password**

```bash
terraform plan 2>&1 | grep -i "password\|admin123"
```

Expected: any password value shown as `(sensitive value)`, not the actual string.

- [ ] **Step 6: Commit**

```bash
git add variables.tf
git commit -m "security: mark secret variables as sensitive"
```

---

## Task 3: Fix secrets — rainforest-homelab

Same as Task 2 but for the homelab repo.

- [ ] **Step 1: Find secret variables**

```bash
cd /Users/rainforest/Repositories/rainforest-homelab
grep -n "password\|token\|secret\|api_key\|client_secret" variables.tf | grep -v "#"
```

- [ ] **Step 2: Add `sensitive = true` to each found variable**

```hcl
variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}
```

- [ ] **Step 3: Validate**

```bash
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 4: Commit**

```bash
git add variables.tf
git commit -m "security: mark secret variables as sensitive"
```

---

## Task 4: Pin image versions — rainforest-iot

**Goal:** Replace all `:latest` tags with explicit version numbers.

- [ ] **Step 1: Look up current stable releases**

Check each project's GitHub releases page for the latest stable version:
- Pi-hole: https://github.com/pi-hole/docker-pi-hole/releases
- Homebridge: https://github.com/homebridge/homebridge/releases
- Homepage: https://github.com/gethomepage/homepage/releases
- OpenSpeedtest: https://hub.docker.com/r/openspeedtest/latest/tags

Note the latest stable version for each.

- [ ] **Step 2: Add version variables to root variables.tf**

```hcl
# variables.tf — add these blocks
variable "pihole_image_version" {
  description = "Pi-hole Docker image version"
  type        = string
  default     = "2024.07.0"   # Update to latest from Step 1
}

variable "homebridge_image_version" {
  description = "Homebridge Docker image version"
  type        = string
  default     = "2024.12.0"   # Update to latest from Step 1
}

variable "homepage_image_version" {
  description = "Homepage Docker image version"
  type        = string
  default     = "v0.9.10"     # Update to latest from Step 1
}

variable "openspeedtest_image_version" {
  description = "OpenSpeedtest image version"
  type        = string
  default     = "v2.0.5"      # Update to latest from Step 1
}
```

- [ ] **Step 3: Pin versions in terraform.tfvars**

```hcl
# terraform.tfvars — add pinned versions (override defaults)
pihole_image_version         = "<version from Step 1>"
homebridge_image_version     = "<version from Step 1>"
homepage_image_version       = "<version from Step 1>"
openspeedtest_image_version  = "<version from Step 1>"
```

- [ ] **Step 4: Update modules to accept version variable**

**modules/pi-hole/variables.tf** — add:
```hcl
variable "image_version" {
  description = "Pi-hole Docker image version"
  type        = string
  default     = "2024.07.0"
}
```

**modules/pi-hole/main.tf** — change image name:
```hcl
# Before:
name = "pihole/pihole:latest"
# After:
name = "pihole/pihole:${var.image_version}"
```

Repeat for **modules/homebridge/**, **modules/homepage/**, **modules/openspeedtest/** — same pattern: add `image_version` variable, update `name = "image:${var.image_version}"`.

- [ ] **Step 5: Pass version from root to modules in main.tf**

```hcl
# main.tf — add image_version to each module block
module "pi-hole" {
  source = "./modules/pi-hole"
  # ... existing vars ...
  image_version = var.pihole_image_version
}

module "homebridge" {
  source = "./modules/homebridge"
  # ... existing vars ...
  image_version = var.homebridge_image_version
}

module "homepage" {
  source = "./modules/homepage"
  # ... existing vars ...
  image_version = var.homepage_image_version
}

module "openspeedtest" {
  source = "./modules/openspeedtest"
  # ... existing vars ...
  image_version = var.openspeedtest_image_version
}
```

- [ ] **Step 6: Validate and plan**

```bash
terraform validate
terraform plan
```

Expected: plan shows image tag changes for each pinned service (e.g. `"pihole/pihole:latest" -> "pihole/pihole:2024.07.0"`).

- [ ] **Step 7: Apply**

```bash
terraform apply
```

- [ ] **Step 8: Verify containers are running with new tags**

```bash
# SSH to RPi or check via Docker provider
ssh rainforest@raspberrypi-5.local "docker ps --format 'table {{.Image}}\t{{.Status}}'"
```

Expected: no `:latest` tags visible for pinned services.

- [ ] **Step 9: Commit**

```bash
git add modules/pi-hole/variables.tf modules/pi-hole/main.tf \
        modules/homebridge/variables.tf modules/homebridge/main.tf \
        modules/homepage/variables.tf modules/homepage/main.tf \
        modules/openspeedtest/variables.tf modules/openspeedtest/main.tf \
        variables.tf terraform.tfvars main.tf
git commit -m "fix: pin all Docker image versions, remove :latest tags"
```

---

## Task 5: Pin image versions — rainforest-homelab

- [ ] **Step 1: Look up current stable releases**

- Open WebUI: https://github.com/open-webui/open-webui/releases
- cloudflared: https://github.com/cloudflare/cloudflared/releases

Note the latest version numbers.

- [ ] **Step 2: Fix Open WebUI image in modules/open-webui/main.tf**

```hcl
# Before:
image = "ghcr.io/open-webui/open-webui:main"
# After:
image = "ghcr.io/open-webui/open-webui:${var.image_version}"
```

Add to **modules/open-webui/variables.tf**:
```hcl
variable "image_version" {
  description = "Open WebUI Docker image version"
  type        = string
  default     = "v0.5.10"   # Update to latest from Step 1
}
```

Add to root **variables.tf**:
```hcl
variable "open_webui_image_version" {
  type    = string
  default = "v0.5.10"
}
```

Pass in root **main.tf**:
```hcl
module "open_webui" {
  # ... existing ...
  image_version = var.open_webui_image_version
}
```

- [ ] **Step 3: Fix cloudflared in modules/cloudflare-tunnel/main.tf**

Find the line containing `cloudflare/cloudflared:latest` (it's in a Kubernetes manifest template):
```bash
grep -n "cloudflared" modules/cloudflare-tunnel/main.tf
```

Replace `:latest` with the pinned version:
```hcl
image: cloudflare/cloudflared:<version from Step 1>
```

If the image is embedded in a template string, extract it to a variable:

Add to **modules/cloudflare-tunnel/variables.tf**:
```hcl
variable "cloudflared_version" {
  type    = string
  default = "2025.4.0"
}
```

Reference it in the template:
```hcl
image: cloudflare/cloudflared:${var.cloudflared_version}
```

- [ ] **Step 4: Validate and plan**

```bash
cd /Users/rainforest/Repositories/rainforest-homelab
terraform validate
terraform plan
```

Expected: plan shows image updates for Open WebUI and cloudflared.

- [ ] **Step 5: Apply and verify**

```bash
terraform apply
kubectl get pods -n homelab | grep -E "webui|cloudflared"
```

- [ ] **Step 6: Commit**

```bash
git add modules/open-webui/ modules/cloudflare-tunnel/ variables.tf main.tf
git commit -m "fix: pin open-webui and cloudflared versions, remove :latest/:main tags"
```

---

## Task 6: Add Pi-hole threat blocklists

**Goal:** Pi-hole blocks malware, phishing, and tracking domains — not just ads.

- [ ] **Step 1: Add blocklist variable to modules/pi-hole/variables.tf**

```hcl
variable "blocklists" {
  description = "Additional blocklist URLs to add to Pi-hole gravity"
  type        = list(string)
  default = [
    "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt",
    "https://big.oisd.nl/",
    "https://openphish.com/feed.txt",
  ]
}
```

- [ ] **Step 2: Inject blocklists via environment variable in modules/pi-hole/main.tf**

Find the `docker_container` resource for Pi-hole and add to its `env` block:

```hcl
env = concat(var.env, [
  "PIHOLE_DNS_=192.168.0.1",
  # Blocklists injected at container startup via PIHOLE_BLOCKLISTS_URLS
  # (Pi-hole v6+ supports this env var; for older versions use gravity.sh)
])
```

> **Note:** Pi-hole v6+ supports `PIHOLE_BLOCKLISTS_URLS` environment variable. For Pi-hole v5.x, blocklists must be added via the API or by mounting a custom `adlists.list` file. Check the deployed version:
> ```bash
> ssh rainforest@raspberrypi-5.local "docker exec pihole pihole --version"
> ```

For Pi-hole v5.x, mount a config file instead:

```hcl
# modules/pi-hole/main.tf — add volume mount
volumes {
  host_path      = "/opt/homelab/pihole/adlists.list"
  container_path = "/etc/pihole/adlists.list"
  read_only      = false
}
```

Create the file via a `null_resource`:
```hcl
resource "null_resource" "pihole_adlists" {
  triggers = {
    blocklists = join(",", var.blocklists)
  }

  connection {
    type        = "ssh"
    host        = var.hostname
    user        = var.ssh_user
    port        = var.ssh_port
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /opt/homelab/pihole",
      "printf '%s\n' ${join(" ", [for url in var.blocklists : "'${url}'"])} > /opt/homelab/pihole/adlists.list",
    ]
  }
}
```

- [ ] **Step 3: Pass blocklists from root to module**

No change needed if using the default in the module — the defaults are already set in Step 1. Optionally override in `terraform.tfvars`:

```hcl
# terraform.tfvars — only needed if you want to override defaults
# pihole_blocklists = ["https://..."]
```

- [ ] **Step 4: Validate and apply**

```bash
cd /Users/rainforest/Repositories/rainforest-iot
terraform validate
terraform plan -target=module.pi-hole
terraform apply -target=module.pi-hole
```

- [ ] **Step 5: Trigger gravity update to download new lists**

```bash
ssh rainforest@raspberrypi-5.local "docker exec pihole pihole -g"
```

Expected output: gravity update runs, pulls new blocklists, ends with `Pi-hole blocking is enabled`.

- [ ] **Step 6: Verify blocklists loaded**

```bash
ssh rainforest@raspberrypi-5.local \
  "docker exec pihole sqlite3 /etc/pihole/gravity.db 'SELECT address FROM adlist;'"
```

Expected: rows containing the hagezi, oisd, and openphish URLs.

- [ ] **Step 7: Commit**

```bash
git add modules/pi-hole/
git commit -m "feat(pi-hole): add threat blocklists (hagezi, OISD, openphish)"
```

---

## Task 7: Add Pi-hole Prometheus exporter

**Goal:** Pi-hole statistics (query count, block rate, top blocked domains) visible in Grafana.

- [ ] **Step 1: Add exporter resource to modules/pi-hole/main.tf**

```hcl
resource "docker_image" "pihole_exporter" {
  name         = "ekofr/pihole-exporter:${var.exporter_version}"
  keep_locally = true
}

resource "docker_container" "pihole_exporter" {
  name  = "${var.project_name}-pihole-exporter"
  image = docker_image.pihole_exporter.image_id

  restart = "unless-stopped"

  env = [
    "PIHOLE_HOSTNAME=localhost",
    "PIHOLE_PORT=${var.web_port}",
    "PIHOLE_API_TOKEN=${var.pihole_api_token}",
    "INTERVAL=30s",
    "PORT=9617",
  ]

  networks_advanced {
    name = docker_network.homelab.name
  }

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://localhost:9617/metrics"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "10s"
  }

  memory = 32
}
```

- [ ] **Step 2: Add exporter variables to modules/pi-hole/variables.tf**

```hcl
variable "exporter_version" {
  description = "pihole-exporter Docker image version"
  type        = string
  default     = "v0.4.0"   # Check https://github.com/eko/pihole-exporter/releases
}
```

- [ ] **Step 3: Add scrape target to modules/monitoring-integrations/main.tf**

Find where external scrape targets are defined (look for `ServiceMonitor` or `additionalScrapeConfigs`) and add:

```hcl
# In the additionalScrapeConfigs or ServiceMonitor section:
{
  job_name = "pihole-exporter"
  static_configs = [{
    targets = ["${var.raspberry_pi_hostname}:9617"]
    labels  = { instance = "raspberry-pi-5", service = "pihole" }
  }]
}
```

The exact syntax depends on how monitoring-integrations defines scrape configs. Check the file:
```bash
grep -n "scrape\|ServiceMonitor\|additionalScrape" \
  modules/monitoring-integrations/main.tf | head -20
```

- [ ] **Step 4: Validate and apply**

```bash
terraform validate
terraform plan -target=module.pi-hole -target=module.monitoring_integrations
terraform apply -target=module.pi-hole -target=module.monitoring_integrations
```

- [ ] **Step 5: Verify exporter is running**

```bash
ssh rainforest@raspberrypi-5.local "docker ps | grep pihole-exporter"
curl http://raspberrypi-5.local:9617/metrics | grep pihole_
```

Expected: metrics output including `pihole_domains_being_blocked`, `pihole_dns_queries_today`, `pihole_ads_blocked_today`.

- [ ] **Step 6: Commit**

```bash
git add modules/pi-hole/main.tf modules/pi-hole/variables.tf \
        modules/monitoring-integrations/main.tf
git commit -m "feat(pi-hole): add Prometheus exporter on port 9617"
```

---

## Task 8: Add Pi-hole gravity update CronJob

**Goal:** Blocklists auto-refresh weekly.

- [ ] **Step 1: Create modules/k3s-cluster/gravity-cronjob.tf**

```hcl
resource "kubernetes_cron_job_v1" "pihole_gravity_update" {
  metadata {
    name      = "pihole-gravity-update"
    namespace = "default"
  }

  spec {
    schedule                      = "0 3 * * 0"   # Every Sunday 03:00
    concurrency_policy            = "Forbid"
    failed_jobs_history_limit     = 3
    successful_jobs_history_limit = 1

    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            restart_policy = "OnFailure"
            container {
              name  = "gravity-update"
              image = "alpine:3.19"

              command = [
                "/bin/sh", "-c",
                "apk add --no-cache openssh-client && ssh -o StrictHostKeyChecking=no -i /ssh/id_rsa ${var.pi_user}@${var.pi_hostname} 'docker exec pihole pihole -g'"
              ]

              volume_mount {
                name       = "ssh-key"
                mount_path = "/ssh"
                read_only  = true
              }
            }

            volume {
              name = "ssh-key"
              secret {
                secret_name  = kubernetes_secret.pi_ssh_key.metadata[0].name
                default_mode = "0400"
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_secret" "pi_ssh_key" {
  metadata {
    name      = "pi-ssh-key"
    namespace = "default"
  }

  data = {
    id_rsa = file("~/.ssh/id_rsa")
  }

  type = "Opaque"
}
```

- [ ] **Step 2: Add required variables to modules/k3s-cluster/variables.tf**

```hcl
variable "pi_hostname" {
  description = "Raspberry Pi hostname for CronJob SSH"
  type        = string
  default     = "raspberrypi-5.local"
}

variable "pi_user" {
  description = "Raspberry Pi SSH user"
  type        = string
  default     = "rainforest"
}
```

- [ ] **Step 3: Pass variables from root main.tf**

```hcl
module "k3s_cluster" {
  # ... existing ...
  pi_hostname = var.raspberry_pi_hostname
  pi_user     = var.raspberry_pi_user
}
```

- [ ] **Step 4: Validate and apply**

```bash
terraform validate
terraform plan -target=module.k3s_cluster
terraform apply -target=module.k3s_cluster
```

- [ ] **Step 5: Verify CronJob created**

```bash
kubectl get cronjob -A | grep gravity
```

Expected: `pihole-gravity-update` with schedule `0 3 * * 0`.

- [ ] **Step 6: Test by triggering manually**

```bash
kubectl create job --from=cronjob/pihole-gravity-update gravity-test -n default
kubectl logs job/gravity-test -n default --follow
```

Expected: Pi-hole gravity update output, ends with blocking enabled message.

- [ ] **Step 7: Clean up test job and commit**

```bash
kubectl delete job gravity-test -n default

git add modules/k3s-cluster/gravity-cronjob.tf modules/k3s-cluster/variables.tf main.tf
git commit -m "feat(pi-hole): add weekly gravity update CronJob (Sundays 03:00)"
```

---

## Phase 1 Complete — Verification Checklist

```bash
# All containers running without :latest tags
ssh rainforest@raspberrypi-5.local "docker ps --format '{{.Image}}'" | grep ":latest"
# Expected: no output (empty)

# Pi-hole exporter metrics
curl http://raspberrypi-5.local:9617/metrics | grep "pihole_domains_being_blocked"

# Gravity CronJob exists
kubectl get cronjob -A

# Secrets not visible in plan output
cd /Users/rainforest/Repositories/rainforest-iot && terraform plan 2>&1 | grep "admin123"
# Expected: no output

# .gitignore protecting tfvars
git status terraform.tfvars
# Expected: "nothing to commit" or untracked (not staged)
```
