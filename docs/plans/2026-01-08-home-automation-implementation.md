# Home Automation & Productivity Suite Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy Home Assistant, Actual Budget, and Mealie to the homelab cluster with Authelia SSO, monitoring, and Homepage integration.

**Architecture:** Three containerized applications in a shared `home` namespace, each with Longhorn storage, Traefik ingress with Authelia middleware, and Prometheus monitoring for Home Assistant.

**Tech Stack:** Kubernetes manifests (no Helm), Traefik IngressRoutes, Authelia forwardAuth, Longhorn PVCs, cert-manager Certificates, Prometheus ServiceMonitors.

---

## Task 1: Create Home Namespace and Base Structure

**Files:**
- Create: `kubernetes/apps/home/namespace.yaml`
- Create: `kubernetes/apps/home/kustomization.yaml`
- Create: `kubernetes/apps/home/authelia-middleware.yaml`

**Step 1: Create the namespace file**

Create `kubernetes/apps/home/namespace.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: home
```

**Step 2: Create the Authelia middleware for the namespace**

Create `kubernetes/apps/home/authelia-middleware.yaml`:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: authelia
  namespace: home
spec:
  forwardAuth:
    address: http://authelia-simple.authelia.svc.cluster.local/api/verify?rd=https://auth.homelab.local
    trustForwardHeader: true
    authResponseHeaders:
      - Remote-User
      - Remote-Groups
      - Remote-Name
      - Remote-Email
```

**Step 3: Create the base kustomization file**

Create `kubernetes/apps/home/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - authelia-middleware.yaml
  - mealie/
  - actual-budget/
  - home-assistant/
```

**Step 4: Commit the base structure**

```bash
git add kubernetes/apps/home/
git commit -m "feat(home): add home namespace and Authelia middleware"
```

---

## Task 2: Deploy Mealie

**Files:**
- Create: `kubernetes/apps/home/mealie/namespace.yaml` (symlink placeholder)
- Create: `kubernetes/apps/home/mealie/kustomization.yaml`
- Create: `kubernetes/apps/home/mealie/pvc.yaml`
- Create: `kubernetes/apps/home/mealie/deployment.yaml`
- Create: `kubernetes/apps/home/mealie/service.yaml`
- Create: `kubernetes/apps/home/mealie/certificate.yaml`
- Create: `kubernetes/apps/home/mealie/ingress.yaml`

**Step 1: Create the mealie directory**

```bash
mkdir -p kubernetes/apps/home/mealie
```

**Step 2: Create the PVC**

Create `kubernetes/apps/home/mealie/pvc.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mealie-data
  namespace: home
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 2Gi
```

**Step 3: Create the deployment**

Create `kubernetes/apps/home/mealie/deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mealie
  namespace: home
  labels:
    app: mealie
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: mealie
  template:
    metadata:
      labels:
        app: mealie
    spec:
      containers:
      - name: mealie
        image: hkotel/mealie:latest
        ports:
        - name: http
          containerPort: 9000
        env:
        - name: TZ
          value: "America/New_York"
        - name: ALLOW_SIGNUP
          value: "false"
        - name: BASE_URL
          value: "https://mealie.homelab.local"
        - name: MAX_WORKERS
          value: "1"
        - name: WEB_CONCURRENCY
          value: "1"
        volumeMounts:
        - name: data
          mountPath: /app/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /api/app/about
            port: 9000
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /api/app/about
            port: 9000
          initialDelaySeconds: 10
          periodSeconds: 10
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: mealie-data
```

**Step 4: Create the service**

Create `kubernetes/apps/home/mealie/service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mealie
  namespace: home
  labels:
    app: mealie
spec:
  selector:
    app: mealie
  ports:
  - name: http
    port: 80
    targetPort: 9000
  type: ClusterIP
```

**Step 5: Create the certificate**

Create `kubernetes/apps/home/mealie/certificate.yaml`:
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: mealie-homelab-cert
  namespace: home
spec:
  secretName: mealie-homelab-tls
  issuerRef:
    name: homelab-ca-issuer
    kind: ClusterIssuer
  commonName: mealie.homelab.local
  dnsNames:
  - mealie.homelab.local
```

**Step 6: Create the ingress**

Create `kubernetes/apps/home/mealie/ingress.yaml`:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: mealie
  namespace: home
spec:
  entryPoints:
  - web
  - websecure
  routes:
  - match: Host(`mealie.homelab.local`)
    kind: Rule
    middlewares:
    - name: authelia
    services:
    - name: mealie
      port: 80
  tls:
    secretName: mealie-homelab-tls
```

**Step 7: Create the kustomization**

Create `kubernetes/apps/home/mealie/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: home

resources:
  - pvc.yaml
  - deployment.yaml
  - service.yaml
  - certificate.yaml
  - ingress.yaml
```

**Step 8: Commit Mealie**

```bash
git add kubernetes/apps/home/mealie/
git commit -m "feat(home): add Mealie recipe manager deployment"
```

---

## Task 3: Deploy Actual Budget

**Files:**
- Create: `kubernetes/apps/home/actual-budget/kustomization.yaml`
- Create: `kubernetes/apps/home/actual-budget/pvc.yaml`
- Create: `kubernetes/apps/home/actual-budget/deployment.yaml`
- Create: `kubernetes/apps/home/actual-budget/service.yaml`
- Create: `kubernetes/apps/home/actual-budget/certificate.yaml`
- Create: `kubernetes/apps/home/actual-budget/ingress.yaml`

**Step 1: Create the actual-budget directory**

```bash
mkdir -p kubernetes/apps/home/actual-budget
```

**Step 2: Create the PVC**

Create `kubernetes/apps/home/actual-budget/pvc.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: actual-data
  namespace: home
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
```

**Step 3: Create the deployment**

Create `kubernetes/apps/home/actual-budget/deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: actual-budget
  namespace: home
  labels:
    app: actual-budget
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: actual-budget
  template:
    metadata:
      labels:
        app: actual-budget
    spec:
      containers:
      - name: actual
        image: actualbudget/actual-server:latest
        ports:
        - name: http
          containerPort: 5006
        env:
        - name: TZ
          value: "America/New_York"
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "250m"
        livenessProbe:
          httpGet:
            path: /
            port: 5006
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 5006
          initialDelaySeconds: 10
          periodSeconds: 10
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: actual-data
```

**Step 4: Create the service**

Create `kubernetes/apps/home/actual-budget/service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: actual-budget
  namespace: home
  labels:
    app: actual-budget
spec:
  selector:
    app: actual-budget
  ports:
  - name: http
    port: 80
    targetPort: 5006
  type: ClusterIP
```

**Step 5: Create the certificate**

Create `kubernetes/apps/home/actual-budget/certificate.yaml`:
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: budget-homelab-cert
  namespace: home
spec:
  secretName: budget-homelab-tls
  issuerRef:
    name: homelab-ca-issuer
    kind: ClusterIssuer
  commonName: budget.homelab.local
  dnsNames:
  - budget.homelab.local
```

**Step 6: Create the ingress**

Create `kubernetes/apps/home/actual-budget/ingress.yaml`:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: actual-budget
  namespace: home
spec:
  entryPoints:
  - web
  - websecure
  routes:
  - match: Host(`budget.homelab.local`)
    kind: Rule
    middlewares:
    - name: authelia
    services:
    - name: actual-budget
      port: 80
  tls:
    secretName: budget-homelab-tls
```

**Step 7: Create the kustomization**

Create `kubernetes/apps/home/actual-budget/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: home

resources:
  - pvc.yaml
  - deployment.yaml
  - service.yaml
  - certificate.yaml
  - ingress.yaml
```

**Step 8: Commit Actual Budget**

```bash
git add kubernetes/apps/home/actual-budget/
git commit -m "feat(home): add Actual Budget deployment"
```

---

## Task 4: Deploy Home Assistant

**Files:**
- Create: `kubernetes/apps/home/home-assistant/kustomization.yaml`
- Create: `kubernetes/apps/home/home-assistant/pvc.yaml`
- Create: `kubernetes/apps/home/home-assistant/deployment.yaml`
- Create: `kubernetes/apps/home/home-assistant/service.yaml`
- Create: `kubernetes/apps/home/home-assistant/certificate.yaml`
- Create: `kubernetes/apps/home/home-assistant/ingress.yaml`

**Step 1: Create the home-assistant directory**

```bash
mkdir -p kubernetes/apps/home/home-assistant
```

**Step 2: Create the PVC**

Create `kubernetes/apps/home/home-assistant/pvc.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: home-assistant-config
  namespace: home
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 5Gi
```

**Step 3: Create the deployment**

Note: Home Assistant requires host network for mDNS device discovery (Kasa, Cast).

Create `kubernetes/apps/home/home-assistant/deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: home-assistant
  namespace: home
  labels:
    app: home-assistant
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: home-assistant
  template:
    metadata:
      labels:
        app: home-assistant
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: home-assistant
        image: ghcr.io/home-assistant/home-assistant:stable
        ports:
        - name: http
          containerPort: 8123
          hostPort: 8123
        env:
        - name: TZ
          value: "America/New_York"
        volumeMounts:
        - name: config
          mountPath: /config
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /
            port: 8123
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 8123
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        startupProbe:
          httpGet:
            path: /
            port: 8123
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 30
        securityContext:
          privileged: true
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: home-assistant-config
```

**Step 4: Create the service**

Create `kubernetes/apps/home/home-assistant/service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: home-assistant
  namespace: home
  labels:
    app: home-assistant
spec:
  selector:
    app: home-assistant
  ports:
  - name: http
    port: 80
    targetPort: 8123
  type: ClusterIP
```

**Step 5: Create the certificate**

Create `kubernetes/apps/home/home-assistant/certificate.yaml`:
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: assistant-homelab-cert
  namespace: home
spec:
  secretName: assistant-homelab-tls
  issuerRef:
    name: homelab-ca-issuer
    kind: ClusterIssuer
  commonName: assistant.homelab.local
  dnsNames:
  - assistant.homelab.local
```

**Step 6: Create the ingress**

Create `kubernetes/apps/home/home-assistant/ingress.yaml`:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: home-assistant
  namespace: home
spec:
  entryPoints:
  - web
  - websecure
  routes:
  - match: Host(`assistant.homelab.local`)
    kind: Rule
    middlewares:
    - name: authelia
    services:
    - name: home-assistant
      port: 80
  tls:
    secretName: assistant-homelab-tls
```

**Step 7: Create the kustomization**

Create `kubernetes/apps/home/home-assistant/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: home

resources:
  - pvc.yaml
  - deployment.yaml
  - service.yaml
  - certificate.yaml
  - ingress.yaml
```

**Step 8: Commit Home Assistant**

```bash
git add kubernetes/apps/home/home-assistant/
git commit -m "feat(home): add Home Assistant deployment with host networking"
```

---

## Task 5: Add Home Assistant Prometheus Monitoring

**Files:**
- Create: `kubernetes/monitoring/servicemonitor-home-assistant.yaml`

**Step 1: Create the ServiceMonitor**

Create `kubernetes/monitoring/servicemonitor-home-assistant.yaml`:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: home-assistant
  namespace: monitoring
  labels:
    app: home-assistant
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: home-assistant
  endpoints:
  - port: http
    interval: 30s
    path: /api/prometheus
    scheme: http
    bearerTokenSecret:
      name: home-assistant-token
      key: token
  namespaceSelector:
    matchNames:
    - home
```

Note: Home Assistant requires a long-lived access token for Prometheus. This will need to be created manually after Home Assistant is running:
1. Log into Home Assistant
2. Go to Profile → Long-Lived Access Tokens
3. Create a token named "prometheus"
4. Create the secret: `kubectl create secret generic home-assistant-token --from-literal=token=YOUR_TOKEN -n monitoring`

**Step 2: Commit the ServiceMonitor**

```bash
git add kubernetes/monitoring/servicemonitor-home-assistant.yaml
git commit -m "feat(monitoring): add Home Assistant ServiceMonitor"
```

---

## Task 6: Add Grafana Dashboard for Home & Productivity

**Files:**
- Create: `kubernetes/monitoring/dashboards/home-productivity.yaml`

**Step 1: Create the dashboard ConfigMap**

Create `kubernetes/monitoring/dashboards/home-productivity.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: home-productivity-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
  annotations:
    grafana_folder: "Home & Productivity"
data:
  home-productivity.json: |
    {
      "annotations": {
        "list": []
      },
      "description": "Home Automation and Productivity Services Overview",
      "editable": true,
      "fiscalYearStartMonth": 0,
      "graphTooltip": 0,
      "id": null,
      "links": [],
      "panels": [
        {
          "gridPos": { "h": 1, "w": 24, "x": 0, "y": 0 },
          "id": 1,
          "title": "Service Health",
          "type": "row"
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": {
            "defaults": {
              "color": { "mode": "thresholds" },
              "mappings": [
                { "options": { "0": { "color": "red", "index": 1, "text": "DOWN" }, "1": { "color": "green", "index": 0, "text": "UP" } }, "type": "value" }
              ],
              "thresholds": { "mode": "absolute", "steps": [{ "color": "red", "value": null }, { "color": "green", "value": 1 }] }
            }
          },
          "gridPos": { "h": 4, "w": 8, "x": 0, "y": 1 },
          "id": 2,
          "options": { "colorMode": "background", "graphMode": "none", "justifyMode": "center", "orientation": "auto", "reduceOptions": { "calcs": ["lastNotNull"], "fields": "", "values": false }, "textMode": "auto" },
          "targets": [{ "expr": "up{job=\"home-assistant\"}", "refId": "A" }],
          "title": "Home Assistant",
          "type": "stat"
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": {
            "defaults": {
              "color": { "mode": "thresholds" },
              "mappings": [
                { "options": { "0": { "color": "red", "index": 1, "text": "DOWN" }, "1": { "color": "green", "index": 0, "text": "UP" } }, "type": "value" }
              ],
              "thresholds": { "mode": "absolute", "steps": [{ "color": "red", "value": null }, { "color": "green", "value": 1 }] }
            }
          },
          "gridPos": { "h": 4, "w": 8, "x": 8, "y": 1 },
          "id": 3,
          "options": { "colorMode": "background", "graphMode": "none", "justifyMode": "center", "orientation": "auto", "reduceOptions": { "calcs": ["lastNotNull"], "fields": "", "values": false }, "textMode": "auto" },
          "targets": [{ "expr": "kube_deployment_status_replicas_available{deployment=\"actual-budget\",namespace=\"home\"}", "refId": "A" }],
          "title": "Actual Budget",
          "type": "stat"
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": {
            "defaults": {
              "color": { "mode": "thresholds" },
              "mappings": [
                { "options": { "0": { "color": "red", "index": 1, "text": "DOWN" }, "1": { "color": "green", "index": 0, "text": "UP" } }, "type": "value" }
              ],
              "thresholds": { "mode": "absolute", "steps": [{ "color": "red", "value": null }, { "color": "green", "value": 1 }] }
            }
          },
          "gridPos": { "h": 4, "w": 8, "x": 16, "y": 1 },
          "id": 4,
          "options": { "colorMode": "background", "graphMode": "none", "justifyMode": "center", "orientation": "auto", "reduceOptions": { "calcs": ["lastNotNull"], "fields": "", "values": false }, "textMode": "auto" },
          "targets": [{ "expr": "kube_deployment_status_replicas_available{deployment=\"mealie\",namespace=\"home\"}", "refId": "A" }],
          "title": "Mealie",
          "type": "stat"
        },
        {
          "gridPos": { "h": 1, "w": 24, "x": 0, "y": 5 },
          "id": 5,
          "title": "Home Assistant Metrics",
          "type": "row"
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "unit": "short" } },
          "gridPos": { "h": 6, "w": 8, "x": 0, "y": 6 },
          "id": 6,
          "options": { "colorMode": "value", "graphMode": "area", "justifyMode": "auto", "orientation": "auto", "reduceOptions": { "calcs": ["lastNotNull"], "fields": "", "values": false }, "textMode": "auto" },
          "targets": [{ "expr": "homeassistant_entity_available_count", "legendFormat": "Available Entities", "refId": "A" }],
          "title": "Available Entities",
          "type": "stat"
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "unit": "short" } },
          "gridPos": { "h": 6, "w": 8, "x": 8, "y": 6 },
          "id": 7,
          "options": { "colorMode": "value", "graphMode": "area", "justifyMode": "auto", "orientation": "auto", "reduceOptions": { "calcs": ["lastNotNull"], "fields": "", "values": false }, "textMode": "auto" },
          "targets": [{ "expr": "homeassistant_automation_triggered_count", "legendFormat": "Automations Triggered", "refId": "A" }],
          "title": "Automations Triggered",
          "type": "stat"
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "gridPos": { "h": 6, "w": 8, "x": 16, "y": 6 },
          "id": 8,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "single" } },
          "targets": [{ "expr": "rate(homeassistant_api_requests_total[5m])", "legendFormat": "API Requests/s", "refId": "A" }],
          "title": "API Request Rate",
          "type": "timeseries"
        },
        {
          "gridPos": { "h": 1, "w": 24, "x": 0, "y": 12 },
          "id": 9,
          "title": "Resource Usage",
          "type": "row"
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "unit": "bytes" } },
          "gridPos": { "h": 6, "w": 12, "x": 0, "y": 13 },
          "id": 10,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "multi" } },
          "targets": [
            { "expr": "container_memory_working_set_bytes{namespace=\"home\", container!=\"\"}", "legendFormat": "{{pod}}", "refId": "A" }
          ],
          "title": "Memory Usage by Pod",
          "type": "timeseries"
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "unit": "percentunit" } },
          "gridPos": { "h": 6, "w": 12, "x": 12, "y": 13 },
          "id": 11,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "multi" } },
          "targets": [
            { "expr": "rate(container_cpu_usage_seconds_total{namespace=\"home\", container!=\"\"}[5m])", "legendFormat": "{{pod}}", "refId": "A" }
          ],
          "title": "CPU Usage by Pod",
          "type": "timeseries"
        }
      ],
      "schemaVersion": 38,
      "tags": ["home", "productivity", "home-assistant", "mealie", "actual"],
      "templating": { "list": [] },
      "time": { "from": "now-6h", "to": "now" },
      "timepicker": {},
      "timezone": "",
      "title": "Home & Productivity",
      "uid": "home-productivity",
      "version": 1
    }
```

**Step 2: Commit the dashboard**

```bash
git add kubernetes/monitoring/dashboards/home-productivity.yaml
git commit -m "feat(monitoring): add Home & Productivity Grafana dashboard"
```

---

## Task 7: Update Homepage Dashboard

**Files:**
- Modify: `kubernetes/apps/homepage/configmap.yaml`

**Step 1: Add Home & Productivity section to Homepage**

Edit `kubernetes/apps/homepage/configmap.yaml` to add a new section in `settings.yaml` layout and `services.yaml`.

In `settings.yaml`, add to the layout section:
```yaml
      Home & Productivity:
        style: row
        columns: 3
```

In `services.yaml`, add a new section:
```yaml
    - Home & Productivity:
        - Home Assistant:
            href: https://assistant.homelab.local
            description: Smart Home Hub
            icon: home-assistant.png

        - Actual Budget:
            href: https://budget.homelab.local
            description: Personal Finance
            icon: actual.png

        - Mealie:
            href: https://mealie.homelab.local
            description: Recipe Manager
            icon: mealie.png
```

**Step 2: Commit Homepage update**

```bash
git add kubernetes/apps/homepage/configmap.yaml
git commit -m "feat(homepage): add Home & Productivity services section"
```

---

## Task 8: Push to Remote and Verify ArgoCD Sync

**Step 1: Push all commits**

```bash
git push origin master
```

**Step 2: Verify ArgoCD syncs the changes**

Run: `kubectl get applications -n argocd`
Expected: All applications show "Synced" and "Healthy"

**Step 3: Verify deployments in home namespace**

Run: `kubectl get pods -n home`
Expected: Three pods running (mealie, actual-budget, home-assistant)

**Step 4: Verify ingress routes**

Run: `kubectl get ingressroutes -n home`
Expected: Three IngressRoutes (mealie, actual-budget, home-assistant)

**Step 5: Test service access**

- Navigate to https://mealie.homelab.local - should redirect to Authelia, then show Mealie
- Navigate to https://budget.homelab.local - should redirect to Authelia, then show Actual
- Navigate to https://assistant.homelab.local - should redirect to Authelia, then show Home Assistant

---

## Task 9: Configure Home Assistant Prometheus Integration

This task requires manual steps after Home Assistant is running.

**Step 1: Access Home Assistant**

Navigate to https://assistant.homelab.local and complete initial setup.

**Step 2: Enable Prometheus integration**

Add to Home Assistant's `configuration.yaml` (via File Editor add-on or directly in PVC):

```yaml
prometheus:
```

**Step 3: Create long-lived access token**

1. Go to Profile (bottom left)
2. Scroll to "Long-Lived Access Tokens"
3. Create token named "prometheus"
4. Copy the token

**Step 4: Create the Kubernetes secret**

```bash
kubectl create secret generic home-assistant-token \
  --from-literal=token=YOUR_LONG_LIVED_TOKEN \
  -n monitoring
```

**Step 5: Verify Prometheus is scraping**

Navigate to https://prometheus.homelab.local and check Targets page for home-assistant.

---

## Verification Checklist

After completing all tasks, verify:

- [ ] `home` namespace exists: `kubectl get ns home`
- [ ] All pods running: `kubectl get pods -n home`
- [ ] All services accessible via browser through Authelia
- [ ] Certificates issued: `kubectl get certificates -n home`
- [ ] Homepage shows new services section
- [ ] Grafana dashboard "Home & Productivity" exists
- [ ] Home Assistant Prometheus metrics visible (after Task 9)
