#!/bin/bash

# Fix WireGuard startup issues on Linux VPS

echo "🔧 Fixing WireGuard startup issues..."
echo

# Check WireGuard status
echo "📊 Current WireGuard status:"
sudo systemctl status wg-quick@wg0 --no-pager
echo

# Stop any existing WireGuard
echo "🛑 Stopping existing WireGuard..."
sudo systemctl stop wg-quick@wg0 2>/dev/null || true
sudo systemctl stop wg-quick@wg0@wg0 2>/dev/null || true
sudo ip link del wg0 2>/dev/null || true

# Check if interface exists
echo "🔍 Checking network interfaces..."
ip addr show | grep wg0 || echo "wg0 interface not found (expected)"

# Start WireGuard manually
echo "🚀 Starting WireGuard manually..."
sudo wg-quick up /etc/wireguard/wg0.conf

if [ $? -eq 0 ]; then
    echo "✅ WireGuard started successfully!"
    
    # Test connection
    echo "🔍 Testing VPN connection..."
    if ping -c 3 10.0.0.1 >/dev/null 2>&1; then
        echo "✅ VPN connection to server successful!"
        
        # Test ESP32 access
        echo "📹 Testing ESP32 access..."
        if curl -s --connect-timeout 5 http://192.168.110.150:81 >/dev/null; then
            echo "✅ ESP32 accessible via VPN!"
            
            # Update face recognition config
            echo "📝 Updating face recognition config..."
            cd /opt/stage/Face_Hands
            
            # Backup existing .env
            [ -f .env ] && cp .env .env.backup
            
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
            echo "🎉 Setup complete!"
            echo "🌐 Access your system at: http://2a02:4780:28f7::1:8012"
            
        else
            echo "❌ ESP32 not accessible via VPN"
            echo "Check: ESP32 is running on local network"
        fi
        
    else
        echo "❌ VPN connection failed"
        echo "Check: Server public key, firewall on UDP 51820"
    fi
    
else
    echo "❌ WireGuard failed to start"
    echo "🔍 Checking configuration..."
    
    # Validate config
    if [ ! -f /etc/wireguard/wg0.conf ]; then
        echo "❌ Config file not found"
        exit 1
    fi
    
    echo "📋 Current config:"
    cat /etc/wireguard/wg0.conf
    echo
    
    echo "🔧 Manual start attempt:"
    sudo wg show
fi

echo
echo "📋 Debugging commands:"
echo "# Check WireGuard status:"
echo "sudo systemctl status wg-quick@wg0"
echo ""
echo "# Check interface:"
echo "ip addr show wg0"
echo ""
echo "# Check WireGuard:"
echo "sudo wg show"
echo ""
echo "# Manual start:"
echo "sudo wg-quick up /etc/wireguard/wg0.conf"
