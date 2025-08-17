- "Mac Mini M4 (AI & Automation)":
    - Open WebUI:
        href: https://open-webui.rainforest.tools/
        description: "AI Chat Interface"
        icon: open-webui.png
        namespace: homelab
        app: open-webui
        cluster: mac-mini
    - Flowise:
        href: https://flowise.rainforest.tools/
        description: "AI Workflow Builder"
        icon: flowise.png
        namespace: homelab  
        app: flowise
        cluster: mac-mini
    - n8n:
        href: https://n8n.rainforest.tools/
        description: "Workflow Automation"
        icon: n8n.png
        namespace: homelab
        app: n8n
        cluster: mac-mini

- "Mac Mini M4 (Media & Files)":
    - Calibre Web:
        href: http://${mac_mini_hostname}:8083
        description: "Ebook Server"
        icon: calibre-web.png
        server: macmini-docker
        container: homelab-calibre-web
    - OpenSpeedTest:
        href: http://${mac_mini_hostname}:3333
        description: "Network Speed Test"
        icon: openspeedtest.png
        server: macmini-docker
        container: homelab-openspeedtest

- "Raspberry Pi 5 (IoT Platform)":
    - HomeAssistant:
        href: http://${raspberry_pi_hostname}:8123
        description: "Home Automation"
        icon: home-assistant.png
        server: pi5-docker
        container: homeassistant
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

- "Monitoring Stack (K3s on Pi 5)":
    - Grafana:
        href: http://${raspberry_pi_hostname}:${grafana_port}
        description: "Dashboards & Visualization"
        icon: grafana.png
        namespace: monitoring
        app: grafana
        cluster: raspberrypi-5
    - Prometheus:
        href: http://${raspberry_pi_hostname}:${prometheus_port}
        description: "Metrics Collection"
        icon: prometheus.png
        namespace: monitoring
        app: prometheus
        cluster: raspberrypi-5
    - AlertManager:
        href: http://${raspberry_pi_hostname}:${alertmanager_port}
        description: "Alert Management"
        icon: alertmanager.png
        namespace: monitoring
        app: alertmanager
        cluster: raspberrypi-5