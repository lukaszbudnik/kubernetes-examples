#!/bin/bash

# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
echo "Installing Prometheus..."
helm install prometheus prometheus-community/prometheus \
  --namespace hpa-custom \
  --set server.persistentVolume.enabled=false \
  --set alertmanager.enabled=false \
  --set pushgateway.enabled=false

# Install Prometheus Adapter
echo "Installing Prometheus Adapter..."
# We need to point the adapter to the Prometheus service
PROMETHEUS_URL="http://prometheus-server.hpa-custom.svc.cluster.local"

helm install prometheus-adapter prometheus-community/prometheus-adapter \
  --namespace hpa-custom \
  --set prometheus.url=$PROMETHEUS_URL \
  --set prometheus.port=80 \
  -f 05-prometheus-adapter-values.yaml

echo "Monitoring setup complete. It may take a few minutes for metrics to populate."
