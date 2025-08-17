%{ if homepage_enable_kubernetes_widgets ~}
# Multiple Kubernetes cluster configuration
clusters:
  # Raspberry Pi 5 K3s cluster
  - name: raspberrypi-5
    mode: cluster
    config: /tmp/kube/kubeconfig-pi5.yaml
    # Uses mounted kubeconfig for Pi 5 K3s cluster with IP address
  
  # Mac Mini K8s cluster  
  - name: mac-mini
    mode: cluster
    config: /tmp/kube/kubeconfig-mac.yaml
    # Uses mounted kubeconfig for Mac Mini cluster with IP address
%{ endif ~}