#!/bin/bash

# Update VPS WireGuard config with correct server public key

echo "🔧 Updating VPS WireGuard configuration..."
echo

# Server public key from Windows
SERVER_PUBLIC_KEY="HlXCgNbVH2iA/gwvFUPd0m6oG3wysgSjrAXes7QgdgE="

echo "📝 Updating /etc/wireguard/wg0.conf..."
sudo tee /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.0.0.2/24
PrivateKey = qIBSOtagHZkDJFLp/kIJGCHK1t1W6bUq5SJRQwB3O1U=
DNS = 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = 196.179.202.142:51820
AllowedIPs = 192.168.110.0/24, 10.0.0.0/24
PersistentKeepalive = 25
EOF

echo "✅ Configuration updated!"
echo

echo "🚀 Starting WireGuard..."
sudo systemctl stop wg-quick@wg0 2>/dev/null || true
sudo wg-quick up /etc/wireguard/wg0.conf

if [ $? -eq 0 ]; then
    echo "✅ WireGuard started successfully!"
    
    echo "🔍 Testing VPN connection..."
    if ping -c 3 10.0.0.1 >/dev/null 2>&1; then
        echo "✅ VPN connection successful!"
        
        echo "📹 Testing ESP32 access..."
        if curl -s --connect-timeout 5 http://192.168.110.150:81/stream >/dev/null; then
            echo "✅ ESP32 accessible via VPN!"
            
            echo "📝 Updating face recognition config..."
            cd /opt/stage/Face_Hands
            
            # Update or add STREAM_URL
            if grep -q "STREAM_URL=" .env; then
                sed -i 's|STREAM_URL=.*|STREAM_URL=http://192.168.110.150:81/stream|' .env
            else
                echo "STREAM_URL=http://192.168.110.150:81/stream" >> .env
            fi
            
            echo "✅ Updated .env with ESP32 stream URL"
            
            # Restart Docker container
            if docker ps | grep -q "face-hands"; then
                echo "🔄 Restarting face recognition service..."
                docker restart face-hands
                echo "✅ Face recognition service restarted!"
            else
                echo "🚀 Starting face recognition service..."
                ./deploy-fixed.sh
            fi
            
            echo ""
            echo "🎉 VPN Setup Complete!"
            echo "🌐 Access your system at: http://2a02:4780:28f7::1:8012"
            echo "📹 Live stream: http://2a02:4780:28f7::1:8012/video.mjpeg"
            
        else
            echo "❌ ESP32 not accessible via VPN"
            echo "Check: ESP32 is running on local network"
        fi
        
    else
        echo "❌ VPN connection failed"
        echo "Check: Firewall on UDP 51820, server status"
    fi
    
else
    echo "❌ WireGuard failed to start"
    echo "🔍 Checking configuration..."
    echo "Current config:"
    cat /etc/wireguard/wg0.conf
fi

echo
echo "📋 Status check commands:"
echo "# Check WireGuard status:"
echo "sudo wg show"
echo ""
echo "# Check interface:"
echo "ip addr show wg0"
echo ""
echo "# Test ESP32:"
echo "curl -I http://192.168.110.150:81/stream"
