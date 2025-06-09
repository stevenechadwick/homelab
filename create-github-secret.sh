#!/bin/bash

# GitHub Personal Access Token Setup for ArgoCD
# This script creates a Kubernetes secret for ArgoCD to access your GitHub repository

echo "Creating ArgoCD GitHub repository secret..."
echo "You will need to provide your GitHub Personal Access Token"
echo ""

# Prompt for GitHub PAT
read -s -p "Enter your GitHub Personal Access Token: " GITHUB_PAT
echo ""

if [ -z "$GITHUB_PAT" ]; then
    echo "Error: GitHub PAT cannot be empty"
    exit 1
fi

# Create the secret
kubectl create secret generic homelab-repo-secret \
  --from-literal=type=git \
  --from-literal=url=https://github.com/stevenechadwick/homelab.git \
  --from-literal=password="$GITHUB_PAT" \
  --from-literal=username=stevenechadwick \
  -n argocd

# Label it for ArgoCD
kubectl label secret homelab-repo-secret argocd.argoproj.io/secret-type=repository -n argocd

echo ""
echo "✅ GitHub repository secret created successfully!"
echo "ArgoCD can now access your GitHub repository for GitOps sync."
echo ""
echo "Next steps:"
echo "1. Apply ArgoCD applications: kubectl apply -f argocd-repo-config.yaml"
echo "2. Check ArgoCD UI: https://argocd.homelab.local"