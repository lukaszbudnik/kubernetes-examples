# Kubernetes Gateway API - Traffic Routing Strategies

Demonstrates different traffic routing strategies using Kubernetes Gateway API with Envoy Gateway.

## Directories

### [traffic-split/](traffic-split/)

A/B testing and weighted traffic splitting strategies:

- **Strategy 1**: Weighted split (90% v1, 10% v2)
- **Strategy 2**: Header-based routing (X-Ab-Group header)
- **Strategy 3**: Weighted split + header override for QA

See [traffic-split/README.md](traffic-split/README.md) for details.

### [traffic-mirroring/](traffic-mirroring/)

Traffic mirroring:

- Copies requests to a mirroring service
- Primary service returns response to client
- Mirroring response is discarded
- Useful for testing with production traffic

See [traffic-mirroring/README.md](traffic-mirroring/README.md) for details.

---

## Prerequisites

### 1. Install the Gateway API CRDs

Gateway API ships as CRDs — they are not bundled with Kubernetes itself.

```bash
# Standard channel (GA resources: GatewayClass, Gateway, HTTPRoute)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml

# Verify
kubectl get crd | grep gateway.networking.k8s.io
```

### 2. Install a Gateway controller

Pick one that matches your environment. The `GatewayClass.spec.controllerName` in
gateway yaml must match the controller you install.

| Controller       | Install guide                                          | controllerName                                         |
|------------------|--------------------------------------------------------|--------------------------------------------------------|
| **Envoy Gateway**| https://gateway.envoyproxy.io/docs/                    | `gateway.envoyproxy.io/gatewayclass-controller`        |
| **Nginx Gateway**| https://docs.nginx.com/nginx-gateway-fabric/           | `k8s.nginx.org/nginx-gateway-controller`               |
| **Istio**        | https://istio.io/latest/docs/tasks/traffic-management/ | `istio.io/gateway-controller`                          |
| **Traefik**      | https://doc.traefik.io/traefik/providers/kubernetes-gateway/ | `traefik.io/gateway-controller`               |

Quick start with Envoy Gateway on a local cluster:
```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.7.1 \
  -n envoy-gateway-system --create-namespace
```

---

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