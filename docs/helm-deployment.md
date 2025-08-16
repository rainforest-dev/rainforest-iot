# Direct Helm Deployment Guide

If you prefer using Helm directly instead of Terraform, here are the equivalent commands:

## Prerequisites
```bash
# Install K3s on Pi 5
curl -sfL https://get.k3s.io | sh -

# Configure kubectl
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(whoami) ~/.kube/config

# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

## 1. Create Namespaces and Storage
```bash
kubectl create namespace monitoring
kubectl create namespace ingress-nginx

# Create storage class (K3s includes local-path by default)
```

## 2. Deploy Prometheus Stack
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.resources.requests.cpu=200m \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.limits.cpu=500m \
  --set prometheus.prometheusSpec.resources.limits.memory=512Mi \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30090 \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30080 \
  --set grafana.adminPassword=admin123 \
  --set grafana.resources.requests.cpu=100m \
  --set grafana.resources.requests.memory=128Mi \
  --set grafana.resources.limits.cpu=200m \
  --set grafana.resources.limits.memory=256Mi \
  --set alertmanager.alertmanagerSpec.resources.requests.cpu=50m \
  --set alertmanager.alertmanagerSpec.resources.requests.memory=64Mi \
  --set alertmanager.alertmanagerSpec.resources.limits.cpu=100m \
  --set alertmanager.alertmanagerSpec.resources.limits.memory=128Mi \
  --set alertmanager.service.type=NodePort \
  --set alertmanager.service.nodePort=30093
```

## 3. Deploy Loki Stack
```bash
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set loki.resources.requests.cpu=100m \
  --set loki.resources.requests.memory=128Mi \
  --set loki.resources.limits.cpu=300m \
  --set loki.resources.limits.memory=512Mi \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi \
  --set loki.service.type=NodePort \
  --set loki.service.nodePort=30100 \
  --set promtail.enabled=true \
  --set promtail.resources.requests.cpu=50m \
  --set promtail.resources.requests.memory=64Mi \
  --set promtail.resources.limits.cpu=100m \
  --set promtail.resources.limits.memory=128Mi \
  --set grafana.enabled=false
```

## 4. Configure Grafana Data Sources
```bash
# Add Loki as data source to Grafana
kubectl exec -n monitoring deployment/prometheus-grafana -- \
  grafana-cli admin reset-admin-password admin123

# Access Grafana at http://raspberrypi-5:30080
# Add Loki data source: http://loki:3100
```

## 5. Monitor External Services
Create additional scrape configs for Mac mini and Pi-hole:

```yaml
# external-scrape-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-additional-scrape-configs
  namespace: monitoring
data:
  additional-scrape-configs.yaml: |
    - job_name: 'mac-mini-docker'
      static_configs:
        - targets: ['dockerproxy.orb.local:2375']
      metrics_path: '/metrics'
      scrape_interval: 30s
    
    - job_name: 'mac-mini-node'
      static_configs:
        - targets: ['100.86.67.66:9100']
      scrape_interval: 30s
    
    - job_name: 'pi-hole'
      static_configs:
        - targets: ['raspberrypi-5:8080']
      metrics_path: '/admin/api.php'
      scrape_interval: 60s
```

```bash
kubectl apply -f external-scrape-config.yaml
```

## Benefits of Terraform + Helm Approach
- **Version Control**: Infrastructure as code with state management
- **Consistency**: Reproducible deployments across environments  
- **Integration**: Seamless integration with Docker containers
- **Variables**: Centralized configuration in terraform.tfvars
- **Dependencies**: Automatic dependency management between resources

## Direct Helm Benefits
- **Simplicity**: Direct Kubernetes deployment
- **Flexibility**: Easy chart customization
- **Community**: Access to thousands of Helm charts
- **Updates**: Simple helm upgrade commands

Choose the approach that fits your workflow better!