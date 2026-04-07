# Kubernetes Gateway API - Traffic Routing Strategies

Demonstrates different traffic routing strategies using Kubernetes Gateway API with Envoy Gateway.

## Directories

### [traffic-split/](traffic-split/)

A/B testing and weighted traffic splitting strategies:

- **Strategy 1**: Weighted split (90% v1, 10% v2)
- **Strategy 2**: Header-based routing (X-Ab-Group header)
- **Strategy 3**: Weighted split + header override for QA

See [traffic-split/README.md](traffic-split/README.md) for details.

## Prerequisites

1. Install Gateway API CRDs:
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
   ```

2. Install Envoy Gateway:
   ```bash
   helm install eg oci://docker.io/envoyproxy/gateway-helm \
     --version v1.3.0 \
     -n envoy-gateway-system --create-namespace
   ```

## Quick Start

Choose a strategy:

```bash
# Traffic splitting (weighted/header-based)
kubectl apply -k traffic-split/

# Traffic mirroring
kubectl apply -k traffic-mirroring/
```

## Gateway API Concepts

| Concept | Description |
|---------|-------------|
| GatewayClass | Defines a class of gateways (e.g., Envoy) |
| Gateway | A single listener attached to a GatewayClass |
| HTTPRoute | Defines routing rules for HTTP traffic |
| BackendRef | Reference to a Service |
| RequestMirror | Mirrors traffic to a secondary backend |
| ResponseHeaderModifier | Adds/modifies response headers |
| Weighted routing | Split traffic by weight percentage |
| Header matching | Route based on request headers |