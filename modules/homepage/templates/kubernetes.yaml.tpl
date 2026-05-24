%{ if homepage_enable_kubernetes_widgets ~}
# Kubernetes configuration for Raspberry Pi 5 K3s cluster
# Uses custom kubeconfig with IP address instead of mDNS hostname
mode: default

# Homepage will use KUBECONFIG environment variable to find the config
# The kubeconfig is mounted at /tmp/kube/kubeconfig-pi5.yaml
%{ endif ~}