# Kubernetes Horizontal Pod Autoscaler (HPA) – Custom Metrics

This example demonstrates how to use the Horizontal Pod Autoscaler (HPA) to scale a deployment based on both standard (CPU/Memory) and custom metrics.

## Overview

HPA automatically scales the number of pods in a deployment based on observed metrics. By default, it supports resource metrics like CPU and Memory, but it can also be extended to use custom metrics provided by an external system (like Prometheus).

### 1. Standard Metrics (CPU/Memory)

Standard metrics are served by the **Metrics Server**, which is often pre-installed in many Kubernetes distributions (e.g., GKE, EKS, or enabled in Minikube/Kind).

To scale based on CPU usage, your HPA manifest would look like this:

```yaml
spec:
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

### 2. Custom Metrics

Custom metrics allow you to scale based on application-specific data, such as queue length, request rate, or any other business logic.

To use custom metrics, you typically need:
1.  A **Metrics Source**: An application or pod that emits the metric (e.g., exposing a `/metrics` endpoint for Prometheus).
2.  A **Metrics Collector**: A system like Prometheus that scrapes and stores these metrics.
3.  A **Custom Metrics Adapter**: A component (like the [Prometheus Adapter](https://github.com/kubernetes-sigs/prometheus-adapter)) that translates Prometheus metrics into the Kubernetes Custom Metrics API.

## This Example

In this example, I simulate a custom metric emitter.

### Metric Emitter Logic
The `metric-emitter` pod runs a shell script that simulates a fluctuating queue length:
1. It starts at 0.
2. It increments by 1 every minute until it reaches 10.
3. It then decrements by 3 every minute until it reaches 1. Note: when decrementing after a new metric is emitted, we sleep for an additional 60s to give us additional time to observe HPA in action.
4. Repeat, go to step 2.

The goal is to see the `sample-app` scale up aggressively as the queue grows and scale down predictably using stabilization windows.

## Deployment & Monitoring Setup

This example uses **Helm** to install Prometheus and the Prometheus Adapter.

### 1. Prerequisites
- **Helm** (installed automatically if you followed the previous steps).
- **kubectl** configured to your cluster.

### 2. Deploy the Application
```bash
kubectl apply -k .
```

### 3. Setup Monitoring (Prometheus + Adapter)
Run the provided setup script to install Prometheus and the adapter into the `hpa-custom` namespace:
```bash
chmod +x setup-monitoring.sh
./setup-monitoring.sh
```

## Test

### 1. Monitor the Metric Emitter
Check the logs to see the simulated metric value changing:
```bash
kubectl logs -l app=metric-emitter -n hpa-custom -c emitter -f
```

You can also verify the HTTP output directly (the `.txt` extension ensures the correct `Content-Type` for Prometheus):
```bash
kubectl run -i --rm --restart=Never debug-emitter -n hpa-custom --image=curlimages/curl -- curl -v "http://metric-emitter.hpa-custom.svc.cluster.local:8080/metrics.txt"
```

### 2. Verify Custom Metrics API
Once the adapter is running and Prometheus has scraped the first data point (wait ~2-3 minutes), query the API:
```bash
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/hpa-custom/pods/*/custom_queue_length" | jq .
```

### 3. Monitor the HPA
Watch how the HPA responds to the metric values:
```bash
kubectl get hpa sample-app-hpa -n hpa-custom -w
```

### 4. The Scaling Math
The HPA calculates desired replicas using this formula:
`desiredReplicas = ceil[currentReplicas * (currentMetricValue / targetMetricValue)]`

In my example I use the HPA target **AverageValue** and set it to 1. This creates a direct 1:1 mapping between the metric value and the number of pods, resulting in very **aggressive scaling**. If the queue length is 7, the HPA will target 7 replicas.

To flatten the scaling curve, you can use the target **Value** and set it to a higher than 1 value. For example, if we set the Value target to **5**:

If the `custom_queue_length` reaches 4, your `kubectl get hpa` output would look like this:

```text
NAME             REFERENCE               TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
sample-app-hpa   Deployment/sample-app   4/5       1         10        1          5m
```

#### 4.1. The TARGETS Column (`Current / Target`)
- **Current (4)**: The latest value fetched from the Custom Metrics API (`custom_queue_length`).
- **Target (5)**: The threshold defined in the HPA manifest.

Using the formula:
`ceil[1 * (4 / 5)] = ceil[0.8] = 1`. 
The HPA will **not** scale up yet.

#### 4.2. When Scale-Up Happens
Scaling occurs as soon as the ratio exceeds 1.0:
- If value = **6**: `ceil[1 * (6 / 5)] = ceil[1.2] = 2` replicas.
- If value = **10**: `ceil[1 * (10 / 5)] = ceil[2.0] = 2` replicas.

#### 4.3. Scale-Down Protection (Stabilization Window)
If the metric value drops (e.g., from `10` to `2`), the `TARGETS` will update immediately (`2/5`), but the `REPLICAS` will stay high for a while.

This is controlled by the **behavior** policy in `04-hpa.yaml`:
- **Stabilization Window**: Configured for **60s**. The HPA waits to ensure the metrics are consistently low before removing pods, preventing "thrashing".
- **Capped Reduction**: Using `selectPolicy: Min`, the HPA only removes the **smaller** of:
    - 30% of the current fleet.
    - 3 pods.
- This ensures a steady, granular scale-down even if the metrics drop by 90% in one scrape.

You can see a detailed audit of these decisions by describing the HPA:
```bash
kubectl describe hpa sample-app-hpa -n hpa-custom
```

## Files

| File | Description |
|------|-------------|
| `00-namespace.yaml` | Dedicated `hpa-custom` namespace |
| `01-deployment-app.yaml` | The application to be scaled |
| `02-configmap-metric-emitter.yaml` | Script that simulates and serves the metric via HTTP |
| `03-deployment-metric-emitter.yaml` | Emitter pod and Service with Prometheus annotations |
| `04-hpa.yaml` | HPA configuration targeting `custom_queue_length` |
| `05-prometheus-adapter-values.yaml` | Configuration for mapping the metric in the Adapter |
| `setup-monitoring.sh` | Script to automate Helm installations |
| `kustomization.yaml` | Kustomize configuration |
