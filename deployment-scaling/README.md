# Kubernetes Deployment – Scaling & Graceful Shutdown

Demonstrates horizontal scaling, reliable termination of worker processes, and automated scaling logic using a CronJob.

This example features:
- A worker script that simulates long-running jobs and handles `SIGTERM` for graceful shutdown.
- An automated scaler that uses the Kubernetes API to ensure a minimum replica count is maintained.

## Overview

### Graceful Shutdown
Kubernetes manages application lifecycle through signals. When a pod is deleted or scaled down:
1.  **SIGTERM** is sent to the main process (PID 1).
2.  The process has a **Grace Period** (default 30s) to finish work and exit.
3.  **SIGKILL** is sent if the process is still running after the grace period.

### Automated Scaling
While Kubernetes has a Horizontal Pod Autoscaler (HPA), sometimes you need custom logic (e.g., scaling based on time of day, external APIs, or complex business rules). This example shows how to:
1.  Assign a **ServiceAccount** with permissions to patch deployments.
2.  Run a **CronJob** that executes a shell script.
3.  Use `curl` within the pod to interact with the Kubernetes API server.

## Files

| File | Description |
|------|-------------|
| `00-namespace.yaml` | Dedicated `flock` namespace |
| `01-configmap-worker-script.yaml` | Worker script with signal trapping logic |
| `02-deployment.yaml` | Worker deployment with `terminationGracePeriodSeconds` |
| `03-rbac-deployment-scaler.yaml` | RBAC for the scaler (ServiceAccount, Role, Binding) |
| `04-configmap-deployment-scaler.yaml` | Shell script that checks and updates replica count |
| `05-cronjob-deployment-scaler.yaml` | CronJob that runs the scaling script every 5 minutes |
| `kustomization.yaml` | Kustomize configuration |

## Deploy

```bash
kubectl apply -k .
```

## Test

### 1. Manual Scaling & Graceful Shutdown

Watch the logs from the worker pods:
```bash
kubectl logs -l app.kubernetes.io/name=worker -n flock -f --tail=10
```

In a separate terminal, scale down and watch the graceful exit:
```bash
kubectl scale deployment worker-pod -n flock --replicas=1
```

You should see the "Received SIGTERM" message, followed by the worker finishing its job before exiting:

```
2026-05-13T19:25:37Z [worker-pod-57b7d97746-7qp7z] Worker script started
2026-05-13T19:25:37Z [worker-pod-57b7d97746-7qp7z] Starting job 1, sleeping for 53 seconds...
2026-05-16T19:25:59Z [worker-pod-57b7d97746-7qp7z] Received SIGTERM, setting shutdown flag, will finish current job then shutdown.
2026-05-16T19:26:30Z [worker-pod-57b7d97746-7qp7z] Job 1 completed
2026-05-16T19:26:30Z [worker-pod-57b7d97746-7qp7z] Shutdown flag set, stopping polling for new jobs.
2026-05-16T19:26:30Z [worker-pod-57b7d97746-7qp7z] Graceful shutdown completed
```

### 2. Automated Scaling via CronJob

The CronJob is configured to ensure at least **3 replicas**. You can test this by manually scaling the deployment to 0 and waiting for the CronJob to trigger (or triggering it manually).

**Manual Trigger:**
```bash
# Scale down to 1
kubectl scale deployment worker-pod -n flock --replicas=1

# Trigger the CronJob immediately
kubectl create job --from=cronjob/deployment-scaler-cronjob manual-scale-check -n flock

# Check the scaler logs
kubectl logs -l job-name=manual-scale-check -n flock

# Verify the deployment scaled back to 3
kubectl get deployment worker-pod -n flock
```

## Use Cases

- **Graceful Shutdown**: Essential for batch processors, long-lived connections, and stateful applications.
- **Custom Scaling Logic**: Scale based on legacy systems, specific time windows, or pre-emptive warming of resources before peak hours.
- **Self-Healing Infrastructure**: Ensure critical deployments maintain a minimum footprint even if manually altered.
