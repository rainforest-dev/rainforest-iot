# Homelab Security, Monitoring & Observability — Design Spec

**Date:** 2026-05-21  
**Repos:** `rainforest-iot` (primary), `rainforest-homelab` (Mac Mini additions)  
**Status:** Approved — ready for implementation planning

---

## 目標

在現有 homelab 基礎上，加入網路安全過濾、入侵偵測、流量分析、全服務可觀測性，以及 AI 查詢整合。同時全面審查所有既有服務的版本固定和可靠性標準。

**核心原則：**
- 路由器（SCR 50AXE）所有 UTM/Content Filter 功能關閉 → 速度最大化
- 安全過濾在 homelab 層處理，不依賴路由器
- RPi 不加入 Tailscale，Mac Mini 作為 NAS 橋接
- Grafana 作為單一監控介面（single pane of glass）
- AI 整合層 model-agnostic，不綁定特定 LLM 前端

---

## 整體架構

```
╔══════════════════════════════════════════════════════════╗
║  RPi 5 — 192.168.0.134                                   ║
║                                                          ║
║  [Docker]                    [K3s]                       ║
║  Pi-hole + blocklists        Prometheus ◄─────────────┐  ║
║  CrowdSec Agent + Bouncer    Grafana                  │  ║
║  Ntopng (traffic DPI)        Loki                     │  ║
║  Blackbox Exporter           AlertManager             │  ║
║  Pi-hole exporter            Velero                   │  ║
║                                    │ alert            │  ║
╚════════════════════════════════════╪══════════════════╪══╝
                                     │                  │
╔═════════════════════════════════════════════════════════╗
║  Mac Mini — 192.168.0.126                               ║
║                                                         ║
║  Grafana Alloy ──────── metrics + logs ────────────────►╝
║  Grafana MCP server ─── Claude Code 查詢 Grafana API    ║
║                                                         ║
║  MinIO (已有) ◄── Velero backup ── RPi K3s PVCs         ║
║  Synology Drive (已有) ──► NAS via Tailscale            ║
║                                                         ║
║  [移除] Flowise                                         ║
╚═════════════════════════════════════════════════════════╝
```

**DNS 設定（Nebula 已完成）：**
- Primary DNS: `192.168.0.134` (Pi-hole)
- Fallback DNS: `1.1.1.1` (Cloudflare — Pi 離線時自動接管)

---

## Phase 1：基礎安全（rainforest-iot）

### 1.1 Pi-hole 威脅名單增強

**修改**：`modules/pi-hole/main.tf`

新增 blocklists（透過 Pi-hole API 或環境變數注入）：
- Hagezi Pro: `https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt`
- OISD Big: `https://big.oisd.nl/`
- OpenPhish: `https://openphish.com/feed.txt`

**新增**：`modules/pi-hole/` 加入 Pi-hole Prometheus exporter sidecar  
- Image: `ekofr/pihole-exporter:<version>`  
- Port: `9617`  
- Prometheus scrape target 加入 `monitoring-integrations` module

**新增**：K8s CronJob — Pi-hole gravity update  
- 排程: 每週日 `03:00`  
- 執行: `pihole -g`（透過 docker exec）

### 1.2 版本固定（全面）

**rainforest-iot** — 將以下全部從 `:latest` 改為固定版號：

| 服務 | 舊 tag | 新 tag（實作時查最新 stable release） |
|---|---|---|
| Pi-hole | `pihole/pihole:latest` | `pihole/pihole:<X.Y.Z>` |
| Homebridge | `homebridge/homebridge:latest` | `homebridge/homebridge:<X.Y.Z>` |
| Homepage | `ghcr.io/gethomepage/homepage:latest` | `ghcr.io/gethomepage/homepage:vX.Y.Z` |
| OpenSpeedtest | `openspeedtest/latest` | `openspeedtest/openspeedtest:vX.Y.Z` |

**rainforest-homelab** — 修正高風險 tag：

| 服務 | 舊 tag | 新 tag |
|---|---|---|
| Open WebUI | `ghcr.io/open-webui/open-webui:main` | `ghcr.io/open-webui/open-webui:vX.Y.Z` |
| cloudflared | `cloudflare/cloudflared:latest` | `cloudflare/cloudflared:X.Y.Z` |

**管理方式**：所有版號集中在各 repo 的 `terraform.tfvars`，module 內用 `var.xxx_version` 引用。

### 1.3 Secrets 管理修正

**問題**：`grafana_admin_password = "admin123"` 明文弱密碼存在 `terraform.tfvars`。

**修正**：
1. 在 `variables.tf` 加上 `sensitive = true`
2. `terraform.tfvars` 換成強密碼（16+ 字元、隨機）
3. 確認兩個 repo 的 `.gitignore` 都有排除 `terraform.tfvars`（含 `*.tfvars`）
4. 若 `terraform.tfvars` 已進 git history，用 `git filter-repo` 清除歷史（**破壞性操作，執行前需所有協作者同步，並備份 repo**）

---

## Phase 2：新安全元件（rainforest-iot）

### 2.1 CrowdSec IDS

**新建**：`modules/crowdsec/`

**元件：**
- `crowdsecurity/crowdsec:<version>` — Agent + LAPI
- `crowdsecurity/firewall-bouncer-iptables:<version>` — 封鎖執行

**設定：**
```hcl
# 監控 log 來源
acquis_config = [
  { filepath = "/var/log/auth.sso", labels = { type = "syslog" } },
  { filepath = "/var/log/pihole.log", labels = { type = "pihole" } },
]

# LAN 永遠不封鎖（whitelist）
whitelist_cidrs = ["192.168.0.0/24", "127.0.0.1/32"]
```

**Prometheus metrics**：CrowdSec 內建 exporter，port `6060`，加入 Prometheus scrape。

**Systemd timer**：每天 04:00 執行 `cscli hub update && cscli hub upgrade`。

**資源限制**：
- CrowdSec agent: 256MB RAM
- Firewall bouncer: 64MB RAM

### 2.2 Ntopng 流量分析

**新建**：`modules/ntopng/`

**Image**：`ntop/ntopng:stable`

**關鍵設定**：
```hcl
network_mode = "host"  # 必要：存取 eth0 看 LAN 流量
```

**資源限制**：512MB RAM

**Prometheus 整合**：Ntopng 支援 InfluxDB line protocol export，透過 Prometheus remote write 橋接，或用社群 exporter。

**Web UI**：port `3000`，加入 Teleport app access（不公開）。

### 2.3 Blackbox Exporter

**修改**：`modules/prometheus-stack/`，在 Helm values 加入 Blackbox Exporter。

**監控端點：**

| 目標 | 類型 | 警報條件 |
|---|---|---|
| `https://homeassistant.rainforest.tools` | HTTPS | 非 200 或回應 > 5s |
| `https://n8n.rainforest.tools` | HTTPS | SSL 到期 < 14 天 |
| `https://open-webui.rainforest.tools` | HTTPS | 掉線 |
| `http://raspberrypi-5.local:30080` | HTTP | Grafana 掉線 |
| `http://raspberrypi-5.local:8080` | HTTP | Pi-hole 掉線 |
| `192.168.0.1` | ICMP | 路由器掉線 |
| `1.1.1.1` | ICMP | ISP 問題 |

**AlertManager 規則**：掉線持續 2 分鐘才觸發（避免短暫抖動）。

---

## Phase 3：可觀測性橋接（rainforest-homelab）

### 3.1 Grafana Alloy

**新建**：`modules/grafana-alloy/`，Docker container on Mac Mini。

**Image**：`grafana/alloy:<version>`

**功能**（單一 agent 取代多工具）：
- 系統 metrics → RPi Prometheus（取代獨立 node_exporter）
- Docker 容器 metrics → RPi Prometheus（取代獨立 cAdvisor）
- 容器 logs → RPi Loki（取代 Promtail）

**設定檔**：`alloy.river`（存入 git，掛載進容器）

**資源限制**：128MB RAM，Cloudflare Tunnel 不暴露（僅 LAN 推送到 RPi）。

### 3.2 Grafana MCP Server

**新建**：`modules/grafana-mcp/`，Docker container on Mac Mini。

**Image**：`grafana/mcp-grafana:<version>`

**暴露**：加入 `locals.tf` services map：
```hcl
"grafana-mcp" = {
  hostname    = "grafana-mcp"
  service_url = "http://host.docker.internal:8765"
  enable_auth = true
  type        = "docker"
}
```

**Claude Code 設定**（deploy 後加入 `.mcp.json`）：
```json
{
  "mcpServers": {
    "grafana": {
      "type": "sse",
      "url": "https://grafana-mcp.rainforest.tools/sse"
    }
  }
}
```

**資源限制**：64MB RAM。

### 3.3 移除 Flowise

**操作**：
1. 確認 Flowise PostgreSQL database 無需保留資料
2. `main.tf` 移除 `module "flowise"` block
3. 移除相關 Helm release、PVC、Service
4. `terraform plan` 確認 diff 合理後 apply

**釋放資源**：~200–400MB RAM on Mac Mini（讓本地 LLM 跑得更順）。

### 3.4 MinIO → Synology Drive 橋接

**修改**：在 Mac Mini K8s 建立一個 `hostPath` PersistentVolume，掛載點指向 `~/SynologyDrive/homelab-velero/`，MinIO 的 PVC 綁定到這個 PV。

這樣 Velero 把 RPi K3s PVC 資料透過 S3 API 寫進 Mac Mini MinIO，MinIO 的實際資料落在 `~/SynologyDrive/homelab-velero/`，Synology Drive 被動同步到 NAS，Mac Mini 無額外計算負擔。

---

## Phase 4：持久化 + 排程（跨兩個 repo）

### 4.1 Grafana Dashboards as Code

**操作**：`modules/prometheus-stack/dashboards/` 下的 dashboard JSON 存入 git。

包含：
- Homelab overview dashboard
- Pi-hole statistics
- CrowdSec events
- Ntopng traffic
- Blackbox Exporter uptime
- Mac Mini vs RPi 資源對比

RPi 重建後 `terraform apply` 自動恢復所有 dashboard。

### 4.2 Velero K3s Backup

**新建**：`modules/velero/`（rainforest-iot）

**設定**：
- Backend: Mac Mini MinIO（LAN 直連，不過 Tailscale）
- 排程: 每天 02:00
- 保留: 7 天

### 4.3 RPi → Mac Mini rsync

**Ansible playbook**（`ansible/playbooks/setup-backup.yml`）：

在 RPi 建立 systemd timer，每 6 小時執行：
```bash
rsync -az /var/lib/rancher/k3s/storage/ \
  rainforest@192.168.0.126:~/homelab-backups/rpi-k3s/
```

### 4.4 K3s 資源管控啟用

```hcl
# terraform.tfvars
k8s_enable_network_policies = true  # 從 false 改為 true
k8s_enable_resource_quotas  = true  # 從 false 改為 true
```

---

## 排程任務總覽

| 任務 | 工具 | 排程 |
|---|---|---|
| Pi-hole gravity update | K8s CronJob | 每週日 03:00 |
| CrowdSec hub update | systemd timer | 每天 04:00 |
| RPi → Mac Mini rsync | systemd timer | 每 6 小時 |
| Velero K3s snapshot | K8s CronJob | 每天 02:00 |
| 週報生成 | n8n workflow | 每週一 08:00 |
| CrowdSec 事件記錄 | n8n webhook | 即時觸發 |
| 頻寬異常警報 | AlertManager rule | 即時觸發 |

---

## 可靠性標準（全服務套用）

### 容器標準
```hcl
restart = "unless-stopped"

healthcheck {
  interval     = "30s"
  timeout      = "10s"
  retries      = 3
  start_period = "60s"
}
```

### 資源限制（新元件）

| 服務 | Memory 上限 |
|---|---|
| CrowdSec agent | 256MB |
| CrowdSec bouncer | 64MB |
| Ntopng | 512MB |
| Blackbox Exporter | 64MB |
| Pi-hole exporter | 32MB |
| Grafana Alloy | 128MB |
| Grafana MCP | 64MB |

---

## AI 整合架構

```
Claude Code
    ↓ MCP
Grafana MCP ── Prometheus metrics、Loki logs、dashboards

n8n workflows（model-agnostic）
    ├── 週報：查 Grafana API → 任何 LLM API → 通知
    └── 事件：CrowdSec webhook → Obsidian 記錄

未來可延伸：
    Pi-hole MCP（社群，可評估）
    Home Assistant MCP（官方支援）
```

---

## 未來使用情境

1. **自然語言查詢監控** — Claude 直接回答「昨晚有可疑 DNS 查詢嗎？」
2. **AI 週報** — n8n + 本地 LLM 自動生成安全摘要
3. **CrowdSec 事件自動記錄** — 攻擊偵測 → Obsidian 筆記
4. **裝置行為基準線** — 異常流量自動警報
5. **情境感知安全模式** — Home Assistant 離家 → 提高 CrowdSec 警戒
6. **Pi-hole 分時過濾** — n8n 排程切換 blocklist 強度
7. **ISP 品質長期追蹤** — Blackbox Exporter 歷史數據
8. **CrowdSec 社群貢獻** — 參與全球威脅情報共享

---

## 不在此次範圍

- Open WebUI 替代方案評估（另開設計）
- Hermes agent 整合（待 Open WebUI 決策後再規劃）
- n8n workflow 的具體設計（另開設計）
- RPi K3s 升版（另行評估）
