#!/bin/bash

# Quick WireGuard VPN Setup for ESP32-VPS Connectivity
# This script sets up VPN between VPS and local network

set -e

echo "🔐 Setting up WireGuard VPN for ESP32-VPS connectivity..."
echo

# Configuration
VPN_SUBNET="10.0.0.0/24"
VPN_SERVER_IP="10.0.0.1"
VPN_CLIENT_IP="10.0.0.2"
WG_PORT="51820"

# Detect if running on server or client
if [ "$1" = "server" ]; then
    echo "🖥️  Setting up VPN Server (Local Network)..."
    
    # Install WireGuard
    apt update && apt install -y wireguard
    
    # Generate keys
    wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
    chmod 600 /etc/wireguard/server_private.key
    
    # Create server config
    cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = $VPN_SERVER_IP/24
PrivateKey = $(cat /etc/wireguard/server_private.key)
ListenPort = $WG_PORT

[Peer]
# VPS Client - Add VPS public key here
# PublicKey = $(cat /etc/wireguard/vps_public.key)
AllowedIPs = $VPN_CLIENT_IP/32
EOF
    
    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
    
    # Configure firewall
    ufw allow $WG_PORT/udp
    ufw route allow in on wg0 out on eth0
    
    # Start WireGuard
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0
    
    echo "✅ VPN Server setup complete!"
    echo "📋 Server Public Key: $(cat /etc/wireguard/server_public.key)"
    echo "🌐 External IP: $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_EXTERNAL_IP'):$WG_PORT"
    echo
    echo "📝 Add this to VPS client config:"
    echo "   PublicKey = $(cat /etc/wireguard/server_public.key)"
    echo "   Endpoint = $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_EXTERNAL_IP'):$WG_PORT"
    
elif [ "$1" = "client" ]; then
    echo "🌐 Setting up VPN Client (VPS)..."
    
    # Install WireGuard
    apt update && apt install -y wireguard
    
    # Generate keys
    wg genkey | tee /etc/wireguard/client_private.key | wg pubkey > /etc/wireguard/client_public.key
    chmod 600 /etc/wireguard/client_private.key
    
    echo "📋 VPS Client Public Key: $(cat /etc/wireguard/client_public.key)"
    echo "   (Add this to server config)"
    echo
    
    read -p "Enter server public key: " SERVER_PUBLIC_KEY
    read -p "Enter server external IP:port: " SERVER_ENDPOINT
    
    # Create client config
    cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = $VPN_CLIENT_IP/24
PrivateKey = $(cat /etc/wireguard/client_private.key)
DNS = 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 192.168.110.0/24, $VPN_SUBNET
PersistentKeepalive = 25
EOF
    
    # Start WireGuard
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0
    
    echo "✅ VPN Client setup complete!"
    echo "🔍 Testing connection..."
    sleep 3
    
    # Test connection
    if ping -c 2 $VPN_SERVER_IP > /dev/null 2>&1; then
        echo "✅ VPN connection successful!"
        echo "🌐 You can now access: http://192.168.110.150:81/stream"
        
        # Update ESP32 stream URL
        if [ -f .env ]; then
            sed -i 's|STREAM_URL=.*|STREAM_URL=http://192.168.110.150:81/stream|' .env
            echo "📝 Updated .env with ESP32 stream URL"
            
            # Restart face recognition if running
            if docker ps | grep -q "face-hands"; then
                docker restart face-hands
                echo "🔄 Restarted face recognition service"
            fi
        fi
    else
        echo "❌ VPN connection failed"
        echo "🔧 Check server configuration and firewall"
    fi
    
else
    echo "Usage:"
    echo "  $0 server  - Setup VPN server on local network"
    echo "  $0 client  - Setup VPN client on VPS"
    echo
    echo "📋 Setup Steps:"
    echo "  1. Run on local network: $0 server"
    echo "  2. Copy server public key to VPS"
    echo "  3. Run on VPS: $0 client"
    echo "  4. Add VPS public key to server config"
    echo "  5. Restart WireGuard on server"
fi
