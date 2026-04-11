# Traffic Mirroring Demo

Mirrors production traffic to a mirroring service for testing without affecting users.

Uses **[yosoy](https://github.com/lukaszbudnik/yosoy)** as a self-describing mock HTTP
backend. yosoy responds to every request with JSON that includes the pod name, env vars,
and request headers — making it easy to verify which version the Gateway is routing to
without any extra tooling.

## Overview

Traffic mirroring sends copies of requests to a mirroring service while the primary service handles the response. The mirroring response is discarded.

```
Client → Gateway → [Primary (v1)] → Response → Client
                ↘ [Mirroring] → Response (discarded)
```

## Files

| File | Description |
|------|-------------|
| `00-namespace.yaml` | Namespace definition |
| `01-deployment-primary.yaml` | Primary v1 deployment |
| `02-deployment-mirroring.yaml` | Mirroring deployment |
| `03-services.yaml` | Services for v1 and mirroring |
| `04-gateway.yaml` | GatewayClass and Gateway |
| `05-httproute-mirroring.yaml` | HTTPRoute with RequestMirror filter |
| `kustomization.yaml` | Kustomize configuration |

## Deploy

```bash
kubectl apply -k .
```

## Test

```bash
# Port-forward (minikube/local)
kubectl port-forward -n envoy-gateway-system \
  svc/$(kubectl get svc -n envoy-gateway-system -o name | head -1 | cut -d/ -f2) \
  8080:80 &
GATEWAY_IP="localhost:8080"

# Send request
curl http://$GATEWAY_IP/ -H "Host: mirroring.example.com"

# Check mirroring pod logs - shows mirrored requests
kubectl logs -n ab-demo deploy/yosoy-mirroring
```

## Use Cases

- Test new versions with real production traffic
- Compare responses between versions
- Load testing with realistic traffic patterns
- Validate changes without risk to users