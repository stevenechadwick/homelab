# Homelab Infrastructure

Production-grade Kubernetes homelab running on TuringPi 2 with GitOps automation.

## 🏗️ Repository Structure

```
├── ansible/              # Infrastructure automation
│   ├── inventory/        # Host definitions
│   └── playbooks/        # K3s installation/management
├── kubernetes/           # Kubernetes manifests (GitOps)
│   ├── infrastructure/   # Core infrastructure (MetalLB, cert-manager, Longhorn)
│   ├── apps/            # Applications (media stack, homepage, ArgoCD)
│   ├── monitoring/      # Prometheus, Grafana stack
│   └── clusters/        # Cluster-specific configurations
├── scripts/             # Utility scripts
├── manifests/           # Standalone manifests
└── docs/                # Setup documentation
```

## 🚀 Quick Start

### 1. Infrastructure Setup
```bash
# Install K3s cluster
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/04-install-k3s.yml

# Get kubeconfig
ansible-playbook -i inventory/hosts.yml playbooks/01-get-kubeconfig.yml
```

### 2. GitOps Setup
```bash
# Create GitHub repository secret
./scripts/create-github-secret.sh

# Deploy ArgoCD applications
kubectl apply -f kubernetes/argocd-repo-config.yaml
```

## 🌐 Access URLs

**Main Dashboard**: https://homepage.homelab.local

### Management
- **ArgoCD**: https://argocd.homelab.local
- **Rancher**: https://rancher.homelab.local  
- **Grafana**: https://grafana.homelab.local

### Media Stack
- **Plex**: https://plex.homelab.local
- **Radarr**: https://radarr.homelab.local
- **Sonarr**: https://sonarr.homelab.local
- **Prowlarr**: https://prowlarr.homelab.local
- **qBittorrent**: https://qbittorrent.homelab.local

## 🔧 Components

- **K3s v1.28.8+k3s1** - Lightweight Kubernetes
- **MetalLB** - LoadBalancer for bare metal
- **Traefik** - Ingress controller with TLS
- **Longhorn** - Distributed storage
- **ArgoCD** - GitOps continuous deployment
- **Prometheus/Grafana** - Monitoring stack

## 📚 Documentation

- [Setup Guide](docs/setup-argocd-gitops.md)
- [Infrastructure Details](documentation/infrastructure.md)
- [Services Overview](documentation/services.md)

## 🔒 Security

- GitHub PAT stored as Kubernetes secret
- TLS certificates via cert-manager
- RBAC and namespace isolation
- Git-ignored credentials and documentation