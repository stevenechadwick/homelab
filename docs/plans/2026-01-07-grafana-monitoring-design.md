# Grafana Monitoring Dashboard Suite Design

## Goals

- **Capacity planning**: Understand resource usage trends to know when to upgrade
- **At-a-glance visibility**: See that everything is healthy quickly

## Dashboard Organization

```
Grafana
├── Home Dashboard (overview with drill-down links)
├── Cluster/
│   ├── Kubernetes Overview
│   ├── Node Resources (Node Exporter Full)
│   └── Namespace Usage
├── Infrastructure/
│   ├── Traefik
│   ├── Longhorn Storage
│   ├── MetalLB
│   └── CoreDNS
└── Apps/
    ├── ArgoCD
    ├── Authelia
    ├── Gitea
    ├── Media Services
    └── Investment Bot
```

## Dashboard Sources

### Community Dashboards (import & customize)

| Dashboard | Grafana ID | Notes |
|-----------|------------|-------|
| Node Exporter Full | 1860 | Gold standard for node metrics |
| Kubernetes Overview | 15661 | Cluster-wide view from kube-state-metrics |
| Longhorn | 13032 | Official Longhorn dashboard |
| CoreDNS | 14981 | Detailed DNS metrics |
| ArgoCD | 14584 | Application sync status & health |
| Traefik | 17346 | Request rates, latency, errors |

### Custom Dashboards

| Dashboard | Reason |
|-----------|--------|
| Home Overview | Tailored to specific services in this homelab |
| Authelia | No good community dashboard available |
| Gitea | Community options are sparse |
| Media Services | Enhance existing basic dashboard |
| Namespace Usage | Tailored capacity planning view |
| Investment Bot | Custom app metrics |

## New ServiceMonitors

### Gitea
- Endpoint: `/metrics` (needs enabling in Gitea config)
- Metrics: `gitea_users`, `gitea_repositories`, `gitea_issues`, etc.

### Authelia
- Endpoint: `/metrics` (exposed by default)
- Metrics: `authelia_authentication_*`, `authelia_request_duration_*`, etc.

### ArgoCD
- Multiple components: argocd-server, argocd-repo-server, argocd-application-controller
- Metrics: sync status, git operations, API metrics

### Investment Bot
- Endpoint: `/metrics` on port 9090 (requires code changes to bot)
- Requires: Service to expose metrics port
- Metrics: Node.js process metrics + custom Discord bot metrics

## Investment Bot Metrics Implementation

The bot needs code changes to expose metrics:

```typescript
import { collectDefaultMetrics, Registry, Counter, Histogram } from 'prom-client';

const register = new Registry();
collectDefaultMetrics({ register });

// Custom metrics
const commandsTotal = new Counter({
  name: 'discord_commands_total',
  help: 'Total commands processed',
  labelNames: ['command', 'status'],
  registers: [register],
});

// Express endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

## Files to Create

### Dashboards (ConfigMaps with `grafana_dashboard: "1"` label)

| File | Purpose |
|------|---------|
| `kubernetes/monitoring/dashboards/home-dashboard.yaml` | Overview with health grid |
| `kubernetes/monitoring/dashboards/node-exporter.yaml` | Community dashboard 1860 |
| `kubernetes/monitoring/dashboards/kubernetes-overview.yaml` | Community dashboard 15661 |
| `kubernetes/monitoring/dashboards/longhorn-full.yaml` | Community dashboard 13032 |
| `kubernetes/monitoring/dashboards/coredns-full.yaml` | Community dashboard 14981 |
| `kubernetes/monitoring/dashboards/argocd.yaml` | Community dashboard 14584 |
| `kubernetes/monitoring/dashboards/traefik-full.yaml` | Community dashboard 17346 |
| `kubernetes/monitoring/dashboards/authelia.yaml` | Custom |
| `kubernetes/monitoring/dashboards/gitea.yaml` | Custom |
| `kubernetes/monitoring/dashboards/namespace-usage.yaml` | Custom |
| `kubernetes/monitoring/dashboards/investment-bot.yaml` | Custom |

### ServiceMonitors

| File | Purpose |
|------|---------|
| `kubernetes/monitoring/servicemonitor-gitea.yaml` | Scrape Gitea metrics |
| `kubernetes/monitoring/servicemonitor-authelia.yaml` | Scrape Authelia metrics |
| `kubernetes/monitoring/servicemonitor-argocd.yaml` | Scrape ArgoCD metrics |
| `kubernetes/monitoring/servicemonitor-investment-bot.yaml` | Scrape bot metrics |

### Supporting Files

| File | Purpose |
|------|---------|
| `kubernetes/monitoring/investment-bot-service.yaml` | Expose bot metrics port |
| `docs/monitoring-new-apps.md` | Guide for adding metrics to future apps |

## Grafana Folder Configuration

Update `kubernetes/monitoring/kube-prometheus-stack/values.yaml` to configure dashboard folder provisioning based on ConfigMap annotations.

## Pattern for Future Apps

To add Prometheus metrics to any new app:

1. **Add metrics endpoint** - Use appropriate Prometheus client library
2. **Expose via Service** - Kubernetes Service with metrics port
3. **Create ServiceMonitor** - Points Prometheus at the service
4. **Create Dashboard** - ConfigMap with `grafana_dashboard: "1"` label

Template ServiceMonitor:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: <app-name>
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames: [<app-namespace>]
  selector:
    matchLabels:
      app: <app-name>
  endpoints:
    - port: metrics
      path: /metrics
      interval: 30s
```
