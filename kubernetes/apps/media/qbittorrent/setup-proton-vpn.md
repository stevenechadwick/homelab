# Proton VPN Setup for qBittorrent

## Step 1: Get Proton VPN Configuration Files

1. **Log into your Proton VPN account**: https://account.protonvpn.com/
2. **Go to Downloads section**: https://account.protonvpn.com/downloads
3. **Download OpenVPN configuration files**:
   - Select "OpenVPN"
   - Choose a P2P-enabled server (look for servers marked with P2P)
   - Recommended P2P servers:
     - Netherlands servers (nl-*)
     - Iceland servers (is-*)
     - Switzerland servers (ch-*)
     - Sweden servers (se-*)
   - Download the `.ovpn` file for your chosen server

4. **Get additional files**:
   - Download `ca.crt` (Certificate Authority file)
   - Download `ta.key` (TLS Authentication key)

## Step 2: Update Configuration Files

1. **Update the secret file** (`proton-vpn-secret.yaml`):
   ```bash
   # Replace YOUR_PROTON_VPN_USERNAME and YOUR_PROTON_VPN_PASSWORD with your actual credentials
   username: "your-proton-username"
   password: "your-proton-password"
   ```

2. **Update the ConfigMap** (`proton-vpn-secret.yaml`):
   - Replace the `protonvpn.ovpn` content with your downloaded `.ovpn` file
   - Replace the `ca.crt` content with your downloaded certificate
   - Replace the `ta.key` content with your downloaded TLS key

## Step 3: Recommended P2P Servers

Choose one of these P2P-optimized servers:

**Netherlands (High-speed P2P)**:
- `nl-free-01.protonvpn.net` (Free tier)
- `nl-01.protonvpn.net` (Plus tier)
- `nl-02.protonvpn.net` (Plus tier)

**Iceland (Privacy-focused P2P)**:
- `is-01.protonvpn.net`
- `is-02.protonvpn.net`

**Switzerland (Balanced)**:
- `ch-01.protonvpn.net`
- `ch-02.protonvpn.net`

## Step 4: Apply the Configuration

After updating the files with your actual Proton VPN credentials and config:

```bash
# Apply the VPN credentials and config
kubectl apply -f proton-vpn-secret.yaml

# Apply the new deployment with VPN
kubectl apply -f deployment-with-vpn.yaml
```

## Step 5: Verify VPN Connection

1. **Check pod logs**:
   ```bash
   kubectl logs -n media deployment/qbittorrent -c proton-vpn
   kubectl logs -n media deployment/qbittorrent -c qbittorrent
   ```

2. **Test IP address**:
   ```bash
   # Exec into qbittorrent container and check public IP
   kubectl exec -n media deployment/qbittorrent -c qbittorrent -- curl -s ifconfig.me
   ```

3. **Verify P2P functionality**:
   - Access qBittorrent WebUI at https://qbittorrent.homelab.local
   - Check connection status and port accessibility

## Troubleshooting

**If VPN fails to connect**:
1. Check VPN container logs
2. Verify credentials are correct
3. Ensure the server endpoint is reachable
4. Try a different P2P server

**If qBittorrent can't access internet**:
1. Check that VPN is connected successfully
2. Verify firewall rules in VPN container
3. Test DNS resolution inside container

**Port forwarding issues**:
- Proton VPN doesn't support automatic port forwarding
- You may need to configure manual port forwarding in qBittorrent settings
- Use the default ports (6881) or configure specific ports manually