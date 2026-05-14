# Kubernetes RBAC – Least Privilege Secret Access

Demonstrates how to securely restrict access to Kubernetes secrets using Role-Based Access Control (RBAC).

This example shows a "least privilege" approach where a specific application identity is granted read-only access to only the secrets it needs, while other identities are denied access.

## Overview

Kubernetes RBAC uses three main components to control access:

1.  **ServiceAccount**: An identity for processes running in your pods.
2.  **Role**: A set of permissions (e.g., "get" secrets) restricted to a specific namespace.
3.  **RoleBinding**: The bridge that grants the permissions defined in a **Role** to a **ServiceAccount**.

```
[ Pod ] → [ ServiceAccount ] ← [ RoleBinding ] → [ Role ]
```

## Files

| File | Description |
|------|-------------|
| `00-namespace.yaml` | Dedicated `herkules` namespace |
| `01-serviceaccount.yaml` | `db-app-sa` identity for the application |
| `02-role.yaml` | `db-secret-reader` role with `get` access to a specific secret |
| `03-rolebinding.yaml` | Binds `db-app-sa` to `db-secret-reader` |
| `04-secret.yaml` | Sample `db-credentials` secret |
| `05-deployment.yaml` | Deployment using the authorized `db-app-sa` |
| `06-serviceaccount-no-access.yaml` | A secondary identity with no secret access |
| `07-role-no-access.yaml` | A role that only allows pod listing |
| `08-rolebinding-no-access.yaml` | Binds the secondary SA to the restricted role |
| `kustomization.yaml` | Kustomize orchestration |

## Deploy

```bash
kubectl apply -k .
```

## Test

### 1. Verify permissions using `auth can-i`

Check if the authorized ServiceAccount can read the secret:
```bash
kubectl auth can-i get secrets/db-credentials \
  --as=system:serviceaccount:herkules:db-app-sa -n herkules
# Expected: yes
```

Check if the unauthorized ServiceAccount is denied:
```bash
kubectl auth can-i get secrets/db-credentials \
  --as=system:serviceaccount:herkules:no-secret-access-sa -n herkules
# Expected: no
```

### 2. Verify access from within a Pod

Execute into the running pod and attempt to fetch the secret using its own token:

```bash
POD_NAME=$(kubectl get pods -n herkules -l app=db-app -o jsonpath='{.items[0].metadata.name}')

kubectl exec -it $POD_NAME -n herkules -- sh -c '
  TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  curl -ks https://kubernetes.default.svc/api/v1/namespaces/herkules/secrets/db-credentials \
    -H "Authorization: Bearer $TOKEN"
'
```

## Use Cases

- **Credential Security**: Ensure only pods requiring DB access can read DB credentials.
- **Audit Compliance**: Meet security requirements by providing granular access logs and minimal permissions.
- **Blast Radius Reduction**: Limit what an attacker can do if a single pod is compromised.
