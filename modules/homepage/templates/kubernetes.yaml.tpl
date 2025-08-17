%{ if homepage_enable_kubernetes_widgets ~}
mode: cluster
config: /tmp/kubeconfig.yaml
# Uses mounted kubeconfig for Pi 5 K3s cluster
%{ endif ~}