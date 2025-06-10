# Overseerr Integration Guide

## Initial Setup (Post-Deployment)

After accessing Overseerr at `https://overseerr.homelab.local`, you'll need to configure:

### 1. Plex Integration
- **Plex Server URL**: `http://plex.media.svc.cluster.local:32400`
- **Plex Token**: Generate from Plex settings

### 2. Sonarr Integration
- **Sonarr URL**: `http://sonarr.media.svc.cluster.local:8989`
- **API Key**: Get from Sonarr settings → General → Security
- **Quality Profile**: Choose appropriate profile
- **Root Folder**: `/tv` (matches your media storage)

### 3. Radarr Integration
- **Radarr URL**: `http://radarr.media.svc.cluster.local:7878`
- **API Key**: Get from Radarr settings → General → Security
- **Quality Profile**: Choose appropriate profile
- **Root Folder**: `/movies` (matches your media storage)

### 4. Authentication
- Overseerr is protected by Authelia SSO
- Users will authenticate via `https://auth.homelab.local`
- Configure user permissions within Overseerr after setup

## Monitoring
- **Prometheus**: Metrics available at `/api/v1/status`
- **Grafana**: Dashboard auto-deployed for monitoring
- **Logs**: Available via `kubectl logs -n media deployment/overseerr`

## Homepage Integration
- Card added to media section
- Icon: overseerr.png (ensure icon exists in homepage assets)
- Direct link to SSO-protected interface