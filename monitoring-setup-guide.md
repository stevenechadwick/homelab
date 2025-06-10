# Media Services Monitoring Setup Guide

## Current Status

### ✅ Working Monitoring
- **Plex**: ✅ Metrics collecting properly
- **Infrastructure**: ✅ CoreDNS, Traefik, Longhorn, MetalLB dashboards active

### ✅ Configured and Working
- **Radarr**: ✅ API key configured via Kubernetes secret, metrics collecting
- **Sonarr**: ✅ API key configured via Kubernetes secret, metrics collecting
- **Prowlarr**: ✅ API key configured via Kubernetes secret, metrics collecting
- **Plex**: ✅ Metrics collecting properly

### ⚠️ Minor Issues
- **qBittorrent**: ⚠️ Exporter configured but authentication failing (may need password verification)

### 📊 Dashboards Available
- **Media Services Overview**: Comprehensive dashboard (once API keys are configured)
- **Plex Monitoring**: ✅ Active
- **Infrastructure**: ✅ CoreDNS, Traefik, Longhorn, MetalLB

### 🔧 Quick Fix Commands
After updating API keys above, restart the exporters:
```bash
kubectl rollout restart deployment/exportarr-radarr -n monitoring
kubectl rollout restart deployment/exportarr-sonarr -n monitoring  
kubectl rollout restart deployment/exportarr-prowlarr -n monitoring
kubectl rollout restart deployment/qbittorrent-exporter -n monitoring
```

### 📈 Access Dashboards
- **Grafana**: https://grafana.homelab.local
- Look for "Media Services Overview" dashboard after API keys are configured

## Overseerr Note
Overseerr doesn't expose Prometheus metrics natively. It's monitored via HTTP status checks instead of detailed application metrics.