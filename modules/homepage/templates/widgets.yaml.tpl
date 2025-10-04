- resources:
    cpu: true
    memory: true
    disk: /
    network: true
    label: "Pi 5 Resources"
    
- search:
    provider: google
    showSearchSuggestions: true
    target: _blank

%{ if homepage_enable_kubernetes_widgets ~}
- kubernetes:
    cluster:
      show: true
      cpu: true
      memory: true
      showLabel: true
      label: "K3s Cluster"
    nodes:
      show: true
      cpu: true  
      memory: true
      showLabel: true

# Monitoring Widgets
- prometheus:
    url: http://${raspberry_pi_hostname}:${prometheus_port}
    label: "Prometheus Metrics"

- grafana:
    url: http://${raspberry_pi_hostname}:${grafana_port}
    username: admin
    password: admin123
    label: "Grafana Dashboards"

# Mac Mini Resources via Docker API
- docker:
    server: macmini-docker
    cpu: true
    memory: true
    running: true
    total: true
    label: "Mac Mini Docker"
%{ endif ~}