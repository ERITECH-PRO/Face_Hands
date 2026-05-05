# Windows Local + Linux VPS Setup Guide

This guide covers setting up ESP32 face recognition with Windows local network and Linux VPS.

## 🏗️ Architecture Overview

```
Windows Local Network          Internet                 Linux VPS
┌─────────────────┐         ┌─────────────┐         ┌─────────────┐
│ ESP32 Camera    │◄──────►│ Router/VPN  │◄──────►│ Face Recog  │
│ 192.168.110.150│         │ Connection  │         │ Docker App  │
└─────────────────┘         └─────────────┘         └─────────────┘
```

## 🎯 Recommended Setup: Port Forwarding

### Why Port Forwarding?
- ✅ Easiest to configure
- ✅ No additional software needed
- ✅ Works with most ISPs
- ⚠️ Less secure than VPN

### Step 1: Windows Router Configuration

1. **Access Router Admin Panel**
   - Open browser: `http://192.168.1.1` (or your router's IP)
   - Login with admin credentials

2. **Find Port Forwarding Section**
   - Look for: "Port Forwarding", "NAT", "Virtual Server"
   - Usually under Advanced/Network settings

3. **Create Port Forwarding Rule**
   ```
   External Port: 8181
   Internal Port: 81
   Internal IP: 192.168.110.150
   Protocol: TCP
   Enable: Yes
   Name: ESP32_Camera
   ```

4. **Save and Restart Router**

### Step 2: Windows Configuration

```powershell
# Run the port forwarding setup script
.\setup-port-forwarding-fixed.ps1 -Action full
```

This script will:
- Detect your public IP
- Test ESP32 connectivity
- Update `.env` file with correct stream URL
- Show you the final URLs

### Step 3: Linux VPS Configuration

```bash
# On your Linux VPS
cd /opt/stage/Face_Hands

# Update .env with your public IP
PUBLIC_IP=$(curl -s ifconfig.me)
sed -i "s|STREAM_URL=.*|STREAM_URL=http://$PUBLIC_IP:8181/stream|" .env

# Deploy the application
./deploy-fixed.sh
```

## 🔐 Alternative: VPN Setup (More Secure)

### Why VPN?
- ✅ Encrypted connection
- ✅ No public exposure of ESP32
- ✅ More reliable connection
- ⚠️ More complex setup

### Step 1: Windows VPN Server

```powershell
# Install WireGuard on Windows
# Download from: https://www.wireguard.com/install/

# Run VPN server setup
.\setup-vpn-fixed.ps1 -Mode server
```

This will:
- Generate server keys
- Create `wg0-server.conf`
- Show server public key
- Display configuration instructions

### Step 2: Linux VPS VPN Client

```bash
# On Linux VPS
cd /opt/stage/Face_Hands

# Make script executable
chmod +x quick-vpn-setup.sh

# Run VPN client setup
./quick-vpn-setup.sh client
```

### Step 3: Complete VPN Connection

1. **Add VPS public key to Windows server config**
2. **Restart WireGuard on Windows**
3. **Test connection from Linux VPS**
4. **Update stream URL on VPS**

```bash
# On Linux VPS, after VPN is connected
echo "STREAM_URL=http://192.168.110.150:81/stream" >> .env
docker restart face-hands
```

## 🧪 Testing Connectivity

### Test Port Forwarding

```powershell
# On Windows
.\setup-port-forwarding-fixed.ps1 -Action test
```

### Test VPN Connection

```bash
# On Linux VPS
ping 10.0.0.1  # VPN server IP
curl -I http://192.168.110.150:81/stream
```

## 📊 Comparison

| Feature | Port Forwarding | VPN |
|---------|----------------|-----|
| **Setup Time** | 5 minutes | 15 minutes |
| **Security** | ⭐⭐ | ⭐⭐⭐⭐ |
| **Complexity** | Easy | Medium |
| **Reliability** | Good | Excellent |
| **Cost** | Free | Free |

## 🚀 Quick Start Commands

### Port Forwarding (Recommended First)
```powershell
# Windows (run once)
.\setup-port-forwarding-fixed.ps1

# Linux VPS
cd /opt/stage/Face_Hands
./deploy-fixed.sh
```

### VPN (If Port Forwarding Fails)
```powershell
# Windows VPN Server
.\setup-vpn-fixed.ps1 -Mode server
```

```bash
# Linux VPS VPN Client
./quick-vpn-setup.sh client
```

## 🔧 Troubleshooting

### Port Forwarding Issues
- **Router blocks ports**: Try different external port (e.g., 8080, 9090)
- **ISP blocks ports**: Use VPN method
- **Double NAT**: Configure both routers

### VPN Issues
- **Firewall blocking**: Open UDP port 51820
- **Keys mismatch**: Regenerate and exchange keys
- **Connection drops**: Check PersistentKeepalive setting

### Docker Issues
```bash
# Check container status
docker ps

# View logs
docker logs face-hands

# Restart container
docker restart face-hands
```

## 📱 Access URLs

After setup, access your system at:

- **Main Interface**: `http://your-vps-ip:8012`
- **Live Stream**: `http://your-vps-ip:8012/video.mjpeg`
- **Upload Faces**: `http://your-vps-ip:8012/upload`
- **API Health**: `http://your-vps-ip:8012/api/health`

## 🎯 Recommendation

**Start with Port Forwarding** because:
1. Much simpler setup
2. No additional software needed
3. Works for most home networks
4. Easy to troubleshoot

**Use VPN only if:**
- Your ISP blocks ports
- You need higher security
- Port forwarding doesn't work

Choose the method that best fits your technical comfort and network requirements!
