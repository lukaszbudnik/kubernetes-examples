# Advanced Kubernetes Design Patterns

A collection of practical examples demonstrating advanced Kubernetes design patterns and architectures for production-grade deployments.

## Examples

### [traffic-split/](traffic-split/)

**Traffic routing and A/B testing strategies** using Kubernetes Gateway API:

- Weighted traffic splitting (canary deployments, gradual rollouts)
- Header-based routing (A/B testing, feature flags)
- Combined strategies for sophisticated traffic management

See [traffic-split/README.md](traffic-split/README.md) for details.

### [traffic-mirroring/](traffic-mirroring/)

**Traffic mirroring and shadowing** using Kubernetes Gateway API:

- Mirror production traffic to a secondary service
- Test new versions with real traffic without impacting users
- Validate changes before full rollout

See [traffic-mirroring/README.md](traffic-mirroring/README.md) for details.

### [network-policies-enforcement/](network-policies-enforcement/)

**Multi-tenant isolation and network security** using Cilium Network Policies:

- Enforce zero-trust networking within a cluster
- Isolate tenants and prevent cross-namespace access
- Allow-list specific cross-tenant communication patterns
- Demonstrate the problem and solution with practical tests

See [network-policies-enforcement/README.md](network-policies-enforcement/README.md) for details.

### [rbac/](rbac/)

**Least privilege secret access** using Kubernetes RBAC:

- Create dedicated ServiceAccounts for applications
- Configure fine-grained Roles for specific resource access
- Use RoleBindings to securely grant permissions to identities

See [rbac/README.md](rbac/README.md) for details.

### [leader-election/](leader-election/)

**High availability and leader election** using Lease API and sidecar pattern:

- Demonstrate the sidecar leader election pattern in Kubernetes
- Use a sidecar to manage election and expose leader status to the main application
- Ensure only one instance performing leader-specific tasks at a time

See [leader-election/README.md](leader-election/README.md) for details.

### [deployment-scaling/](deployment-scaling/)

**Horizontal scaling, graceful shutdown, and automated scaling** using Kubernetes Deployments:

- Trapping `SIGTERM` signals for reliable process termination
- Configuring termination grace periods for long-running tasks
- Automated scaling using a CronJob and the Kubernetes API
- Using ConfigMaps to inject application logic into containers

See [deployment-scaling/README.md](deployment-scaling/README.md) for details.

### [hpa-custom-metrics/](hpa-custom-metrics/)

**Horizontal scaling based on custom metrics** using HPA and Prometheus:

- Scaling deployments based on standard resource metrics (CPU/Memory)
- Implementing custom metric scaling (e.g., queue length, request rate)
- Using the Prometheus Adapter to expose metrics to the Kubernetes API
- Configuring scaling behaviors like stabilization windows and capped reductions

See [hpa-custom-metrics/README.md](hpa-custom-metrics/README.md) for details.

---

## Prerequisites

### Install Cilium (optional, required for network-policies-enforcement)

Cilium provides advanced networking and security policies. Below are setup instructions for macOS with minikube.

```bash
# 1. Install the Cilium CLI
brew install cilium-cli

# 2. Start minikube without a CNI (so you can install Cilium yourself)
#    Use the socket_vmnet driver for best compatibility on Apple Silicon
minikube start --network-plugin=cni --cni=false

# 3. Install Cilium
cilium install

# 4. Verify
cilium status

# 5. Optional: run connectivity test (takes some time)
cilium connectivity test
```

### Install Gateway API CRDs (required for traffic-split and traffic-mirroring)

Gateway API ships as CRDs and is not bundled with Kubernetes.

```bash
# Standard channel (GA resources: GatewayClass, Gateway, HTTPRoute)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml

# Verify
kubectl get crd | grep gateway.networking.k8s.io
```

### Install a Gateway Controller (required for traffic-split and traffic-mirroring)

Choose a controller that matches your environment. The `GatewayClass.spec.controllerName` in gateway YAML must match the controller you install.

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

Deploy an example:

```bash
# Traffic splitting and routing
kubectl apply -k traffic-split/

# Traffic mirroring
kubectl apply -k traffic-mirroring/

# Multi-tenant network isolation
kubectl apply -k network-policies-enforcement/

# Least privilege RBAC
kubectl apply -k rbac/

# Deployment scaling and graceful shutdown
kubectl apply -k deployment-scaling/

# High availability leader election
kubectl apply -k leader-elector/

# Horizontal scaling based on custom metrics
kubectl apply -k hpa-custom-metrics/
```

---

## Key Concepts

### Traffic Management (Gateway API)

| Concept | Description |
|---------|-------------|
| GatewayClass | Defines a class of gateways (e.g., Envoy) |
| Gateway | A single listener attached to a GatewayClass |
| HTTPRoute | Defines routing rules for HTTP traffic |
| BackendRef | Reference to a Service |
| RequestMirror | Mirrors traffic to a secondary backend |
| Weighted routing | Split traffic by weight percentage |
| Header matching | Route based on request headers |

### Network Security (Cilium)

| Concept | Description |
|---------|-------------|
| CiliumNetworkPolicy | Fine-grained network access control |
| Default-deny | Deny all traffic by default, allow explicitly |
| Endpoint selector | Target pods by labels |
| Ingress/Egress rules | Control inbound and outbound traffic |
| Multi-tenant isolation | Prevent cross-namespace communication |
| Allow-list patterns | Permit specific cross-tenant flows |

### Access Control (RBAC)

| Concept | Description |
|---------|-------------|
| ServiceAccount | Identity for processes in a Pod |
| Role | Namespace-scoped set of permissions |
| RoleBinding | Binds a Role to a ServiceAccount |
| Least Privilege | Granting only the minimum required permissions |
| Secret Access | Restricting read access to sensitive data |

### Scaling & Lifecycle

| Concept | Description |
|---------|-------------|
| Horizontal Scaling | Adjusting replica count via `kubectl scale` |
| HPA (Custom Metrics) | Automated scaling via Prometheus & Custom Metrics API |
| Stabilization Window | Delaying scale-down to prevent thrashing |
| Automated Scaling | Custom scaling logic via CronJobs and API |
| SIGTERM | Signal sent to processes for graceful shutdown |
| Grace Period | Time allowed for cleanup before `SIGKILL` |
| ConfigMap Volume | Injecting scripts/config from ConfigMaps |
