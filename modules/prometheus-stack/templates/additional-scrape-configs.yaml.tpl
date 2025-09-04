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