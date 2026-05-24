# All targets use raw IP addresses, not .local mDNS hostnames.
# K3s pods use CoreDNS which cannot resolve mDNS; .local names cause "no such host" errors.

- job_name: 'mac-mini-docker'
  static_configs:
    - targets: ['${mac_mini_ip}:2375']
  metrics_path: /metrics
  scrape_interval: 30s

- job_name: 'mac-mini-minio'
  static_configs:
    - targets: ['${mac_mini_ip}:30900']
  metrics_path: /minio/v2/metrics/cluster
  scrape_interval: 30s
  scheme: http

# Pi-hole Prometheus exporter sidecar (port 9617).
# Replaces the old /admin/api.php job which returned JSON, not Prometheus text-format.
- job_name: 'pihole-exporter'
  static_configs:
    - targets: ['${external_ip}:9617']
      labels:
        instance: 'raspberry-pi-5'
        service: 'pihole'
  metrics_path: /metrics
  scrape_interval: 30s

# CrowdSec IDS metrics (community bans + local decisions)
- job_name: 'crowdsec'
  static_configs:
    - targets: ['${external_ip}:6060']
      labels:
        instance: 'raspberry-pi-5'
        service: 'crowdsec'
  metrics_path: /metrics
  scrape_interval: 30s

%{~ if homeassistant_token != "" ~}
# Home Assistant Prometheus integration (requires HA Prometheus integration + long-lived token)
- job_name: 'homeassistant'
  static_configs:
    - targets: ['${external_ip}:8123']
  metrics_path: /api/prometheus
  authorization:
    credentials: '${homeassistant_token}'
  scrape_interval: 60s
%{~ endif ~}

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
