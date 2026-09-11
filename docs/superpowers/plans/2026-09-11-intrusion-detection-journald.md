# SSH Intrusion Detection via journald — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore local SSH intrusion detection on the Pi by having CrowdSec read journald, remove the broken fail2ban and the dead gravity CronJob, and alert on failed systemd units and a blind CrowdSec — entirely through Terraform and Ansible.

**Architecture:** CrowdSec stays a Terraform-managed container but moves to the `-debian` image (which ships `journalctl`), mounts the host journal read-only, and receives its acquisition config and tailnet whitelist through Terraform `upload` blocks. Ansible removes fail2ban and the stray `/var/log/auth.log` directory. kube-prometheus-stack gains the node-exporter systemd collector and two PrometheusRule alerts.

**Tech Stack:** Terraform 1.5.7 (kreuzwerker/docker 3.0.2, hashicorp/helm 2.17.0, hashicorp/kubernetes), Ansible core 2.21, CrowdSec `v1.8.1-debian`, kube-prometheus-stack 87.19.0 (prometheus-node-exporter 4.56.x), k3s, Debian 12 / systemd 252.

**Spec:** No separate spec document — the design was agreed in the 2026-09-11 homelab session. The Background section below is the spec of record.

## Background (spec of record)

- Raspberry Pi OS 2024-07-04 (bookworm) never had rsyslog: the pi-gen stage0–2 package lists contain no syslog package, and `dpkg.log` since first boot (2024-07-11) has no rsyslog install or removal. SSH logs exist only in journald.
- `ansible/playbooks/system-hardening.yml` points fail2ban at `/var/log/auth.log`, so `fail2ban.service` exits 255 on every boot.
- `modules/crowdsec` bind-mounts `/var/log/auth.log` and `/var/log/syslog`. Docker created `/var/log/auth.log` as an empty directory on 2026-05-21. CrowdSec acquisition reads 0 lines; only the CAPI community blocklist is protecting the host.
- The current image (`v1.6.3`) is Alpine and has no `journalctl`. `v1.8.1-debian` is Debian 12 with systemd 252 — the Pi's own systemd version — and was verified to read the host journal with `/var/log/journal` and `/etc/machine-id` mounted read-only.
- CrowdSec's journalctl source starts with `--follow -n 0`, so the 3.7 GB journal backlog is not replayed. Lines read are exported as `cs_journalctlsource_hits_total{source,datasource_type,acquis_type}`.
- The Pi logs ~470 `[UFW BLOCK]` kernel lines per hour and ~40 sshd lines per day, so kernel acquisition gives the stall alert a steady signal and enables port-scan detection.
- The built-in `crowdsecurity/whitelists` parser covers RFC1918 and loopback but not the tailnet (`100.64.0.0/10`, `fd7a:115c:a1e0::/48`). `module.crowdsec` declares `whitelist_cidrs` but never uses it.
- The native iptables bouncer talks to LAPI at `127.0.0.1:6081`; nothing else uses LAPI, so the port can bind to loopback. Metrics on `:6060` are scraped by k3s Prometheus via the Pi's LAN IP and must stay reachable.
- The `pihole-gravity-update` CronJob has failed every week since at least 2026-07-19 because its `pi-ssh-key` secret is empty. Pi-hole's own in-container cron already runs `pihole updateGravity` on Sundays at 03:23 and succeeds, so the CronJob is redundant.
- `https://pgadmin.rainforest.tools` is still a blackbox target although pgAdmin was removed in rainforest-homelab `50d95ff` and its DNS record is gone.
- node-exporter runs without the systemd collector, so a failed unit raises no alert — fail2ban was down for months unnoticed.
- External access to the Pi is Cloudflare Tunnel and Tailscale only; there are no router port forwards. Tailscale SSH is off (`RunSSH: false`), so tailnet SSH still goes through `ssh.service`.
- The Mac's `~/.kube/config-raspberrypi-5` client certificate expired on 2026-08-17. k3s has already renewed the on-Pi `/etc/rancher/k3s/k3s.yaml` (valid until 2027-04-19).

## Global Constraints

- Work in the main checkout `~/Repositories/rainforest-iot`, not a worktree: `terraform.tfstate` and `terraform.tfvars` are gitignored and exist only there.
- Branch: `fix/intrusion-detection-journald`, from `origin/main`.
- PR #18 (`feat/homepage-missing-services`) is applied live but not merged. Every `terraform plan` and `terraform apply` MUST use `-target` for exactly the resources the task touches. Never run an untargeted apply from this branch — it would roll back the homepage.
- Read every `terraform plan` before applying. If it lists changes outside the task's **Expected plan**, stop and report.
- Ansible: always run with `--tags`. Never run `system-hardening.yml` or `k3s-install.yml` untagged — both begin with apt upgrades, and `k3s-install.yml` can restart k3s.
- Do not commit LAN IP addresses (repo policy since `chore(privacy): stop committing LAN addresses`). Shell steps derive the Pi address from the `rpi5` SSH alias: `PI_IP=$(ssh -G rpi5 | awk '/^hostname /{print $2}')`.
- Never print values from `terraform.tfvars`.
- CrowdSec image tag: `v1.8.1-debian`. kube-prometheus-stack stays at `87.19.0` (a chart bump needs a manual CRD apply).
- Commits: conventional `type(scope): subject`; the message ends with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- Tests for this repo are live checks: `terraform validate`, targeted `terraform plan`, `ansible-playbook --check --diff`, and post-apply probes. Each task records the failing probe before the change and the passing probe after it.

## Execution environment: reaching the k3s API

macOS Local Network privacy blocks non-Apple binaries (kubectl, helm, Terraform providers) from LAN addresses when the process tree lacks the grant — e.g. a Claude Code session under tmux gets `dial tcp …:6443: connect: no route to host` while `/usr/bin/curl` succeeds. `/usr/bin/ssh` is exempt, loopback is never gated, and the k3s API certificate includes `127.0.0.1`.

From a gated session, open an SSH forward before any k3s-facing kubectl or Terraform step:

```bash
K3S_KC=$(mktemp -t k3s-via-ssh); chmod 600 "$K3S_KC"
sed -E 's#server: https://[^:]+:6443#server: https://127.0.0.1:16443#' ~/.kube/config-raspberrypi-5 >| "$K3S_KC"
ssh -f -N -o ExitOnForwardFailure=yes -o BatchMode=yes -L 16443:127.0.0.1:6443 rpi5
kubectl --kubeconfig "$K3S_KC" get nodes
```

Pass `-var "k8s_config_path=$K3S_KC"` to Terraform. Tear down when the task is done:

```bash
pkill -f 'ssh -f -N -o ExitOnForwardFailure=yes -o BatchMode=yes -L 16443:127.0.0.1:6443 rpi5'; rm -f "$K3S_KC"
```

From a terminal app that has the Local Network grant, `~/.kube/config-raspberrypi-5` works directly once Task 1 is done, and the forward is unnecessary. The Docker provider uses `ssh://`, so CrowdSec (Task 2) needs no workaround.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `docs/superpowers/plans/2026-09-11-intrusion-detection-journald.md` | Create | This plan |
| `ansible/playbooks/k3s-install.yml` | Modify | Tag the kubeconfig tasks; server address from facts |
| `modules/crowdsec/acquis.yaml` | Create | journald acquisition (ssh.service + kernel) |
| `modules/crowdsec/main.tf` | Modify | Debian image, journal mounts, config uploads, LAPI on loopback, iptables collection |
| `modules/crowdsec/variables.tf` | Modify | Drop `log_paths`; tailnet `whitelist_cidrs`; image default |
| `variables.tf` | Modify | `crowdsec_version` default; `pi_ssh_private_key` description; drop pgAdmin target |
| `modules/prometheus-stack/main.tf` | Modify | node-exporter systemd collector + D-Bus mount; two alert rules |
| `modules/prometheus-stack/variables.tf` | Modify | Drop pgAdmin target |
| `ansible/playbooks/system-hardening.yml` | Modify | Remove fail2ban and the stray auth.log directory |
| `README.md`, `docs/deployment-guide.md`, `GEMINI.md`, `ansible/README.md` | Modify | fail2ban → CrowdSec |
| `modules/k3s-cluster/gravity-cronjob.tf` | Delete | Redundant CronJob and its empty secret |
| `modules/k3s-cluster/variables.tf` | Modify | Drop the `pi_*` variables |
| `main.tf` | Modify | Stop passing `pi_*` to `k3s_cluster` |

Task order matters: 0 → 1 → 2 → 3 → 4 → 5 → 6. Task 3 must land before Task 4 so that `SystemdUnitFailed` is seen firing for fail2ban (red) and then resolving (green).

---

### Task 0: Branch and baseline

**Files:**
- Create: `docs/superpowers/plans/2026-09-11-intrusion-detection-journald.md` (already written, untracked)

**Interfaces:**
- Consumes: nothing
- Produces: branch `fix/intrusion-detection-journald`; initialised Terraform working directory

- [ ] **Step 1: Confirm a clean tree and create the branch**

```bash
cd ~/Repositories/rainforest-iot
git status --short
git fetch origin
git switch -c fix/intrusion-detection-journald origin/main
```

Expected: `git status --short` shows only `?? docs/superpowers/plans/2026-09-11-intrusion-detection-journald.md`.

- [ ] **Step 2: Baseline validate**

```bash
terraform init -input=false -lockfile=readonly
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit the plan**

```bash
git add docs/superpowers/plans/2026-09-11-intrusion-detection-journald.md
git commit -m "docs(plans): SSH intrusion detection via journald" \
  -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 1: Refresh the stale k3s kubeconfig through Ansible

**Files:**
- Modify: `ansible/playbooks/k3s-install.yml:193-237`

**Interfaces:**
- Consumes: nothing
- Produces: `~/.kube/config-raspberrypi-5` with a valid client certificate and `server: https://<Pi LAN address>:6443`. Tasks 3 and 5 use it.

- [ ] **Step 1: Record the failing probe**

```bash
grep -m1 client-certificate-data ~/.kube/config-raspberrypi-5 | awk '{print $2}' | base64 -d | openssl x509 -noout -enddate
```

Expected: `notAfter=Aug 17 04:13:00 2026 GMT` (in the past).

- [ ] **Step 2: Tag the kubeconfig tasks and take the server address from facts**

Replace lines 193–237 of `ansible/playbooks/k3s-install.yml` (from `- name: Create kubeconfig directory for user` through the `flat: yes` of the fetch task) with:

```yaml
    - name: Create kubeconfig directory for user
      file:
        path: "/home/{{ ansible_user }}/.kube"
        state: directory
        owner: "{{ ansible_user }}"
        group: "{{ ansible_user }}"
        mode: '0755'
      tags: [kubeconfig]

    - name: Copy kubeconfig for user access
      copy:
        src: /etc/rancher/k3s/k3s.yaml
        dest: "/home/{{ ansible_user }}/.kube/config"
        owner: "{{ ansible_user }}"
        group: "{{ ansible_user }}"
        mode: '0600'
        remote_src: yes
      tags: [kubeconfig]

    - name: Update kubeconfig server address
      replace:
        path: "/home/{{ ansible_user }}/.kube/config"
        regexp: 'server: https://[^:]+:6443'
        replace: "server: https://{{ ansible_default_ipv4.address }}:6443"
      tags: [kubeconfig]

    - name: Ensure local .kube directory exists
      file:
        path: "~/.kube"
        state: directory
        mode: '0700'
      delegate_to: localhost
      become: no
      tags: [kubeconfig]

    - name: Backup existing local kubeconfig if it exists
      copy:
        src: "~/.kube/config"
        dest: "~/.kube/config.backup-{{ ansible_date_time.epoch }}"
        mode: '0600'
      delegate_to: localhost
      become: no
      ignore_errors: yes  # In case ~/.kube/config doesn't exist
      tags: [kubeconfig]

    - name: Fetch kubeconfig to local machine for Terraform
      fetch:
        src: "/home/{{ ansible_user }}/.kube/config"
        dest: "~/.kube/config-{{ inventory_hostname }}"
        flat: yes
      tags: [kubeconfig]
```

`ansible_default_ipv4` is the Pi's `wlan0` LAN address (verified), which is in the API certificate's SANs. Facts are still gathered when running with `--tags`.

- [ ] **Step 3: Dry run**

```bash
cd ansible && ansible-playbook playbooks/k3s-install.yml --tags kubeconfig --check --diff; cd ..
```

Expected: only the six tasks above run; no apt, cgroup, or k3s tasks; `failed=0`.

- [ ] **Step 4: Apply**

```bash
cd ansible && ansible-playbook playbooks/k3s-install.yml --tags kubeconfig; cd ..
```

Expected: `failed=0`.

- [ ] **Step 5: Passing probes**

```bash
grep -m1 client-certificate-data ~/.kube/config-raspberrypi-5 | awk '{print $2}' | base64 -d | openssl x509 -noout -enddate
grep -m1 'server:' ~/.kube/config-raspberrypi-5 | grep -c '\.local'
```

Expected: `notAfter` in 2027 or later; `0` (the server is an IP, not a `.local` name).

Then open the SSH forward (see *Execution environment*) and run:

```bash
kubectl --kubeconfig "$K3S_KC" get nodes
```

Expected: `raspberrypi-5   Ready`. Tear the forward down.

- [ ] **Step 6: Commit**

```bash
git add ansible/playbooks/k3s-install.yml
git commit -m "fix(ansible): refresh the Terraform kubeconfig on its own tag" \
  -m "The fetched kubeconfig's client certificate expired on 2026-08-17 although k3s had already renewed its own. The fetch tasks had no tags, so refreshing meant rerunning the whole install, and they rewrote the server to an mDNS name that hangs on lookup." \
  -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: CrowdSec reads journald

**Files:**
- Create: `modules/crowdsec/acquis.yaml`
- Modify: `modules/crowdsec/main.tf:36-60`
- Modify: `modules/crowdsec/variables.tf` (`crowdsec_version`, `whitelist_cidrs`, `log_paths`)
- Modify: `variables.tf:487-491`

**Interfaces:**
- Consumes: nothing
- Produces: metric `cs_journalctlsource_hits_total` on `:6060` (Task 3's stall alert); LAPI on `127.0.0.1:6081` (the native bouncer, unchanged); no bind mount on `/var/log/auth.log` (Task 4 precondition)

- [ ] **Step 1: Record the failing probes**

```bash
ssh rpi5 'docker exec homelab-crowdsec cscli metrics show acquisition; ss -tlnH | grep ":6081 "'
ssh rpi5 'docker exec homelab-crowdsec cscli explain --type syslog --log "Sep 11 12:00:00 raspberrypi-5 sshd[4242]: Invalid user admin from 100.100.1.1 port 51234"' | tail -1
```

Expected: an acquisition table with no rows; `0.0.0.0:6081`; the last explain line does **not** contain `ignored by whitelist`.

- [ ] **Step 2: Back up the CrowdSec data volume**

v1.7+ migrates the database schema, and there is no downgrade path without this backup.

```bash
ssh rpi5 'mkdir -p "$HOME/backups" && docker run --rm -v homelab-crowdsec-data:/data:ro -v "$HOME/backups":/backup alpine tar czf /backup/crowdsec-data-v1.6.3.tar.gz -C /data . && ls -l "$HOME/backups/crowdsec-data-v1.6.3.tar.gz"'
```

Expected: a non-empty `crowdsec-data-v1.6.3.tar.gz`.

- [ ] **Step 3: Create `modules/crowdsec/acquis.yaml`**

```yaml
source: journalctl
journalctl_filter:
  - "_SYSTEMD_UNIT=ssh.service"
labels:
  type: syslog
---
source: journalctl
journalctl_filter:
  - "_TRANSPORT=kernel"
labels:
  type: syslog
```

- [ ] **Step 4: Update `modules/crowdsec/variables.tf`**

Replace the `crowdsec_version` variable with:

```hcl
variable "crowdsec_version" {
  description = "CrowdSec Agent image tag (a -debian variant: journald acquisition needs journalctl)"
  type        = string
  default     = "v1.8.1-debian"
}
```

Replace the `whitelist_cidrs` variable with:

```hcl
variable "whitelist_cidrs" {
  description = "CIDRs never banned by local detections, on top of the built-in crowdsecurity/whitelists (RFC1918, loopback)"
  type        = list(string)
  default     = ["100.64.0.0/10", "fd7a:115c:a1e0::/48"]
}
```

Delete the whole `log_paths` variable block.

- [ ] **Step 5: Update the root default in `variables.tf:487-491`**

```hcl
variable "crowdsec_version" {
  description = "CrowdSec Agent Docker image tag (a -debian variant: journald acquisition needs journalctl)"
  type        = string
  default     = "v1.8.1-debian"
}
```

- [ ] **Step 6: Update the container in `modules/crowdsec/main.tf`**

Replace everything from the first `ports {` block through the end of the `dynamic "volumes"` block (lines 36–60) with:

```hcl
  ports {
    internal = 6060
    external = 6060
    protocol = "tcp"
  }
  ports {
    internal = 8080
    external = 6081
    ip       = "127.0.0.1"
    protocol = "tcp"
  }

  env = [
    "TZ=${var.timezone}",
    "COLLECTIONS=crowdsecurity/linux crowdsecurity/sshd crowdsecurity/iptables crowdsecurity/nginx",
    "CUSTOM_HOSTNAME=${var.project_name}-crowdsec",
  ]

  upload {
    file    = "/etc/crowdsec/acquis.yaml"
    content = file("${path.module}/acquis.yaml")
  }

  upload {
    file = "/etc/crowdsec/parsers/s02-enrich/homelab-whitelists.yaml"
    content = yamlencode({
      name        = "homelab/whitelists"
      description = "Homelab trusted networks"
      whitelist = {
        reason = "homelab trusted network"
        cidr   = var.whitelist_cidrs
      }
    })
  }

  volumes {
    host_path      = "/var/log/journal"
    container_path = "/var/log/journal"
    read_only      = true
  }

  volumes {
    host_path      = "/etc/machine-id"
    container_path = "/etc/machine-id"
    read_only      = true
  }
```

The `volumes` block for `crowdsec_data` that follows stays unchanged. The image entrypoint copies defaults with `rsync --ignore-existing`, so the uploaded `acquis.yaml` is not overwritten.

- [ ] **Step 7: Format and validate**

```bash
terraform fmt modules/crowdsec variables.tf
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 8: Targeted plan**

```bash
terraform plan -target=module.crowdsec -out=/tmp/crowdsec.tfplan
```

**Expected plan:** `module.crowdsec.docker_image.crowdsec` replaced; `module.crowdsec.docker_container.crowdsec` replaced (image, ports, upload, volumes). `docker_network.crowdsec`, `docker_volume.crowdsec_data`, and `null_resource.crowdsec_bouncer` unchanged. `Plan: 2 to add, 0 to change, 2 to destroy.`

- [ ] **Step 9: Apply**

```bash
terraform apply /tmp/crowdsec.tfplan
```

- [ ] **Step 10: Passing probes** (allow ~2 minutes for hub installs and the health check)

```bash
ssh rpi5 'docker ps --filter name=homelab-crowdsec --format "{{.Status}}"; docker exec homelab-crowdsec cscli version 2>&1 | head -1'
```

Expected: `Up … (healthy)`; `version: v1.8.1…`.

```bash
ssh rpi5 true
ssh rpi5 'docker exec homelab-crowdsec cscli metrics show acquisition'
```

Expected: two rows whose Source starts with `journalctl:` (one per filter), each with `Lines read` > 0.

```bash
ssh rpi5 'docker exec homelab-crowdsec cscli explain --type syslog --log "Sep 11 12:00:00 raspberrypi-5 sshd[4242]: Invalid user admin from 100.100.1.1 port 51234"' | tail -1
ssh rpi5 'docker exec homelab-crowdsec cscli explain --type syslog --log "Sep 11 12:00:00 raspberrypi-5 sshd[4242]: Invalid user admin from 203.0.113.7 port 51234"' | tail -1
```

Expected: the first ends with `ignored by whitelist (homelab trusted network) 🟢`; the second ends with `parser success 🟢` and no whitelist.

```bash
ssh rpi5 'ss -tlnH | grep -E ":(6060|6081) "; docker exec homelab-crowdsec cscli bouncers list'
```

Expected: `127.0.0.1:6081` and no `0.0.0.0:6081`; `0.0.0.0:6060` still present; `iptables-bouncer` Valid ✔️ with `Last API pull` within the last minute.

```bash
PI_IP=$(ssh -G rpi5 | awk '/^hostname /{print $2}')
curl -sG "http://$PI_IP:30090/api/v1/query" --data-urlencode 'query=cs_journalctlsource_hits_total' | jq '.data.result | length'
```

Expected: `2` or more within a minute.

- [ ] **Step 11: Roll back only if Step 10 fails and cannot be fixed forward**

```bash
ssh rpi5 'docker stop homelab-crowdsec && docker run --rm -v homelab-crowdsec-data:/data -v "$HOME/backups":/backup alpine sh -c "rm -rf /data/* && tar xzf /backup/crowdsec-data-v1.6.3.tar.gz -C /data"'
git restore --source=origin/main -- modules/crowdsec variables.tf
rm -f modules/crowdsec/acquis.yaml
terraform apply -target=module.crowdsec
```

- [ ] **Step 12: Commit**

```bash
git add modules/crowdsec variables.tf
git commit -m "fix(crowdsec): read SSH and firewall logs from journald" \
  -m "The Pi runs journald only, with no rsyslog, so the bind-mounted /var/log/auth.log was an empty directory Docker had created, and the agent read zero lines. Switch to the -debian image, which ships journalctl, and acquire ssh.service and kernel (UFW) entries from the host journal. Tailnet ranges join the whitelist, and LAPI binds to loopback, where the native bouncer already connects." \
  -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Alert on failed systemd units and a blind CrowdSec

**Files:**
- Modify: `modules/prometheus-stack/main.tf:506-520` (node exporter)
- Modify: `modules/prometheus-stack/main.tf:666-678` (homelab rules)

**Interfaces:**
- Consumes: `cs_journalctlsource_hits_total` (Task 2); a working kubeconfig (Task 1)
- Produces: alerts `SystemdUnitFailed` and `CrowdSecAcquisitionStalled`. Task 4 uses `SystemdUnitFailed` as its passing probe.

- [ ] **Step 1: Record the failing probe**

```bash
PI_IP=$(ssh -G rpi5 | awk '/^hostname /{print $2}')
curl -sG "http://$PI_IP:30090/api/v1/query" --data-urlencode 'query=node_systemd_unit_state' | jq '.data.result | length'
```

Expected: `0`.

- [ ] **Step 2: Add the systemd collector**

Directly after the closing `}` of the `nodeExporter = { … }` block (line 520), at the same indentation, insert:

```hcl

      # extraArgs replaces the subchart's default list, so its two filesystem
      # excludes are repeated verbatim.
      "prometheus-node-exporter" = {
        extraArgs = [
          "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|run/containerd/.+|var/lib/docker/.+|var/lib/kubelet/.+)($|/)",
          "--collector.filesystem.fs-types-exclude=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs|erofs)$",
          "--collector.systemd",
          "--collector.systemd.unit-include=.+\\.service",
        ]
        extraHostVolumeMounts = [
          {
            name      = "dbus"
            hostPath  = "/var/run/dbus/system_bus_socket"
            mountPath = "/var/run/dbus/system_bus_socket"
            type      = "Socket"
            readOnly  = true
          }
        ]
      }
```

- [ ] **Step 3: Add the two rules**

In `homelab-rules`, replace:

```hcl
                  annotations = {
                    summary     = "Homelab service is down"
                    description = "Homelab service {{ $labels.job }} is not responding"
                  }
                }
              ]
```

with:

```hcl
                  annotations = {
                    summary     = "Homelab service is down"
                    description = "Homelab service {{ $labels.job }} is not responding"
                  }
                },
                {
                  alert = "SystemdUnitFailed"
                  expr  = "node_systemd_unit_state{state=\"failed\"} == 1"
                  for   = "15m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary     = "systemd unit {{ $labels.name }} failed"
                    description = "{{ $labels.name }} on {{ $labels.instance }} has been in the failed state for 15 minutes"
                  }
                },
                {
                  alert = "CrowdSecAcquisitionStalled"
                  expr  = "sum(rate(cs_journalctlsource_hits_total[30m])) == 0 or absent(cs_journalctlsource_hits_total)"
                  for   = "30m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary     = "CrowdSec is reading no logs"
                    description = "No journald lines reached CrowdSec for 30 minutes; local intrusion detection is blind"
                  }
                }
              ]
```

- [ ] **Step 4: Format and validate**

```bash
terraform fmt modules/prometheus-stack
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 5: Targeted plan** (open the SSH forward first if the session is gated)

```bash
terraform plan -target='module.prometheus_stack[0].helm_release.prometheus_stack' \
  -var "k8s_config_path=$K3S_KC" -out=/tmp/prom.tfplan
```

**Expected plan:** `module.prometheus_stack[0].helm_release.prometheus_stack` updated in place (values only). `Plan: 0 to add, 1 to change, 0 to destroy.` The module-level `depends_on` pulls `module.k3s_cluster` into the graph; if any of its resources show changes, stop.

- [ ] **Step 6: Apply**

```bash
terraform apply /tmp/prom.tfplan
```

Tear the forward down afterwards.

- [ ] **Step 7: Passing probes** (node-exporter rolls in ~1 minute; rules load in ~1 minute)

```bash
PI_IP=$(ssh -G rpi5 | awk '/^hostname /{print $2}')
curl -sG "http://$PI_IP:30090/api/v1/query" --data-urlencode 'query=node_systemd_unit_state{name="ssh.service",state="active"}' | jq -r '.data.result[0].value[1]'
curl -s "http://$PI_IP:30090/api/v1/rules" | jq -r '.data.groups[].rules[].name' | grep -E '^(SystemdUnitFailed|CrowdSecAcquisitionStalled)$'
curl -sG "http://$PI_IP:30090/api/v1/query" --data-urlencode 'query=node_systemd_unit_state{state="failed"} == 1' | jq -r '.data.result[].metric.name'
```

Expected: `1`; both rule names; `fail2ban.service` — the red state that Task 4 turns green.

If the first query returns `null`, run `ssh rpi5 'sudo k3s kubectl -n monitoring logs ds/prometheus-prometheus-node-exporter | grep -i systemd'` to check for a D-Bus connection error before changing anything.

- [ ] **Step 8: Commit**

```bash
git add modules/prometheus-stack/main.tf
git commit -m "feat(monitoring): alert on failed systemd units and a blind CrowdSec" \
  -m "fail2ban crashed on every boot for months without an alert because node-exporter had no systemd collector. The second rule catches CrowdSec acquisition going quiet, which is how its broken log paths went unnoticed." \
  -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Remove fail2ban and the stray auth.log directory

**Files:**
- Modify: `ansible/playbooks/system-hardening.yml:8`, `:22`, `:103-117`, `:188-192`
- Modify: `README.md:10`, `docs/deployment-guide.md:24`, `GEMINI.md:9`, `ansible/README.md:39`, `:75`, `:139`

**Interfaces:**
- Consumes: Task 2 (no bind mount on `/var/log/auth.log`); Task 3 (`SystemdUnitFailed` probe)
- Produces: no failed systemd units on the Pi

- [ ] **Step 1: Check the precondition and record the failing probe**

```bash
ssh rpi5 'docker inspect homelab-crowdsec --format "{{range .Mounts}}{{.Source}} {{end}}"'
ssh rpi5 'systemctl is-failed fail2ban; stat -c %F /var/log/auth.log'
```

Expected: the mount list does **not** contain `/var/log/auth.log` (if it does, stop — Task 2 is not applied); then `failed` and `directory`.

- [ ] **Step 2: Remove the fail2ban variable and package**

In `ansible/playbooks/system-hardening.yml`, delete the line `    fail2ban_enabled: true` and the line `          - fail2ban` from the `Install security packages` list.

- [ ] **Step 3: Replace the fail2ban configuration task**

Replace lines 103–117 (from `    # Fail2Ban Configuration` through `      when: fail2ban_enabled`) with:

```yaml
    # Intrusion prevention: CrowdSec (Terraform module crowdsec) reading journald
    - name: Remove fail2ban
      apt:
        name: fail2ban
        state: absent
        purge: yes
      tags: [intrusion-prevention]

    - name: Remove the fail2ban jail override
      file:
        path: /etc/fail2ban/jail.local
        state: absent
      tags: [intrusion-prevention]

    - name: Clear fail2ban's failed unit state
      command: systemctl reset-failed fail2ban.service
      register: fail2ban_reset
      changed_when: fail2ban_reset.rc == 0
      failed_when: false
      tags: [intrusion-prevention]

    - name: Check for a stray /var/log/auth.log
      stat:
        path: /var/log/auth.log
      register: auth_log
      tags: [intrusion-prevention]

    - name: Remove the /var/log/auth.log directory left by a Docker bind mount
      file:
        path: /var/log/auth.log
        state: absent
      when: auth_log.stat.isdir | default(false)
      tags: [intrusion-prevention]
```

- [ ] **Step 4: Remove the handler**

Delete the last handler (lines 188–192):

```yaml
    - name: restart fail2ban
      systemd:
        name: fail2ban
        state: restarted
        enabled: yes
```

- [ ] **Step 5: Syntax check and dry run**

```bash
cd ansible
ansible-playbook playbooks/system-hardening.yml --syntax-check
ansible-playbook playbooks/system-hardening.yml --tags intrusion-prevention --check --diff
cd ..
```

Expected: syntax OK; only the five tagged tasks run; `Remove fail2ban` reports changed; `failed=0`.

- [ ] **Step 6: Apply**

```bash
cd ansible && ansible-playbook playbooks/system-hardening.yml --tags intrusion-prevention; cd ..
```

Expected: `failed=0`.

- [ ] **Step 7: Passing probes**

```bash
ssh rpi5 'systemctl --failed --no-legend; dpkg -l fail2ban 2>/dev/null | tail -1; ls -ld /var/log/auth.log /etc/fail2ban 2>&1'
PI_IP=$(ssh -G rpi5 | awk '/^hostname /{print $2}')
sleep 60
curl -sG "http://$PI_IP:30090/api/v1/query" --data-urlencode 'query=node_systemd_unit_state{state="failed"} == 1' | jq '.data.result | length'
```

Expected: no failed units listed; fail2ban absent or in state `un`/`pn`; both paths `No such file or directory`; `0`.

- [ ] **Step 8: Update the docs**

| File:line | Replace | With |
|---|---|---|
| `README.md:10` | `- **System hardening** with UFW firewall and fail2ban` | `- **System hardening** with UFW firewall and CrowdSec intrusion prevention` |
| `docs/deployment-guide.md:24` | `- **System hardening** with UFW firewall and fail2ban` | `- **System hardening** with UFW firewall and CrowdSec intrusion prevention` |
| `GEMINI.md:9` | `system hardening with UFW and fail2ban, and kubeconfig management.` | `system hardening with UFW and SSH lockdown, and kubeconfig management.` |
| `ansible/README.md:39` | `# 2. Security hardening (SSH, firewall, fail2ban)` | `# 2. Security hardening (SSH, firewall)` |
| `ansible/README.md:75` | `- Fail2Ban intrusion prevention` | `- Removes fail2ban (intrusion prevention is CrowdSec, deployed by Terraform)` |
| `ansible/README.md:139` | `- ✅ Intrusion detection (Fail2Ban)` | `- ✅ Intrusion detection (CrowdSec, Terraform layer)` |

Verify:

```bash
git grep -n -i fail2ban -- ':!docs/superpowers'
```

Expected: matches only in `ansible/playbooks/system-hardening.yml` (the removal tasks) and `ansible/README.md:75`.

- [ ] **Step 9: Commit**

```bash
git add ansible/playbooks/system-hardening.yml README.md docs/deployment-guide.md GEMINI.md ansible/README.md
git commit -m "fix(ansible): remove fail2ban; CrowdSec owns SSH intrusion prevention" \
  -m "fail2ban watched /var/log/auth.log, which never existed on this journald-only Pi, so it exited on every boot. CrowdSec now reads journald and already carries the SSH scenarios plus the community blocklist, so a second engine would only duplicate bans. The playbook also removes the empty directory Docker left at /var/log/auth.log." \
  -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Remove the gravity CronJob and the pgAdmin probe

**Files:**
- Delete: `modules/k3s-cluster/gravity-cronjob.tf`
- Modify: `modules/k3s-cluster/variables.tf:50-67`
- Modify: `main.tf:186-188`
- Modify: `variables.tf:480-485` (description) and the `blackbox_http_targets` default
- Modify: `modules/prometheus-stack/variables.tf` (`blackbox_http_targets` default)

**Interfaces:**
- Consumes: a working kubeconfig (Task 1)
- Produces: no `KubeJobFailed` or `BlackboxProbeFailed` alerts for these two leftovers

- [ ] **Step 1: Record the failing probe**

```bash
PI_IP=$(ssh -G rpi5 | awk '/^hostname /{print $2}')
curl -sG "http://$PI_IP:30090/api/v1/query" --data-urlencode 'query=ALERTS{alertname=~"KubeJobFailed|BlackboxProbeFailed",alertstate="firing"}' | jq -r '.data.result[].metric | .job_name // .instance'
```

Expected: three `pihole-gravity-update-…` job names and `https://pgadmin.rainforest.tools`.

- [ ] **Step 2: Delete the CronJob module file**

```bash
git rm modules/k3s-cluster/gravity-cronjob.tf
```

- [ ] **Step 3: Remove the module variables**

Delete this block from `modules/k3s-cluster/variables.tf` (lines 50–67), including the blank line before it:

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

variable "pi_ssh_private_key" {
  description = "SSH private key content for Pi-hole gravity CronJob (set in terraform.tfvars)"
  type        = string
  sensitive   = true
  default     = ""
}
```

- [ ] **Step 4: Stop passing them from `main.tf`**

Delete these three lines from `module "k3s_cluster"`:

```hcl
  pi_hostname             = var.raspberry_pi_hostname
  pi_user                 = var.raspberry_pi_user
  pi_ssh_private_key      = var.pi_ssh_private_key
```

The root `pi_ssh_private_key` variable stays: `null_resource.alloy_pi_config` uses it.

- [ ] **Step 5: Correct the root variable's description (`variables.tf:481`)**

Replace:

```hcl
  description = "SSH private key content for Pi-hole gravity CronJob (store in terraform.tfvars only)"
```

with:

```hcl
  description = "SSH private key content for the Alloy config provisioner (store in terraform.tfvars only)"
```

- [ ] **Step 6: Drop the pgAdmin target**

Delete the line `    "https://pgadmin.rainforest.tools",` from the `blackbox_http_targets` default in both `variables.tf` and `modules/prometheus-stack/variables.tf`.

- [ ] **Step 7: Format and validate**

```bash
terraform fmt main.tf variables.tf modules/k3s-cluster modules/prometheus-stack
terraform validate
git grep -n -E 'pgadmin|pi_ssh_key|pihole_gravity_update' -- '*.tf'
```

Expected: `Success!`; the grep prints nothing. (`gravity.db` comments in other modules are unrelated, which is why the pattern is specific.)

- [ ] **Step 8: Targeted plan** (open the SSH forward first if the session is gated)

```bash
terraform plan \
  -target='module.k3s_cluster[0].kubernetes_cron_job_v1.pihole_gravity_update' \
  -target='module.k3s_cluster[0].kubernetes_secret.pi_ssh_key' \
  -target='module.prometheus_stack[0].kubernetes_secret.prometheus_additional_scrape_configs' \
  -var "k8s_config_path=$K3S_KC" -out=/tmp/cleanup.tfplan
```

**Expected plan:** `kubernetes_cron_job_v1.pihole_gravity_update` destroyed; `kubernetes_secret.pi_ssh_key` destroyed; `kubernetes_secret.prometheus_additional_scrape_configs` updated in place (pgAdmin removed from `prometheus-additional.yaml`). `Plan: 0 to add, 1 to change, 2 to destroy.`

- [ ] **Step 9: Apply**

```bash
terraform apply /tmp/cleanup.tfplan
```

- [ ] **Step 10: Passing probes** (the operator reloads scrape configs within ~3 minutes)

```bash
kubectl --kubeconfig "$K3S_KC" get cronjob,jobs -n default 2>&1 | grep -c pihole-gravity
```

Expected: `0`. If failed Jobs remain, delete them:

```bash
kubectl --kubeconfig "$K3S_KC" get jobs -n default -o name | grep pihole-gravity-update | while read -r j; do kubectl --kubeconfig "$K3S_KC" delete -n default "$j"; done
```

```bash
sleep 300
curl -sG "http://$PI_IP:30090/api/v1/query" --data-urlencode 'query=ALERTS{alertname=~"KubeJobFailed|BlackboxProbeFailed",alertstate="firing"}' | jq '.data.result | length'
```

Expected: `0`. Tear the forward down.

- [ ] **Step 11: Commit**

```bash
git add -A modules/k3s-cluster main.tf variables.tf modules/prometheus-stack/variables.tf
git commit -m "chore(k3s): drop the redundant gravity CronJob and the pgAdmin probe" \
  -m "The CronJob's SSH key secret was empty, so it failed every week, while Pi-hole's own in-container cron already runs updateGravity on Sundays and succeeds. pgAdmin was removed from rainforest-homelab and its DNS record is gone, so its probe only produced a false BlackboxProbeFailed." \
  -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Open the PR

**Files:** none

**Interfaces:**
- Consumes: Tasks 0–5 committed and verified
- Produces: a PR against `main`

- [ ] **Step 1: Final checks**

```bash
terraform validate
git log --oneline origin/main..HEAD
git diff origin/main..HEAD | grep -E '^\+.*192\.168\.[0-9]+\.[0-9]+' || echo "no LAN addresses added"
```

Expected: `Success!`; six commits; `no LAN addresses added`.

- [ ] **Step 2: Push and open the PR — only after the user approves**

```bash
git push -u origin fix/intrusion-detection-journald
gh pr create --base main --title "fix: restore SSH intrusion detection via journald" --body-file - <<'EOF'
## Summary
- CrowdSec reads `ssh.service` and kernel (UFW) logs from journald on the `-debian` image; tailnet ranges are whitelisted; LAPI binds to loopback.
- fail2ban is removed (it crashed on every boot watching a non-existent `/var/log/auth.log`), along with the empty directory Docker left at that path.
- node-exporter gains the systemd collector; new alerts `SystemdUnitFailed` and `CrowdSecAcquisitionStalled`.
- The redundant, always-failing `pihole-gravity-update` CronJob and the stale pgAdmin probe are removed.
- The kubeconfig fetch tasks are tagged `kubeconfig` and use the Pi's LAN address.

## Root cause
Raspberry Pi OS bookworm ships journald only. Both fail2ban and the CrowdSec module assumed `/var/log/auth.log` exists, so local SSH detection had been blind; only the CAPI community blocklist was protecting the host.

## Verification
- CrowdSec acquisition shows two `journalctl:` sources with lines read > 0.
- `cscli explain`: tailnet source whitelisted, public source parsed.
- `iptables-bouncer` still pulling from LAPI on `127.0.0.1:6081`.
- `SystemdUnitFailed` fired for fail2ban, then cleared after removal.
- No `KubeJobFailed` / `BlackboxProbeFailed` alerts remain.

All applies were targeted, because PR #18 is applied live but not merged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
```

---

## Out of scope — follow-up plan

- UFW: restrict the "Anywhere" rules to the LAN and `tailscale0`, including the IPv6 rules. The API certificate records past public IPv6 addresses (`2407:…`), so global IPv6 has been delivered to the Pi before.
- Docker-published ports bypass UFW: add `DOCKER-USER` chain rules.
- Move the bouncer install from Terraform `null_resource` (`curl | sudo bash`) into Ansible, with the API key in ansible-vault, and rotate that key.
- Bring the Tailscale install under Ansible (only `tailscale-remove.yml` exists).
- Cap the journal size (`SystemMaxUse`); it is 3.7 GB on the SD card.
- Fix the AirPlay UFW rules, which allow `192.168.176.0/24` instead of the LAN, and codify the manually added rules.
- rainforest-homelab: update the macOS container-LAN section in `CLAUDE.md` (fixed on build `26A428`).
