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

# Blackbox Exporter - HTTP synthetic monitoring
- job_name: 'blackbox-http'
  metrics_path: /probe
  params:
    module: [http_2xx]
  static_configs:
    - targets:
%{~ for t in blackbox_http_targets ~}
        - ${t}
%{~ endfor ~}
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: prometheus-prometheus-blackbox-exporter:9115

# Blackbox Exporter - ICMP ping probes
- job_name: 'blackbox-icmp'
  metrics_path: /probe
  params:
    module: [icmp]
  static_configs:
    - targets:
%{~ for t in blackbox_icmp_targets ~}
        - ${t}
%{~ endfor ~}
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: prometheus-prometheus-blackbox-exporter:9115