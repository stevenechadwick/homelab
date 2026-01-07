# Gitea + CI/CD + Container Registry Design

**Date:** 2026-01-06
**Status:** Approved
**Goal:** Self-hosted git platform with CI/CD pipelines and container registry, fully integrated into the homelab ecosystem.

## Summary

Deploy Gitea with its built-in container registry and Gitea Actions for CI/CD. Use Kaniko for rootless container image builds. Integrate with existing Authelia SSO for web access while using Gitea accounts for git/registry operations.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Homelab Cluster                          │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │   Gitea      │    │  Gitea       │    │   Your Apps      │  │
│  │  (git repos) │───▶│  Actions     │───▶│  (deployed via   │  │
│  │  + Registry  │    │  Runner      │    │   ArgoCD)        │  │
│  └──────────────┘    └──────────────┘    └──────────────────┘  │
│         │                   │                    ▲              │
│         │                   │ Kaniko builds      │              │
│         │                   ▼                    │              │
│         │            ┌──────────────┐            │              │
│         └───────────▶│  Container   │────────────┘              │
│                      │  Registry    │   ArgoCD pulls images     │
│                      │  (in Gitea)  │                           │
│                      └──────────────┘                           │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐                          │
│  │  Authelia    │    │   ArgoCD     │◀── github.com/homelab    │
│  │  (web auth)  │    │  (GitOps)    │    (infra source)        │
│  └──────────────┘    └──────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

**Workflow for new apps:**
1. Push code to Gitea repo
2. Gitea Actions triggers, runner picks up job
3. Kaniko builds image, pushes to Gitea's container registry
4. ArgoCD detects new image tag, deploys to cluster

**Key URLs:**
- `gitea.homelab.local` - Web UI (Authelia protected)
- `gitea.homelab.local/owner/repo` - Container images
- `git@gitea.homelab.local:owner/repo.git` - SSH clone

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Container Registry | Gitea built-in | Single service, zero extra setup, images alongside code |
| Storage | Longhorn (20Gi) | Replicated, sufficient for <50GB usage |
| Image Building | Kaniko | No privileged containers, no Docker daemon needed |
| Web Auth | Authelia (existing) | SSO with other homelab services |
| Git Auth | Gitea accounts + SSH keys | Git CLI doesn't support OIDC, practical approach |
| SSH Routing | Traefik IngressRouteTCP | Clean URLs via existing LoadBalancer |
| GitHub Migration | Keep homelab on GitHub | Disaster recovery bootstrap, external source of truth |

## Kubernetes Components

**Namespace:** `gitea`

### Gitea Server
- Image: `gitea/gitea:latest` (ARM64 compatible)
- Single replica
- PVC: `gitea-data` (20Gi, Longhorn) - repos, registry blobs, SQLite
- Ports: 3000 (HTTP), 22 (SSH)

### Gitea Actions Runner
- Image: `gitea/act_runner:latest`
- 1-2 replicas
- Registers with Gitea on startup via token
- Optional cache PVC (5Gi)

### Services
- `gitea`: ClusterIP, port 3000
- `gitea-ssh`: ClusterIP, port 22

### Ingress
- IngressRoute: `gitea.homelab.local` → port 3000, with Authelia middleware
- IngressRouteTCP: SSH entrypoint → port 22

### Secrets (SealedSecrets)
- Gitea admin credentials
- Runner registration token
- Internal service token

### Certificate
- `gitea-homelab-tls` via cert-manager

## Traefik Configuration

Add SSH entrypoint to Traefik via HelmChartConfig:

```yaml
# kubernetes/infrastructure/traefik/traefik-config.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |
    ports:
      ssh:
        port: 22
        expose:
          default: true
        exposedPort: 22
        protocol: TCP
```

## Gitea Configuration

Key settings in `app.ini` (via ConfigMap):

```ini
[server]
DOMAIN = gitea.homelab.local
ROOT_URL = https://gitea.homelab.local/
SSH_DOMAIN = gitea.homelab.local

[packages]
ENABLED = true

[actions]
ENABLED = true
DEFAULT_ACTIONS_URL = https://github.com
```

## Example CI/CD Workflow

`.gitea/workflows/build.yaml`:

```yaml
name: Build and Push
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: gcr.io/kaniko-project/executor:debug
    steps:
      - uses: actions/checkout@v4
      - run: |
          /kaniko/executor \
            --context . \
            --dockerfile Dockerfile \
            --destination gitea.homelab.local/${{ github.repository }}:${{ github.sha }}
```

## File Structure

```
kubernetes/apps/gitea/
├── namespace.yaml
├── deployment.yaml          # Gitea server
├── runner-deployment.yaml   # Gitea Actions runner
├── service.yaml             # ClusterIP for HTTP
├── service-ssh.yaml         # ClusterIP for SSH
├── ingress.yaml             # IngressRoute with Authelia
├── ingress-ssh.yaml         # IngressRouteTCP for SSH
├── pvc.yaml                 # Longhorn storage claims
├── configmap.yaml           # Gitea app.ini overrides
├── sealed-secret.yaml       # Admin creds, tokens
└── certificate.yaml         # TLS cert

kubernetes/infrastructure/traefik/
└── traefik-config.yaml      # Add SSH entrypoint (new/modified)
```

## Verification Checklist

1. [ ] Gitea web UI accessible at `https://gitea.homelab.local`
2. [ ] Authelia SSO redirect works
3. [ ] SSH test: `ssh -T git@gitea.homelab.local` succeeds
4. [ ] Container registry login: `docker login gitea.homelab.local`
5. [ ] Actions runner shows "Online" in Gitea admin
6. [ ] End-to-end: push repo with workflow, image appears in Packages

## Future Considerations

- Add Prometheus ServiceMonitor for Gitea metrics
- Runner autoscaling with KEDA if build queue grows
- Mirror select repos to GitHub for public visibility
