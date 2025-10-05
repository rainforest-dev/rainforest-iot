- job_name: 'mac-mini-docker'
  static_configs:
    - targets: ['${mac_mini_docker_endpoint}']
  metrics_path: /metrics
  scrape_interval: 30s

- job_name: 'mac-mini-node'
  static_configs:
    - targets: ['${mac_mini_ip}:9100']
  scrape_interval: 30s

- job_name: 'pi-hole'
  static_configs:
    - targets: ['${pihole_endpoint}']
  metrics_path: /admin/api.php
  scrape_interval: 60s
  params:
    auth: ['${pihole_api_token}']

- job_name: 'homeassistant'
  static_configs:
    - targets: ['${external_hostname}:8123']
  metrics_path: /api/prometheus
  scrape_interval: 30s

# Mac Mini Kubernetes services
- job_name: 'mac-mini-postgres'
  static_configs:
    - targets: ['${mac_mini_ip}:30432']
  metrics_path: /metrics
  scrape_interval: 30s

- job_name: 'mac-mini-minio'
  static_configs:
    - targets: ['${mac_mini_ip}:30900']
  metrics_path: /minio/v2/metrics/cluster
  scrape_interval: 30s
  scheme: http

# Blackbox Exporter - HTTP health checks for all homelab services
- job_name: 'blackbox-homelab-services'
  metrics_path: /probe
  params:
    module: [http_2xx]
  static_configs:
    - targets:
        - https://open-webui.rainforest.tools
        - https://flowise.rainforest.tools
        - https://n8n.rainforest.tools
        - https://calibre-web.rainforest.tools
        - https://whisper.rainforest.tools
        - https://minio.rainforest.tools
        - https://pgadmin.rainforest.tools
        - https://s3.rainforest.tools
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: prometheus-prometheus-blackbox-exporter:9115