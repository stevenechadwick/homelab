# Home Automation & Productivity Suite Design

**Date:** 2026-01-08
**Status:** Approved

## Overview

Add a home automation and productivity suite to the homelab cluster:

- **Home Assistant** - Central smart home hub
- **Actual Budget** - Self-hosted budgeting application
- **Mealie** - Recipe management and meal planning

## Architecture

### Namespace & URLs

All services deployed to new `home` namespace:

| Service | URL | Purpose |
|---------|-----|---------|
| Home Assistant | https://assistant.homelab.local | Smart home hub |
| Actual Budget | https://budget.homelab.local | Budgeting |
| Mealie | https://mealie.homelab.local | Recipes & meal planning |

### Network Flow

```
Internet/LAN → Traefik (192.168.87.10) → Authelia middleware → Apps
                                                              ├── Home Assistant ←→ Smart Devices
                                                              ├── Actual Budget
                                                              └── Mealie
```

### Storage

All services use Longhorn PVCs:

| Service | Size | Contents |
|---------|------|----------|
| Home Assistant | 5Gi | Config, database, recordings |
| Actual Budget | 1Gi | SQLite budget files |
| Mealie | 2Gi | Recipes, images, database |

## Home Assistant

### Purpose

Centralize control of smart home ecosystem with local-first operation.

### Device Integrations

| Device | Integration | Notes |
|--------|-------------|-------|
| Google Home speakers/screens | Google Cast | Media control, TTS announcements |
| Kasa lights & switches | TP-Link Kasa | Full local control (no cloud required) |
| Govee lights | Govee (via HACS) | Cloud API initially, some support local |
| Nest Protect (fire detectors) | Google Nest | Cloud API (Google requirement) |
| Nest cameras & doorbell | Google Nest | Cloud API, can display streams in dashboards |

### Capabilities

- Unified dashboard for all devices
- Cross-ecosystem automations
- Presence detection (phone-based or device-based)
- Historical data tracking

### Deployment Details

- **Image:** `ghcr.io/home-assistant/home-assistant:stable`
- **Storage:** 5Gi Longhorn PVC
- **Networking:** Host network required for mDNS device discovery
- **Add-ons:** HACS (Home Assistant Community Store) for additional integrations

## Actual Budget

### Purpose

Privacy-focused envelope budgeting without cloud dependency.

### Features

- Envelope budgeting methodology
- Optional bank sync (GoCardless/SimpleFIN) or manual CSV import
- Multi-device access via web app
- SQLite-based, fully self-contained

### Deployment Details

- **Image:** `actualbudget/actual-server:latest`
- **Storage:** 1Gi Longhorn PVC
- **Port:** 5006
- **Database:** Built-in SQLite (no external DB)

## Mealie

### Purpose

Centralized recipe storage with meal planning and grocery list generation.

### Features

- Recipe import from URLs (auto-scrape)
- Meal planning calendar
- Shopping list generation from meal plans
- Recipe scaling
- Multi-user support

### Deployment Details

- **Image:** `hkotel/mealie:latest`
- **Storage:** 2Gi Longhorn PVC
- **Port:** 9000
- **Database:** Built-in SQLite

## Authentication

### Authelia Integration

All services protected by Authelia via Traefik's `forwardAuth` middleware.

**Flow:**
```
Request → Traefik → authelia middleware → App
                         ↓
                  Authelia validates session
                         ↓
                  ✓ Valid: Forward to app
                  ✗ Invalid: Redirect to login
```

### Per-App Authentication

| App | Authelia Role | App's Built-in Auth |
|-----|---------------|---------------------|
| Home Assistant | Gate access | Keep enabled - handles permissions/users internally |
| Actual Budget | Gate access | Keep enabled - budget files have passwords |
| Mealie | Gate + header auth | Can auto-login from Authelia headers |

### Configuration Required

- Add access control rules to Authelia configuration
- Create IngressRoute per app with Authelia middleware
- Optionally configure Mealie header authentication

## Monitoring

### Home Assistant (Full Monitoring)

- Enable built-in Prometheus exporter
- Metrics: entity states, automation triggers, API latency, database size
- ServiceMonitor for Prometheus scraping
- Grafana dashboard in "Home & Productivity" folder

### Actual Budget & Mealie (Uptime Probes)

- Basic uptime/availability probes
- Simple Grafana panels showing service health
- No custom metrics (low-criticality services)

## Deployment Order

1. **Create namespace and base structure**
   - Create `home` namespace
   - Set up `kubernetes/apps/home/` directory structure
   - Add to ArgoCD application configuration

2. **Deploy Mealie** (simplest)
   - Validate namespace, ingress, Authelia wiring

3. **Deploy Actual Budget**
   - Validate pattern before complex deployment

4. **Deploy Home Assistant** (most complex)
   - Requires host networking for device discovery
   - Post-deploy: configure integrations, install HACS

5. **Add monitoring**
   - ServiceMonitor for Home Assistant
   - Uptime probes for Actual and Mealie
   - Grafana dashboards

## Directory Structure

```
kubernetes/apps/home/
├── kustomization.yaml
├── namespace.yaml
├── home-assistant/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── pvc.yaml
│   ├── ingress.yaml
│   └── configmap.yaml
├── actual-budget/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── pvc.yaml
│   └── ingress.yaml
└── mealie/
    ├── kustomization.yaml
    ├── deployment.yaml
    ├── service.yaml
    ├── pvc.yaml
    └── ingress.yaml
```

## Post-Deployment Tasks

Outside scope of this design, but required after deployment:

- Configure Home Assistant integrations for each device type
- Set up automations in Home Assistant
- Install HACS and Govee integration
- Import recipes into Mealie
- Set up budget categories in Actual

## Verification Checklist

- [ ] `home` namespace created
- [ ] All three services deployed and healthy in ArgoCD
- [ ] Ingress routes working (assistant/budget/mealie.homelab.local)
- [ ] Authelia protecting all three services
- [ ] TLS certificates issued
- [ ] Home Assistant accessible and responsive
- [ ] Home Assistant discovers local devices (Kasa, Cast)
- [ ] Actual Budget accessible, can create budget
- [ ] Mealie accessible, can import recipe
- [ ] Prometheus scraping Home Assistant metrics
- [ ] Grafana dashboards displaying data
- [ ] Services added to Homepage dashboard
