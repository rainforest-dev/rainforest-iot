# Homepage Mac Mini Kubernetes Integration

## Current Status

Homepage (running on Raspberry Pi 5) monitors Mac Mini services using **Docker API** instead of Kubernetes API due to network access limitations.

## Why Not Direct Kubernetes API?

### The Problem
- Mac Mini runs Docker Desktop / OrbStack with Kubernetes enabled
- The Kubernetes API server binds to `127.0.0.1:6443` (localhost only) for security
- Homepage on Pi 5 cannot reach `192.168.0.30:6443` (connection refused)
- This is by design - Docker Desktop doesn't expose K8s API to the network

### Current Workaround
Services running as Kubernetes pods on Mac Mini are monitored via Docker API:
- Docker API is accessible at `192.168.0.30:2375`
- K8s pods show up as Docker containers with names like `/k8s_<app>_<pod>_<namespace>_<uid>_<restart>`
- Homepage can query container status via Docker API

## Solutions for Proper Kubernetes Integration

### Option 1: kubectl proxy (Recommended)
Run `kubectl proxy` on Mac Mini to expose K8s API:

```bash
# On Mac Mini, run as a background service
kubectl proxy --address='0.0.0.0' --port=8001 --accept-hosts='^.*$'
```

Then update Homepage's kubeconfig to use `http://192.168.0.30:8001`

### Option 2: socat Port Forward
Forward the K8s API port:

```bash
# On Mac Mini
socat TCP-LISTEN:6443,fork,reuseaddr TCP:127.0.0.1:6443
```

### Option 3: Configure OrbStack/Docker Desktop
If using OrbStack, you might be able to configure it to bind to network interface (check OrbStack documentation).

### Option 4: SSH Tunnel (Current Alternative)
Homepage could use SSH tunneling, but this requires SSH keys and is complex to set up.

## Current Implementation

### Services with Docker Monitoring
These use full container names (updates required when pods restart):
- Open WebUI: `/k8s_open-webui_open-webui-0_homelab_...`
- Flowise: `/k8s_flowise_homelab-flowise-..._homelab_...`
- n8n: `/k8s_n8n_homelab-n8n-..._homelab_...`
- MinIO: `/k8s_minio_homelab-minio-..._homelab_...`
- pgAdmin: `/k8s_pgadmin4_homelab-pgadmin-..._homelab_...`

### Services with Native Docker
These are standalone Docker containers (not K8s):
- Whisper STT: `homelab-whisper`
- Calibre Web: `homelab-calibre-web`
- Docker MCP Gateway: `homelab-docker-mcp-gateway`

## Recommendations

1. **Short term**: Keep current Docker API monitoring (works, but container names change on pod restart)
2. **Medium term**: Set up `kubectl proxy` on Mac Mini for proper K8s integration
3. **Long term**: Consider running Homepage on Mac Mini alongside the services, or use a unified K8s cluster

## Removed Services

### Loki
- Removed from Homepage dashboard
- Loki has no web UI, only API endpoints
- Access logs via Grafana's Explore view: `http://raspberrypi-5.local:30080/explore`
- The datasource is already configured in Grafana
