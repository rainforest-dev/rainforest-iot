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
%{ endif ~}