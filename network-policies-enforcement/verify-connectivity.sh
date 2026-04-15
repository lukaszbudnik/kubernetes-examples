#!/usr/bin/env bash
##############################################################################
# verify-connectivity.sh
#
# Runs all 26 combinations from the connectivity matrix and reports
# whether each result matches the expected outcome.
#
# Usage:
#   ./verify-connectivity.sh
##############################################################################

set -euo pipefail

PASS=0
FAIL=0

# Colours
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Run a ping from a pod and check the result against the expectation.
# Args: from_namespace  from_label_name  to_host  to_port  expected (allow|deny)  description
check() {
  local ns="$1" label="$2" host="$3" port="$4" expected="$5" desc="$6"

  local pod
  pod=$(kubectl get pod -n "$ns" -l "app.kubernetes.io/name=$label" \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) || true

  if [[ -z "$pod" ]]; then
    echo -e "  ${RED}SKIP${NC}  $desc  (pod not found in $ns)"
    return 0
  fi

  local result
  result=$(kubectl exec -n "$ns" "$pod" -- \
    wget -qO- --timeout=5 \
    "http://localhost/_/yosoy/ping?h=${host}&p=${port}" 2>/dev/null || true)

  local actual
  if echo "$result" | grep -q '"message":"ping succeeded"'; then
    actual="allow"
  else
    actual="deny"
  fi

  if [[ "$actual" == "$expected" ]]; then
    echo -e "  ${GREEN}PASS${NC}  $desc"
    ((PASS++))
  else
    echo -e "  ${RED}FAIL${NC}  $desc  (expected=$expected, got=$actual)"
    ((FAIL++))
  fi
  return 0
}

echo ""
echo "=== Stage 1: intra-tenant (should all be ALLOW) ==="
check tenant-a frontend backend.tenant-a.svc.cluster.local        80 allow "tenant-a/frontend → tenant-a/backend"
check tenant-a backend  frontend.tenant-a.svc.cluster.local       80 allow "tenant-a/backend  → tenant-a/frontend"
check tenant-b frontend backend.tenant-b.svc.cluster.local        80 allow "tenant-b/frontend → tenant-b/backend"
check tenant-b backend  frontend.tenant-b.svc.cluster.local       80 allow "tenant-b/backend  → tenant-b/frontend"
check metadata  frontend backend.metadata.svc.cluster.local       80 allow "metadata/frontend  → metadata/backend"
check metadata  backend  frontend.metadata.svc.cluster.local      80 allow "metadata/backend   → metadata/frontend"

echo ""
echo "=== Stage 2: cross-tenant allow-listed (should all be ALLOW) ==="
check tenant-a frontend frontend.metadata.svc.cluster.local       80 allow "tenant-a/frontend → metadata/frontend"
check tenant-b frontend frontend.metadata.svc.cluster.local       80 allow "tenant-b/frontend → metadata/frontend"

echo ""
echo "=== Stage 3: cross-tenant blocked (should all be DENY) ==="
check tenant-a frontend frontend.tenant-b.svc.cluster.local       80 deny  "tenant-a/frontend → tenant-b/frontend"
check tenant-a frontend backend.tenant-b.svc.cluster.local        80 deny  "tenant-a/frontend → tenant-b/backend"
check tenant-a backend  frontend.tenant-b.svc.cluster.local       80 deny  "tenant-a/backend  → tenant-b/frontend"
check tenant-a backend  backend.tenant-b.svc.cluster.local        80 deny  "tenant-a/backend  → tenant-b/backend"
check tenant-b frontend frontend.tenant-a.svc.cluster.local       80 deny  "tenant-b/frontend → tenant-a/frontend"
check tenant-b frontend backend.tenant-a.svc.cluster.local        80 deny  "tenant-b/frontend → tenant-a/backend"
check tenant-b backend  frontend.tenant-a.svc.cluster.local       80 deny  "tenant-b/backend  → tenant-a/frontend"
check tenant-b backend  backend.tenant-a.svc.cluster.local        80 deny  "tenant-b/backend  → tenant-a/backend"

echo ""
echo "=== Stage 4: metadata backend is blocked from tenant namespaces (should all be DENY) ==="
check tenant-a frontend backend.metadata.svc.cluster.local        80 deny  "tenant-a/frontend → metadata/backend"
check tenant-b frontend backend.metadata.svc.cluster.local        80 deny  "tenant-b/frontend → metadata/backend"

echo ""
echo "=== Stage 5: metadata cannot reach tenant namespaces (should all be DENY) ==="
check metadata  frontend frontend.tenant-a.svc.cluster.local      80 deny  "metadata/frontend → tenant-a/frontend"
check metadata  frontend backend.tenant-a.svc.cluster.local       80 deny  "metadata/frontend → tenant-a/backend"
check metadata  backend  frontend.tenant-a.svc.cluster.local      80 deny  "metadata/backend  → tenant-a/frontend"
check metadata  backend  backend.tenant-a.svc.cluster.local       80 deny  "metadata/backend  → tenant-a/backend"
check metadata  frontend frontend.tenant-b.svc.cluster.local      80 deny  "metadata/frontend → tenant-b/frontend"
check metadata  frontend backend.tenant-b.svc.cluster.local       80 deny  "metadata/frontend → tenant-b/backend"
check metadata  backend  frontend.tenant-b.svc.cluster.local      80 deny  "metadata/backend  → tenant-b/frontend"
check metadata  backend  backend.tenant-b.svc.cluster.local       80 deny  "metadata/backend  → tenant-b/backend"

echo ""
echo "======================================"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "======================================"
echo ""
