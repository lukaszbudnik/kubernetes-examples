# Leader Election Pattern

This example demonstrates how to implement the leader election pattern in Kubernetes using a sidecar container.

## Overview

The leader election pattern is used when you have multiple instances of an application, but only one instance should perform certain tasks (e.g., writing to a database, processing a queue) at any given time.

In this example:
1.  **sidecar-elector**: A sidecar container (using `instana/leader-elector`) that participates in a Kubernetes lease-based election.
2.  **app-stub**: The main application container that queries the sidecar's HTTP endpoint to determine if it is the current leader.

## Prerequisites

Build `instana/leader-elector` image:

```
git clone git@github.com:instana/leader-elector.git
cd leader-elector
REPOSITORY=instana/leader-elector make
# use your architecture build
docker tag instana/leader-elector:arm64-test instana/leader-elector:latest
# load it into minikube
minikube image load instana/leader-elector:latest
minikube cache reload
```

## Deployment

Apply the manifests:

```bash
kubectl apply -k .
```

## Verification

1.  Check the logs of the pods to see which one is the leader:

```bash
kubectl logs -n leader-election -l app.kubernetes.io/name=leader-elector -c app-stub
```

2.  You should see output like:

```
2026-05-09T10:11:14+0000 [FOLLOWER] leader-elector-766c74849f-6jhnv
2026-05-09T10:11:15+0000 [LEADER] leader-elector-766c74849f-dmrxr
2026-05-09T10:10:55+0000 [FOLLOWER] leader-elector-766c74849f-spsf4
```

3.  To test failover, delete the leader pod:

```bash
# Find the leader
LEADER_POD=$(kubectl get pods -n leader-election -l app.kubernetes.io/name=leader-elector -o json | jq -r '.items[] | select(.status.phase=="Running") | .metadata.name' | while read pod; do if kubectl logs -n leader-election $pod -c app-stub | grep -q "LEADER"; then echo $pod; break; fi; done)

kubectl delete pod -n leader-election $LEADER_POD
```

4.  Watch the logs of the remaining pods to see a new leader being elected.

```bash
kubectl logs -n leader-election -l app.kubernetes.io/name=leader-elector -c app-stub
```
