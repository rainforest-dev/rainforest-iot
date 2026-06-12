# Homelab Observability & Service Value Design

**Date:** 2026-06-04
**Status:** Approved
**Repos:** rainforest-iot, rainforest-homelab

## Goal

Full observability across all homelab services — both operational health and personal analytics — using the existing Prometheus + Loki + Grafana stack on the Pi, extended by Grafana Alloy agents on each machine.

## Architecture & Data Flow

```
Mac Mini                              Raspberry Pi 5
──────────────────────────────        ──────────────────────────────────
Alloy (Docker container)              Alloy (Docker container)
  ├─ Docker containers:               ├─ Docker containers:
  │   whisper, calibre-web,           │   homeassistant, music-assistant,
  │   docker-mcp, flowise             │   homebridge, pihole
  ├─ Kubernetes pods (via API):       ├─ K3s pods (via API):
  │   open-webui, n8n, minio,         │   prometheus, loki, grafana,
  │   pgadmin, flowise                │   alertmanager, node-exporter
  ├─ node_exporter (Mac host)         ├─ node_exporter (Pi host)
  └─ pushes → Loki + Prometheus       └─ pushes → Loki + Prometheus
                                           (local, already deployed)
                                                ↓
                                           Grafana (K3s, port 30080)
```

- Loki and Prometheus already run on K3s on the Pi — Alloy feeds them from both machines
- Alloy uses `loki.source.kubernetes` for K8s/K3s pod logs (structured, labelled by namespace/pod/container)
- Alloy uses `loki.source.docker` for Docker container logs on both machines
- No changes to existing Prometheus scrape configs, dashboards, or service deployments

## Dashboards

### Operational Health (expand existing)

| Dashboard | Changes |
|-----------|---------|
| Homelab Overview | Expand with K8s pod restart counts, container health |
| Kubernetes Cluster | Exists — no changes needed |
| Network Health (Blackbox) | Exists — no changes needed |

### Personal Analytics (new)

| Dashboard | Key Panels |
|-----------|-----------|
| **AI & Automation** | Open WebUI: active sessions, models used; n8n: executions per workflow, success/fail rate; Flowise: flow runs; Whisper: request count, avg latency |
| **Home & Music** | HA: automations fired, Google Home commands, devices online; Music Assistant: tracks played, active players |
| **Storage & Reading** | MinIO: bucket sizes, request rates; Calibre Web: book downloads, active sessions |

### Security Visibility (expand existing)

| Dashboard | Changes |
|-----------|---------|
| CrowdSec Events | Exists — no changes needed |
| Pi-hole Stats | Exists — no changes needed |
| **HA Login Attempts** | New — failed auth by IP over time (sourced from HA logs in Loki) |
| **Cloudflare Access** | New — Zero Trust auth events per service (sourced from Cloudflare Logpush → Loki, or deferred if Logpush setup is out of scope) |

### Log Explorer

Saved Loki queries per service group — pre-filtered by container/pod label. Allows jumping directly to any service's logs without writing LogQL manually.

## Service Value Map

| Service | Operational signals | Personal analytics |
|---------|--------------------|--------------------|
| Open WebUI | Pod restarts, error logs | Sessions, models used |
| n8n | Pod restarts, error logs | Executions, success/fail rate |
| Whisper STT | Container health, error logs | Request count, avg latency |
| Flowise | Pod restarts, error logs | Flow run count |
| Calibre Web | Container health | Book downloads, sessions |
| MinIO | Pod restarts, storage usage | Bucket sizes, request rates |
| pgAdmin | Pod restarts | (admin tool — health only) |
| Home Assistant | Container health | Automations fired, Google Home commands |
| Music Assistant | Container health | Tracks played, active players |
| Pi-hole | Container health | Block rate, query volume (existing dashboard) |
| CrowdSec | Exists | Banned IPs, alerts (existing dashboard) |
| Homebridge | Container health | (bridge tool — health only) |

## Security Services — What They Protect

| Service | What it does for you |
|---------|---------------------|
| **CrowdSec** | Crowdsourced threat intel — bans IPs attempting brute force, scanning, or known malicious patterns. Blocks at the network level before requests reach your services |
| **Pi-hole** | DNS-level ad/tracker blocking — prevents devices from phoning home to ad networks and blocks known malware domains. Block rate and top blocked domains visible in existing Grafana dashboard |
| **Cloudflare Zero Trust** | Access gateway — every protected service requires email verification before reaching your homelab. Logs all auth attempts per service |
| **Cloudflare Tunnel** | Hides your home IP entirely — no ports open on your router, no direct path to your network from the internet |
| **HA failed auth monitoring** | Visibility into credential-stuffing attempts against Home Assistant (we saw IPs from Taiwan actively attempting logins) |

## Implementation Scope

### rainforest-iot repo
- New module `modules/grafana-alloy-pi/` — Alloy on Pi (Docker + K3s logs + metrics)
- New dashboards in `modules/prometheus-stack/dashboards/`: `ai-automation.json`, `home-music.json`, `storage-reading.json`, `ha-security.json`
- Update `modules/monitoring-integrations/main.tf` — wire new Alloy scrape targets

### rainforest-homelab repo
- Complete `modules/grafana-alloy/` module (stub exists) — Alloy on Mac Mini (Docker + K8s logs + metrics)

## Delivery Order

Each step is independently useful:

1. **Alloy on Mac Mini** → Mac Mini container + K8s pod logs flow into Loki
2. **Alloy on Pi** → Pi Docker + K3s logs flow into Loki
3. **Personal analytics dashboards** → AI, Home, Storage panels in Grafana
4. **Security dashboards** → HA login attempts + Cloudflare access events
