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

- "Mac Mini M4 (Database & Admin)":
    - pgAdmin:
        href: https://pgadmin.rainforest.tools/
        description: "PostgreSQL Database Admin"
        icon: pgadmin.png
        # K8s-managed: container name changes on every pod restart, omitted to avoid stale "not found"

- "Mac Mini M4 (Development Tools)":
    - Docker MCP Gateway:
        href: https://docker-mcp.rainforest.tools/
        description: "Claude Code Integration"
        icon: docker.png
        server: macmini-docker
        container: homelab-docker-mcp-gateway

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
        container: music-assistant-server
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
        href: http://${raspberry_pi_hostname}:${grafana_port}
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