# PiHole DNS Service Setup

## Overview
PiHole provides DNS service with ad-blocking for your homelab network. It's configured with a LoadBalancer IP that your router can use as the primary DNS server.

## Network Configuration

### LoadBalancer Assignment
- **PiHole DNS IP**: `192.168.87.12` (LoadBalancer)
- **Web Interface**: https://pihole.homelab.local (requires DNS pointing to PiHole)
- **Admin Password**: `admin` (configurable in configmap)

### DNS Records Included
All `*.homelab.local` domains automatically resolve to Traefik at `192.168.87.10`:
- argocd.homelab.local
- rancher.homelab.local
- grafana.homelab.local
- plex.homelab.local
- radarr.homelab.local
- sonarr.homelab.local
- prowlarr.homelab.local
- qbittorrent.homelab.local
- pihole.homelab.local
- homepage.homelab.local

## Router Configuration

### Set Primary DNS Server
Configure your router to use PiHole as the primary DNS server:

1. **Access Router Admin**: Usually http://192.168.87.1
2. **Navigate to**: DHCP/DNS settings
3. **Set Primary DNS**: `192.168.87.12` (PiHole)
4. **Set Secondary DNS**: `1.1.1.1` or `8.8.8.8` (fallback)
5. **Apply Settings**: Restart router if required

### Alternative: Manual Device Configuration
If you can't configure router-wide DNS, set DNS manually on devices:
- **Primary DNS**: `192.168.87.12`
- **Secondary DNS**: `1.1.1.1`

## Deployment

### Deploy PiHole
```bash
# Apply all PiHole manifests
kubectl apply -f kubernetes/apps/pihole/

# Check deployment status
kubectl get pods -n pihole
kubectl get svc -n pihole
```

### Verify DNS Resolution
```bash
# Test local domain resolution  
nslookup homepage.homelab.local 192.168.87.12

# Test external domain resolution
nslookup google.com 192.168.87.12
```

## Web Interface Access
- **URL**: https://pihole.homelab.local
- **Username**: admin
- **Password**: admin (default)

### Features Available
- **Ad Blocking Lists**: Automatic updates
- **Query Log**: Real-time DNS queries
- **Network Overview**: Client activity
- **Local DNS Records**: Manage custom domains
- **Settings**: Upstream DNS servers, blocking lists

## Security Notes
- Default admin password is `admin` - change after first login
- PiHole runs with NET_ADMIN capability for DNS functionality
- Custom DNS records are stored in Kubernetes ConfigMap
- Persistent storage via Longhorn for settings and logs

## Troubleshooting

### DNS Not Working
1. Check PiHole pod status: `kubectl get pods -n pihole`
2. Check LoadBalancer IP: `kubectl get svc pihole-dns -n pihole`
3. Verify router DNS settings
4. Test direct DNS query: `dig @192.168.87.11 google.com`

### Web Interface Issues
1. Check ingress: `kubectl get ingressroute -n pihole`
2. Verify Traefik routing: Check Traefik dashboard at http://192.168.87.10:8080
3. Test direct access: http://192.168.87.11 (bypasses ingress)