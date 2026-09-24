- "Mac Mini M4 (AI & Automation)":
    - Open WebUI:
        href: https://open-webui.rainforest.tools/
        description: "AI Chat Interface with Claude & OpenAI"
        icon: open-webui.png
        # K8s-managed: container name changes on every pod restart, omitted to avoid stale "not found"
    - n8n:
        href: https://n8n.rainforest.tools/
        description: "Workflow Automation Platform"
        icon: n8n.png
        # K8s-managed: container name changes on every pod restart, omitted to avoid stale "not found"
    - Whisper STT:
        href: https://whisper.rainforest.tools/
        description: "Speech-to-Text API Service"
        icon: mdi-microphone-message
        server: macmini-docker
        container: homelab-whisper
    - ComfyUI:
        href: https://comfyui.rainforest.tools/
        description: "Node-Based Image Generation Workflows"
        icon: comfyui.png
        # Runs natively on the mini via uv, not in Docker — no container to poll
    - Antigravity:
        href: https://agy.rainforest.tools/
        description: "Multi-Model AI CLI (Gemini / Claude / GPT-OSS)"
        icon: mdi-robot
        # Runs natively on the mini — no container to poll

- "Mac Mini M4 (Storage & Files)":
    - MinIO Console:
        href: https://minio.rainforest.tools/
        description: "S3-Compatible Object Storage"
        icon: minio.png
        # K8s-managed: container name changes on every pod restart, omitted to avoid stale "not found"
    - MinIO S3 API:
        href: https://s3.rainforest.tools/
        description: "S3 API Endpoint"
        icon: minio.png
        # K8s-managed: container name changes on every pod restart, omitted to avoid stale "not found"
    - Calibre Web:
        href: https://calibre-web.rainforest.tools/
        description: "Ebook Library & Reader"
        icon: calibre-web.png
        server: macmini-docker
        container: homelab-calibre-web
    - Calibre:
        href: https://calibre.rainforest.tools/
        description: "Calibre Content Server (library backend)"
        icon: calibre.png
        server: macmini-docker
        container: homelab-personal-calibre

- "Mac Mini M4 (Development Tools)":
    - Docker MCP Gateway:
        href: https://docker-mcp.rainforest.tools/
        description: "Claude Code Integration"
        icon: docker.png
        # launchd service on the mini (`docker mcp gateway run`, PORT=3101), not Docker —
        # the old homelab-docker-mcp-gateway container is gone and polling it showed
        # a permanent "not found".
    - Teleport:
        href: https://tp.rainforest.tools/
        description: "Secure SSH & Kubernetes Access"
        icon: teleport.png
        # K8s-managed: container name changes on every pod restart, omitted to avoid stale "not found"
    - Loop Observatory:
        href: https://loop.rainforest.tools/
        description: "Autonomous Task Loop Dashboard"
        icon: mdi-autorenew
        # launchd service on the mini (PORT=3099), not Docker — no container to poll

- "Mac Mini M4 (Personal Dashboards)":
    - Finance Audit:
        href: https://finance.rainforest.tools/
        description: "Credit Card Reconciliation & Rewards Audit"
        icon: mdi-credit-card-check-outline
        server: macmini-docker
        container: homelab-finance-audit
    - RSS Manager:
        href: https://rss.rainforest.tools/
        description: "Feed Subscription Manager"
        icon: mdi-rss
        server: macmini-docker
        container: homelab-rss-manager
    - Bambii Focus:
        href: https://bambii.rainforest.tools/
        description: "Pomodoro Focus Timer"
        icon: mdi-timer-outline
        # Runs natively on the mini — no container to poll

- "Raspberry Pi 5 (IoT Platform)":
    - HomeAssistant:
        href: https://homeassistant.rainforest.tools
        description: "Home Automation"
        icon: home-assistant.png
        server: pi5-docker
        container: homeassistant
    - Music Assistant:
        href: https://music-assistant.rainforest.tools
        description: "Multi-Room Music Player"
        icon: mdi-music
        server: pi5-docker
        container: music-assistant
    - Homebridge:
        href: http://${raspberry_pi_hostname}:8581
        description: "HomeKit Bridge"
        icon: homebridge.png
        server: pi5-docker
        container: homebridge
    - Pi-hole:
        href: http://${raspberry_pi_hostname}:8080/admin
        description: "DNS Ad Blocker"
        icon: pi-hole.png
        server: pi5-docker
        container: pihole
    - OpenSpeedTest:
        href: http://${raspberry_pi_hostname}:3000
        description: "Network Speed Test"
        icon: openspeedtest.png
        server: pi5-docker
        container: openspeedtest

- "Monitoring & Observability (K3s on Pi 5)":
    - Grafana:
        # href is the public Zero Trust route so the link works off the LAN;
        # the widget below must stay on the LAN IP — that call is made by the
        # homepage container itself and would fail against the Access-gated host.
        href: https://gfn.rainforest.tools/
        description: "Dashboards & Visualization"
        icon: grafana.png
        namespace: monitoring
        app: grafana
        widget:
          type: grafana
          url: http://${raspberry_pi_ip}:${grafana_port}
          username: ${grafana_username}
          password: ${grafana_password}
    - Prometheus:
        href: http://${raspberry_pi_hostname}:${prometheus_port}
        description: "Metrics Collection & Storage"
        icon: prometheus.png
        namespace: monitoring
        app: prometheus
        widget:
          type: prometheus
          url: http://${raspberry_pi_ip}:${prometheus_port}
    - AlertManager:
        href: http://${raspberry_pi_hostname}:${alertmanager_port}
        description: "Alert Management & Routing"
        icon: alertmanager.png
        namespace: monitoring
        app: alertmanager
