# Multi-tenant isolation with Cilium Network Policies

Demonstrates multi-tenant isolation and zero-trust networking using Cilium Network Policies. Deploys three namespaces (`tenant-a`, `tenant-b`, `metadata`) with frontend and backend services to show the security problem (unrestricted cross-namespace access) and the solution (enforced network policies).

---

## Deploy

```bash
kubectl apply -f 00-namespaces.yaml
kubectl apply -f 01-deployments.yaml

# Wait for pods to be ready
kubectl rollout status deployment/frontend -n tenant-a
kubectl rollout status deployment/backend -n tenant-a
kubectl rollout status deployment/frontend -n tenant-b
kubectl rollout status deployment/backend -n tenant-b
kubectl rollout status deployment/frontend -n metadata
kubectl rollout status deployment/backend -n metadata
```

---

## Get pod and service details

```bash
kubectl get pods,svc -n tenant-a
kubectl get pods,svc -n tenant-b
kubectl get pods,svc -n metadata
```

You'll need the ClusterIP of each service for the tests below, or you can
use Kubernetes DNS which is more realistic:

| What                        | DNS name                          |
|-----------------------------|-----------------------------------|
| tenant-a frontend           | `frontend.tenant-a.svc.cluster.local` |
| tenant-a backend            | `backend.tenant-a.svc.cluster.local` |
| tenant-b frontend           | `frontend.tenant-b.svc.cluster.local` |
| tenant-b backend            | `backend.tenant-b.svc.cluster.local` |
| metadata frontend           | `frontend.metadata.svc.cluster.local` |
| metadata backend            | `backend.metadata.svc.cluster.local` |

---

## Default connectivity matrix (no network policies)

By default, Kubernetes allows both intra-namespace and cross-namespace connections.

| From \ To | tenant-a frontend | tenant-a backend | tenant-b frontend | tenant-b backend | metadata frontend | metadata backend |
|-----------|-------------------|------------------|-------------------|------------------|-------------------|------------------|
| tenant-a frontend | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| tenant-a backend | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| tenant-b frontend | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| tenant-b backend | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| metadata frontend | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| metadata backend | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## Desired connectivity matrix (with network policies)

After applying network policies, only the following connections will be allowed:

| From \ To | tenant-a frontend | tenant-a backend | tenant-b frontend | tenant-b backend | metadata frontend | metadata backend |
|-----------|-------------------|------------------|-------------------|------------------|-------------------|------------------|
| tenant-a frontend | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| tenant-a backend | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| tenant-b frontend | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ |
| tenant-b backend | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| metadata frontend | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| metadata backend | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |

**Allowed connections:**
- tenant-a frontend → tenant-a frontend (intra-tenant)
- tenant-a frontend → tenant-a backend (intra-tenant)
- tenant-a frontend → metadata frontend (cross-tenant, allow-listed)
- tenant-a backend → tenant-a frontend (intra-tenant)
- tenant-a backend → tenant-a backend (intra-tenant)
- tenant-b frontend → tenant-b frontend (intra-tenant)
- tenant-b frontend → tenant-b backend (intra-tenant)
- tenant-b frontend → metadata frontend (cross-tenant, allow-listed)
- tenant-b backend → tenant-b frontend (intra-tenant)
- tenant-b backend → tenant-b backend (intra-tenant)
- metadata frontend → metadata frontend (intra-tenant)
- metadata frontend → metadata backend (intra-tenant)
- metadata backend → metadata frontend (intra-tenant)
- metadata backend → metadata backend (intra-tenant)

**Blocked connections:**
- All cross-tenant frontend-to-frontend (tenant-a ↔ tenant-b)
- All cross-tenant frontend-to-backend
- All cross-tenant backend-to-anything
- tenant-a frontend → metadata backend
- tenant-b frontend → metadata backend
- metadata services → tenant namespaces

---

## Test the problem: cross-namespace access is allowed

By default Kubernetes allows both intra-namespace and cross-namespace connections. Get the tenant-a frontend pod:

```bash
POD_A_FRONTEND=$(kubectl get pod -n tenant-a -l app.kubernetes.io/name=frontend -o jsonpath='{.items[0].metadata.name}')
```

We will use the yosoy ping endpoint to test reachability:

```
GET /_/yosoy/ping?h=<hostname>&p=<port>
```

### Example 1: Allowed connection (intra-tenant)

tenant-a frontend → tenant-a backend (should be allowed):

```bash
kubectl exec -n tenant-a $POD_A_FRONTEND -- \
  wget -qO- "http://localhost/_/yosoy/ping?h=backend.tenant-a.svc.cluster.local&p=80"
```

Expected output:
```json
{"message":"ping succeeded"}
```

### Example 2: The problem (cross-tenant access that should be blocked)

tenant-a frontend → tenant-b frontend (should be blocked, but currently succeeds):

```bash
kubectl exec -n tenant-a $POD_A_FRONTEND -- \
  wget -qO- "http://localhost/_/yosoy/ping?h=frontend.tenant-b.svc.cluster.local&p=80"
```

Expected output (the problem – it succeeds):
```json
{"message":"ping succeeded"}
```

After applying network policies, this same command will fail with either a timeout or HTTP error, indicating the connection is blocked.

---

## What you've just shown

Without any network policy:

- DNS resolves across namespaces by default
- TCP connections succeed across namespaces
- Full HTTP requests succeed across namespaces
- A compromised pod in `tenant-a` can freely query any service in `tenant-b` or `metadata`

---

## Enter NetworkPolicy

We will now add `CiliumNetworkPolicy` resources to each namespace that enforce a default-deny and only allow:
- Intra-tenant traffic (frontend → backend within the same tenant)
- Cross-tenant access from tenant-a and tenant-b frontend to metadata services

Apply all three policy files:

```bash
kubectl apply -f 02-cilium-policies-tenant-a.yaml
kubectl apply -f 03-cilium-policies-tenant-b.yaml
kubectl apply -f 04-cilium-policies-metadata.yaml
```

---

## Verify the policies work

Run the full connectivity verification script to test all 26 combinations:

```bash
./verify-connectivity.sh
```

Expected output:
```
=== Stage 1: intra-tenant (should all be ALLOW) ===
  PASS  tenant-a/frontend → tenant-a/backend
  PASS  tenant-a/backend  → tenant-a/frontend
  PASS  tenant-b/frontend → tenant-b/backend
  PASS  tenant-b/backend  → tenant-b/frontend
  PASS  metadata/frontend  → metadata/backend
  PASS  metadata/backend   → metadata/frontend

=== Stage 2: cross-tenant allow-listed (should all be ALLOW) ===
  PASS  tenant-a/frontend → metadata/frontend
  PASS  tenant-b/frontend → metadata/frontend

=== Stage 3: cross-tenant blocked (should all be DENY) ===
  PASS  tenant-a/frontend → tenant-b/frontend
  PASS  tenant-a/frontend → tenant-b/backend
  ... (8 tests total)

=== Stage 4: metadata backend is blocked from tenant namespaces (should all be DENY) ===
  PASS  tenant-a/frontend → metadata/backend
  PASS  tenant-b/frontend → metadata/backend

=== Stage 5: metadata cannot reach tenant namespaces (should all be DENY) ===
  PASS  metadata/frontend → tenant-a/frontend
  ... (8 tests total)

======================================
  Results: 26 passed, 0 failed
======================================
```

All tests should pass, confirming that network policies are enforced correctly.
