#!/bin/bash

# Switch from VPN to Port Forwarding for better performance

echo "🔄 Switching to Port Forwarding (Better Performance)"
echo "=================================================="
echo

# Stop WireGuard to avoid conflicts
echo "🛑 Stopping WireGuard..."
sudo wg-quick down /etc/wireguard/wg0.conf 2>/dev/null || true
sudo systemctl stop wg-quick@wg0 2>/dev/null || true

echo "✅ WireGuard stopped"
echo

# Update .env for port forwarding
echo "📝 Updating .env for port forwarding..."

# Get Windows public IP
WINDOWS_IP="196.179.202.142"
EXTERNAL_PORT="8181"

# Update stream URL
sed -i "s|STREAM_URL=.*|STREAM_URL=http://$WINDOWS_IP:$EXTERNAL_PORT/stream|g" .env

echo "✅ Updated .env with port forwarding URL"
echo "   STREAM_URL=http://$WINDOWS_IP:$EXTERNAL_PORT/stream"
echo

# Restart Docker to apply changes
echo "🔄 Restarting face recognition container..."
docker restart face-hands

if [ $? -eq 0 ]; then
    echo "✅ Container restarted successfully!"
    
    # Wait for startup
    sleep 5
    
    # Test new stream URL
    echo "🔍 Testing port forwarded stream..."
    if curl -s --connect-timeout 10 http://$WINDOWS_IP:$EXTERNAL_PORT/stream >/dev/null; then
        echo "✅ Port forwarded stream working!"
    else
        echo "⚠️  Port forwarded stream test failed"
        echo "   Check: Router port forwarding setup"
    fi
    
    echo ""
    echo "🎉 Port Forwarding Setup Complete!"
    echo "=================================="
    echo "🌐 Access your system at:"
    echo "   Main Interface: http://2a02:4780:28f7::1:8012"
    echo "   Live Stream: http://2a02:4780:28f7::1:8012/video.mjpeg"
    echo "   Upload Faces: http://2a02:4780:28f7::1:8012/upload"
    echo ""
    echo "📋 Router Configuration Needed:"
    echo "   External Port: $EXTERNAL_PORT"
    echo "   Internal Port: 81"
    echo "   Internal IP: 192.168.110.150"
    echo "   Protocol: TCP"
    echo ""
    echo "🔧 Windows Router Setup:"
    echo "   1. Access router admin (usually: 192.168.1.1)"
    echo "   2. Find 'Port Forwarding' section"
    echo "   3. Add rule: External $EXTERNAL_PORT -> Internal 192.168.110.150:81"
    echo "   4. Save and restart router"
    echo ""
    echo "📊 Performance Benefits:"
    echo "   ✅ Faster video streaming"
    echo "   ✅ Lower latency"
    echo "   ✅ More reliable connection"
    echo "   ✅ No VPN overhead"
    
else
    echo "❌ Failed to restart container"
    echo "🔍 Checking logs:"
    docker logs face-hands
fi

echo ""
echo "🔄 To switch back to VPN (if needed):"
echo "./update-vps-config.sh"
