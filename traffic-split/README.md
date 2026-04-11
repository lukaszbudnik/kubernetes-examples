# Kubernetes Gateway API – A/B Testing Demo

Routes traffic across two service versions for controlled experimentation — 
split by weight for gradual rollouts, or by request header for explicit cohort targeting.

Uses **[yosoy](https://github.com/lukaszbudnik/yosoy)** as a self-describing mock HTTP
backend. yosoy responds to every request with JSON that includes the pod name, env vars,
and request headers — making it easy to verify which version the Gateway is routing to
without any extra tooling.

## Deploy

```bash
# Apply everything at once
kubectl apply -k .

# Or apply piece by piece (recommended when learning)
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-deployment-v1.yaml
kubectl apply -f 02-deployment-v2.yaml
kubectl apply -f 03-services.yaml
kubectl apply -f 04-gateway.yaml
kubectl apply -f 05-httproute-weighted.yaml
kubectl apply -f 06-httproute-header.yaml
kubectl apply -f 07-httproute-smart.yaml
```

### Check status

```bash
# Gateway should show PROGRAMMED=True
kubectl get gateway -n ab-demo

# Routes should show ACCEPTED=True and PROGRAMMED=True for each rule
kubectl get httproute -n ab-demo

# Pods
kubectl get pods -n ab-demo
```

---

## Get the Gateway IP

```bash
# Cloud provider (EKS, GKE, AKS) – a LoadBalancer is provisioned automatically
GATEWAY_IP=$(kubectl get gateway ab-demo-gateway -n ab-demo \
  -o jsonpath='{.status.addresses[0].value}')

# Local cluster (minikube, kind, etc.) – no LoadBalancer, use port-forward
# Note: PROGRAMMED=False in Gateway status is expected when no address is assigned
kubectl port-forward -n envoy-gateway-system \
  svc/$(kubectl get svc -n envoy-gateway-system -o name | head -1 | cut -d/ -f2) \
  8080:80 &
GATEWAY_IP="localhost:8080"
```

---

## Testing

### Strategy 1 – Weighted split (`app.example.com`)

```bash
# Run the test script (requires port-forward or GATEWAY_IP set)
./test-weighted-split.sh

# Or with custom gateway IP
GATEWAY_IP=localhost:8080 ./test-weighted-split.sh

# With 90/10 split, expect roughly 18× v1 and 2× v2
```

To shift more traffic to v2, edit `05-httproute-weighted.yaml`:
```yaml
backendRefs:
  - name: yosoy-v1
    port: 80
    weight: 50   # was 90
  - name: yosoy-v2
    port: 80
    weight: 50   # was 10
```
```bash
kubectl apply -f 05-httproute-weighted.yaml
```

### Strategy 2 – Header-based routing (`ab.example.com`)

```bash
# Control group → v1 (no header)
curl -s http://$GATEWAY_IP/ -H "Host: ab.example.com" | grep -o 'APP_VERSION=[^",]*'

# Experiment group → v2
curl -s http://$GATEWAY_IP/ -H "Host: ab.example.com" -H "X-Ab-Group: v2" | grep -o 'APP_VERSION=[^",]*'
```

### Strategy 3 – Smart routing with override (`smart.example.com`)

```bash
# Normal user → weighted split (check X-Served-By response header)
curl -sv http://$GATEWAY_IP/ -H "Host: smart.example.com" 2>&1 | grep x-served-by

# QA engineer forcing v1
curl -sv http://$GATEWAY_IP/ -H "Host: smart.example.com" -H "X-Force-Version: v1" \
  2>&1 | grep x-served-by

# QA engineer forcing v2
curl -sv http://$GATEWAY_IP/ -H "Host: smart.example.com" -H "X-Force-Version: v2" \
  2>&1 | grep x-served-by
```

---

## Key concepts illustrated

| Concept | Where | What to look at |
|---|---|---|
| **GatewayClass** | `04-gateway.yaml` | Binds to the installed controller |
| **Gateway** | `04-gateway.yaml` | Declares the listener; `allowedRoutes` acts as RBAC |
| **HTTPRoute parentRefs** | all route files | How a route attaches to a specific Gateway listener |
| **Weighted backendRefs** | `05-httproute-weighted.yaml` | The `weight` field on each backend |
| **Header matching** | `06-httproute-header.yaml` | `rules[].matches[].headers` |
| **Rule ordering** | `06-httproute-header.yaml` | More specific rules (with matches) evaluated before catch-all |
| **Response header injection** | `07-httproute-smart.yaml` | `filters[].type: ResponseHeaderModifier` |
| **Named rules** | all route files | `rules[].name` — makes Gateway status conditions readable |

---

## Cleanup

```bash
kubectl delete namespace ab-demo
# GatewayClass is cluster-scoped, delete separately if no longer needed
kubectl delete gatewayclass ab-demo-gwclass
```
