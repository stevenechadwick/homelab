# ArgoCD GitOps Setup Instructions

## Prerequisites
1. Ensure your homelab repository is pushed to GitHub: `https://github.com/stevenechadwick/homelab.git`
2. Create a GitHub Personal Access Token with repository read access
3. ArgoCD should be accessible at: `https://argocd.homelab.local`

## Setup Steps

### 1. Create GitHub Personal Access Token (PAT)
1. Go to GitHub Settings: https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Set **Expiration**: 90 days (or longer as needed)
4. Select **Scopes**:
   - `repo` (Full control of private repositories)
   - OR just `public_repo` if your homelab repo is public
5. Click "Generate token"
6. **COPY THE TOKEN** - you won't see it again!

### 2. Create ArgoCD Repository Secret
**NEVER commit your PAT to git!** Use the secure script:

```bash
# Run the secure secret creation script
./create-github-secret.sh
# Enter your PAT when prompted (input is hidden)
```

### 3. Apply ArgoCD Applications
```bash
# Apply the ArgoCD applications (no secrets in this file)
kubectl apply -f kubernetes/argocd-repo-config.yaml
```

### 3. Access ArgoCD UI
- URL: https://argocd.homelab.local
- Username: admin
- Password: BW3NPuriPMGOLm6W

### 4. Verify Applications
The following ArgoCD Applications will be created:
- `homelab-infrastructure` - Core infrastructure components
- `homelab-apps` - Application stack (media, homepage, etc.)
- `homelab-monitoring` - Monitoring stack (Prometheus, Grafana)

### 5. GitOps Workflow
Once configured, any changes pushed to the GitHub repository will automatically sync to your cluster:

1. Make changes to manifests in `gitops-repo/`
2. Commit and push to GitHub
3. ArgoCD automatically syncs changes to cluster
4. Monitor sync status in ArgoCD UI

## Repository Structure
```
kubernetes/
├── infrastructure/     # Core infrastructure (MetalLB, cert-manager, etc.)
├── apps/              # Applications (media stack, homepage, etc.)
├── monitoring/        # Monitoring stack (Prometheus, Grafana)
└── clusters/          # Cluster-specific configurations
```

## Notes
- Auto-sync is enabled with `prune: true` and `selfHeal: true`
- Applications will create namespaces automatically
- All manifests should be committed to the GitHub repository
- Local documentation/ folder is git-ignored for security
- Run from scripts/ directory: `../scripts/create-github-secret.sh`