#!/bin/bash

# Linux VPS Client Setup Commands for WireGuard VPN
# Run these commands on your Linux VPS

echo "🐧 Linux VPS WireGuard Client Setup"
echo "=================================="
echo

# Install WireGuard
echo "📦 Installing WireGuard..."
sudo apt update && sudo apt install -y wireguard

echo
echo "🔑 Generating client keys..."
# Generate private key
wg genkey | sudo tee /etc/wireguard/client_private.key
sudo chmod 600 /etc/wireguard/client_private.key

# Generate public key
CLIENT_PUBLIC_KEY=$(sudo cat /etc/wireguard/client_private.key | wg pubkey)
echo $CLIENT_PUBLIC_KEY | sudo tee /etc/wireguard/client_public.key

echo "✅ Client keys generated!"
echo "Client Public Key: $CLIENT_PUBLIC_KEY"
echo

echo "📝 Creating client configuration..."
sudo tee /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.0.0.2/24
PrivateKey = $(cat /etc/wireguard/client_private.key)
DNS = 8.8.8.8

[Peer]
PublicKey = SERVER_PUBLIC_KEY_HERE
Endpoint = SERVER_PUBLIC_IP:51820
AllowedIPs = 192.168.110.0/24, 10.0.0.0/24
PersistentKeepalive = 25
EOF

echo "✅ Client configuration created!"
echo

echo "🚀 Starting WireGuard..."
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

echo
echo "🔍 Testing connection..."
sleep 3

# Test VPN connection
if ping -c 3 10.0.0.1 > /dev/null 2>&1; then
    echo "✅ VPN connection successful!"
else
    echo "❌ VPN connection failed"
    echo "Check: Server public key, firewall on UDP 51820"
fi

# Test ESP32 access
if curl -s --connect-timeout 5 http://192.168.110.150:81/stream > /dev/null; then
    echo "✅ ESP32 accessible via VPN!"
else
    echo "❌ ESP32 not accessible via VPN"
    echo "Check: ESP32 is running, local network connectivity"
fi

echo
echo "📱 Next steps for face recognition:"
echo "cd /opt/stage/Face_Hands"
echo "echo 'STREAM_URL=http://192.168.110.150:81/stream' >> .env"
echo "docker restart face-hands"

echo
echo "📋 Information to send to Windows:"
echo "Client Public Key: $CLIENT_PUBLIC_KEY"
echo "VPS IP: $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_VPS_PUBLIC_IP')"
