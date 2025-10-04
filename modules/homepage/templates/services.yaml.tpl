- "Mac Mini M4 (AI & Automation)":
    - Open WebUI:
        href: https://open-webui.rainforest.tools/
        description: "AI Chat Interface with Claude & OpenAI"
        icon: open-webui.png
        namespace: homelab
        app: open-webui
        cluster: mac-mini
    - Flowise:
        href: https://flowise.rainforest.tools/
        description: "Low-code AI Workflow Builder"
        icon: flowise.png
        namespace: homelab  
        app: flowise
        cluster: mac-mini
    - n8n:
        href: https://n8n.rainforest.tools/
        description: "Workflow Automation Platform"
        icon: n8n.png
        namespace: homelab
        app: n8n
        cluster: mac-mini
    - Whisper STT:
        href: https://whisper.rainforest.tools/
        description: "Speech-to-Text API Service"
        icon: whisper.png
        server: macmini-docker
        container: homelab-whisper

- "Mac Mini M4 (Storage & Files)":
    - MinIO Console:
        href: https://minio.rainforest.tools/
        description: "S3-Compatible Object Storage"
        icon: minio.png
        namespace: homelab
        app: minio
        cluster: mac-mini
    - MinIO S3 API:
        href: https://s3.rainforest.tools/
        description: "S3 API Endpoint"
        icon: minio.png
        namespace: homelab
        app: minio
        cluster: mac-mini
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
        namespace: homelab
        app: pgadmin
        cluster: mac-mini

- "Mac Mini M4 (Development Tools)":
    - Docker MCP Gateway:
        href: https://docker-mcp.rainforest.tools/
        description: "Claude Code Integration"
        icon: docker.png
        server: macmini-docker
        container: homelab-docker-mcp-gateway

- "Raspberry Pi 5 (IoT Platform)":
    - HomeAssistant:
        href: http://${raspberry_pi_hostname}:8123
        description: "Home Automation"
        icon: home-assistant.png
        server: pi5-docker
        container: homeassistant
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
        cluster: raspberrypi-5
        widget:
          type: grafana
          url: http://${raspberry_pi_hostname}:${grafana_port}
          username: admin
          password: admin123
    - Prometheus:
        href: http://${raspberry_pi_hostname}:${prometheus_port}
        description: "Metrics Collection & Storage"
        icon: prometheus.png
        namespace: monitoring
        app: prometheus
        cluster: raspberrypi-5
        widget:
          type: prometheus
          url: http://${raspberry_pi_hostname}:${prometheus_port}
    - AlertManager:
        href: http://${raspberry_pi_hostname}:${alertmanager_port}
        description: "Alert Management & Routing"
        icon: alertmanager.png
        namespace: monitoring
        app: alertmanager
        cluster: raspberrypi-5
    - Loki:
        href: http://${raspberry_pi_hostname}:${loki_port}
        description: "Log Aggregation & Search"
        icon: loki.png
        namespace: monitoring
        app: loki
        cluster: raspberrypi-5