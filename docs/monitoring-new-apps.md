# Adding Prometheus Monitoring to New Applications

This guide explains how to add Prometheus metrics monitoring to applications deployed in this homelab Kubernetes cluster.

## Overview

### Monitoring Stack

This cluster uses **kube-prometheus-stack** which provides:

- **Prometheus**: Time-series database for collecting and storing metrics
- **Grafana**: Visualization and dashboarding
- **Alertmanager**: Alert routing and notification (optional)

The stack is deployed in the `monitoring` namespace via the Helm chart at `kubernetes/monitoring/kube-prometheus-stack/`.

### How Auto-Discovery Works

Prometheus discovers metrics endpoints through **ServiceMonitors**, which are custom Kubernetes resources. The key requirement is the label:

```yaml
release: kube-prometheus-stack
```

This label tells Prometheus to scrape the target defined in the ServiceMonitor.

For Grafana dashboards, the sidecar watches for ConfigMaps with the label:

```yaml
grafana_dashboard: "1"
```

Dashboards are automatically loaded and can be organized into folders using the annotation:

```yaml
grafana_folder: Apps
```

---

## Adding Metrics to Your Application

Your application must expose a `/metrics` endpoint that returns Prometheus-formatted metrics.

### Node.js / TypeScript

Use the `prom-client` library:

```bash
npm install prom-client
```

```typescript
import express from 'express';
import { Registry, collectDefaultMetrics, Counter, Histogram } from 'prom-client';

const app = express();
const register = new Registry();

// Collect default Node.js metrics (CPU, memory, event loop, etc.)
collectDefaultMetrics({ register });

// Custom metrics
const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'path', 'status'],
  registers: [register],
});

const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'path'],
  buckets: [0.1, 0.5, 1, 2, 5],
  registers: [register],
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

### Python

Use the `prometheus-client` library:

```bash
pip install prometheus-client
```

```python
from prometheus_client import Counter, Histogram, generate_latest, REGISTRY, CollectorRegistry
from flask import Flask, Response

app = Flask(__name__)

# Custom metrics
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency',
    ['method', 'endpoint'],
    buckets=[0.1, 0.5, 1.0, 2.0, 5.0]
)

@app.route('/metrics')
def metrics():
    return Response(generate_latest(REGISTRY), mimetype='text/plain')
```

### Go

Use the `prometheus/client_golang` library:

```go
package main

import (
    "net/http"

    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "path", "status"},
    )

    httpRequestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "path"},
    )
)

func init() {
    prometheus.MustRegister(httpRequestsTotal)
    prometheus.MustRegister(httpRequestDuration)
}

func main() {
    http.Handle("/metrics", promhttp.Handler())
    http.ListenAndServe(":8080", nil)
}
```

### Standard Metrics to Include

At minimum, include these metrics for HTTP services:

| Metric | Type | Description |
|--------|------|-------------|
| `http_requests_total` | Counter | Total requests by method, path, status |
| `http_request_duration_seconds` | Histogram | Request latency distribution |
| `up` | Gauge | Application health (auto-provided) |

For background workers or async processes:

| Metric | Type | Description |
|--------|------|-------------|
| `jobs_processed_total` | Counter | Total jobs processed |
| `jobs_failed_total` | Counter | Failed job count |
| `job_duration_seconds` | Histogram | Job processing time |
| `queue_depth` | Gauge | Current queue size |

---

## Creating a ServiceMonitor

The ServiceMonitor tells Prometheus where to scrape metrics from your application.

### Template

Create a file at `kubernetes/monitoring/servicemonitor-<app-name>.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: <app-name>
  namespace: monitoring
  labels:
    app: <app-name>
    release: kube-prometheus-stack  # Required for Prometheus to discover this
spec:
  selector:
    matchLabels:
      app: <app-name>  # Must match your Service's labels
  endpoints:
  - port: metrics      # Name of the port in your Service
    interval: 30s
    path: /metrics
    scheme: http
  namespaceSelector:
    matchNames:
    - <app-namespace>  # Namespace where your app runs
```

### Real Examples from This Repo

**Authelia** (`kubernetes/monitoring/servicemonitor-authelia.yaml`):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: authelia
  namespace: monitoring
  labels:
    app: authelia
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: authelia
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    scheme: http
  namespaceSelector:
    matchNames:
    - authelia
```

**Traefik** (`kubernetes/monitoring/servicemonitor-traefik.yaml`):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: traefik
  namespace: kube-system
  labels:
    app: traefik
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: traefik
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    scheme: http
  namespaceSelector:
    matchNames:
    - kube-system
```

### Key Points

1. **`release: kube-prometheus-stack`** label is required
2. The `selector.matchLabels` must match labels on your Kubernetes Service
3. The `port` must match the port name in your Service spec
4. The `namespaceSelector` specifies where to find the target Service

---

## Creating a Service (if needed)

If your application does not already have a Kubernetes Service exposing the metrics port, create one.

### When You Need a Metrics Service

- Your main Service only exposes the application port (e.g., 80/443)
- Metrics are on a different port
- You want to separate metrics traffic from application traffic

### Template

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <app-name>-metrics
  namespace: <app-namespace>
  labels:
    app: <app-name>
spec:
  selector:
    app: <app-name>  # Must match your Pod's labels
  ports:
  - name: metrics
    port: 9090       # Common metrics port
    targetPort: 9090
```

Many applications expose metrics on their main port at `/metrics`, so a separate Service may not be needed.

---

## Creating a Grafana Dashboard

Dashboards are stored as JSON in ConfigMaps and auto-loaded by Grafana's sidecar.

### ConfigMap Structure

Create a file at `kubernetes/monitoring/dashboards/<app-name>.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <app-name>-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"       # Required for auto-discovery
  annotations:
    grafana_folder: Apps         # Optional: organize into folder
data:
  <app-name>.json: |
    {
      "annotations": { "list": [] },
      "description": "Description of your dashboard",
      "editable": true,
      "id": null,
      "panels": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "title": "Requests per Second",
          "type": "timeseries",
          "gridPos": { "h": 8, "w": 12, "x": 0, "y": 0 },
          "targets": [
            {
              "expr": "rate(http_requests_total{job=\"<app-name>\"}[5m])",
              "legendFormat": "{{method}} {{path}}"
            }
          ]
        }
      ],
      "schemaVersion": 38,
      "tags": ["<app-name>"],
      "title": "<App Name> Dashboard",
      "uid": "<app-name>-dashboard"
    }
```

### Folder Organization

Use the `grafana_folder` annotation to organize dashboards:

| Folder | Use For |
|--------|---------|
| `Apps` | Application-specific dashboards |
| `Infrastructure` | Traefik, Longhorn, CoreDNS, etc. |
| `Cluster` | Node metrics, Kubernetes overview |

### Tips for Dashboard Creation

1. **Start in Grafana UI**: Build your dashboard interactively, then export as JSON
2. **Use the Prometheus datasource UID**: Set `"uid": "prometheus"` for portability
3. **Set `"id": null`**: Grafana assigns IDs automatically
4. **Use unique UIDs**: The `uid` field must be unique across all dashboards
5. **Add useful tags**: Makes dashboards easier to find

### Finding Community Dashboards

Many applications have pre-built dashboards available:

1. Visit [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
2. Search for your application
3. Download the JSON or note the dashboard ID
4. Import into your ConfigMap

Popular dashboard IDs:
- Node Exporter: 1860
- Kubernetes cluster: 6417
- Traefik: 4475

---

## Quick Reference Checklist

Use this checklist when adding monitoring to a new application:

### Application Setup

- [ ] Add metrics library to your application (`prom-client`, `prometheus-client`, etc.)
- [ ] Expose `/metrics` endpoint on your application
- [ ] Include standard metrics: `http_requests_total`, `http_request_duration_seconds`
- [ ] Test locally: `curl http://localhost:<port>/metrics`

### Kubernetes Resources

- [ ] Ensure your app's Service has a named port for metrics
- [ ] Service has appropriate labels for ServiceMonitor selector

### ServiceMonitor

- [ ] Create `kubernetes/monitoring/servicemonitor-<app-name>.yaml`
- [ ] Include `release: kube-prometheus-stack` label
- [ ] Set correct `selector.matchLabels` to match your Service
- [ ] Set correct `namespaceSelector.matchNames`
- [ ] Verify port name matches Service port name

### Dashboard (Optional)

- [ ] Create `kubernetes/monitoring/dashboards/<app-name>.yaml`
- [ ] Include `grafana_dashboard: "1"` label
- [ ] Add `grafana_folder: Apps` annotation
- [ ] Set unique `uid` in dashboard JSON
- [ ] Test dashboard in Grafana

### Verification

- [ ] Apply resources: `kubectl apply -f kubernetes/monitoring/`
- [ ] Check Prometheus targets: Status > Targets in Prometheus UI
- [ ] Verify metrics in Grafana Explore
- [ ] Dashboard loads and displays data

---

## Troubleshooting

### Prometheus not scraping my app

1. Check ServiceMonitor exists: `kubectl get servicemonitor -n monitoring`
2. Verify the `release: kube-prometheus-stack` label is present
3. Check selector matches your Service labels
4. Verify the port name matches

### Dashboard not appearing in Grafana

1. Verify ConfigMap has `grafana_dashboard: "1"` label
2. Check ConfigMap is in `monitoring` namespace
3. Validate JSON syntax (use a JSON validator)
4. Check Grafana sidecar logs: `kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana-sc-dashboard`

### Metrics endpoint returning errors

1. Test locally: `kubectl port-forward svc/<app-name> 9090:9090 -n <namespace>`
2. Then: `curl http://localhost:9090/metrics`
3. Check application logs for errors

---

## File Locations Reference

| Resource Type | Location |
|--------------|----------|
| ServiceMonitors | `kubernetes/monitoring/servicemonitor-*.yaml` |
| Dashboards | `kubernetes/monitoring/dashboards/*.yaml` |
| Prometheus config | `kubernetes/monitoring/kube-prometheus-stack/values.yaml` |
