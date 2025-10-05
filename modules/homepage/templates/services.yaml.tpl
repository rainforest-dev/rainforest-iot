- "Mac Mini M4 (AI & Automation)":
    - Open WebUI:
        href: https://open-webui.rainforest.tools/
        description: "AI Chat Interface with Claude & OpenAI"
        icon: open-webui.png
        server: macmini-docker
        container: /k8s_open-webui_open-webui-0_homelab_27d8995c-c017-43bb-92fe-1656c9e606d1_2
    - Flowise:
        href: https://flowise.rainforest.tools/
        description: "Low-code AI Workflow Builder"
        icon: flowise.png
        server: macmini-docker
        container: /k8s_flowise_homelab-flowise-75958fc5c9-85cmm_homelab_9dba30d6-a3cb-4bb6-821d-5ff49f4c943d_0
    - n8n:
        href: https://n8n.rainforest.tools/
        description: "Workflow Automation Platform"
        icon: n8n.png
        server: macmini-docker
        container: /k8s_n8n_homelab-n8n-c975766cf-pv6qq_homelab_dee19c7c-e301-4de2-97c1-44bd4ab570e8_0
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
        server: macmini-docker
        container: /k8s_minio_homelab-minio-59ccc784ff-dfq5l_homelab_3f6f61b5-bd0f-4fc0-ba4f-c4b87eeea2cc_0
    - MinIO S3 API:
        href: https://s3.rainforest.tools/
        description: "S3 API Endpoint"
        icon: minio.png
        server: macmini-docker
        container: /k8s_minio_homelab-minio-59ccc784ff-dfq5l_homelab_3f6f61b5-bd0f-4fc0-ba4f-c4b87eeea2cc_0
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
        server: macmini-docker
        container: /k8s_pgadmin4_homelab-pgadmin-pgadmin4-5dc68d87fb-gqfgs_homelab_cd81a49b-c640-475a-b66e-90a71dff9c84_0

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
        widget:
          type: grafana
          url: http://${raspberry_pi_ip}:${grafana_port}
          username: admin
          password: admin123
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