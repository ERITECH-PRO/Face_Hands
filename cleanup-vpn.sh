#!/bin/bash

# Completely remove VPN from VPS

echo "🧹 Cleaning up VPN from VPS..."
echo "================================="

# Stop WireGuard service
echo "🛑 Stopping WireGuard service..."
sudo systemctl stop wg-quick@wg0 2>/dev/null || true
sudo systemctl disable wg-quick@wg0 2>/dev/null || true

# Remove WireGuard interface
echo "🔧 Removing WireGuard interface..."
sudo wg-quick down /etc/wireguard/wg0.conf 2>/dev/null || true
sudo ip link del wg0 2>/dev/null || true

# Remove WireGuard packages
echo "🗑️ Removing WireGuard packages..."
sudo apt remove --purge -y wireguard wireguard-tools 2>/dev/null || true

# Remove configuration files
echo "🗑️ Removing configuration files..."
sudo rm -rf /etc/wireguard/ 2>/dev/null || true

# Clean up systemd
echo "🧹 Cleaning up systemd..."
sudo systemctl daemon-reload
sudo systemctl reset-failed

echo "✅ VPN completely removed from VPS!"
echo

# Check if any WireGuard processes remain
echo "🔍 Checking for remaining processes..."
if pgrep -f "wireguard\|wg" >/dev/null; then
    echo "⚠️  WireGuard processes still running:"
    pgrep -fl "wireguard\|wg"
    echo "🔧 Force killing remaining processes..."
    sudo pkill -f "wireguard\|wg" 2>/dev/null || true
    echo "✅ Processes terminated"
else
    echo "✅ No WireGuard processes found"
fi

echo ""
echo "🔄 Restarting face recognition with port forwarding..."
echo "📝 Updating .env for port forwarding..."

# Get Windows public IP
WINDOWS_IP="196.179.202.142"
EXTERNAL_PORT="8181"

# Update .env for port forwarding
sed -i "s|STREAM_URL=.*|STREAM_URL=http://$WINDOWS_IP:$EXTERNAL_PORT/stream|g" .env

echo "✅ Updated .env: http://$WINDOWS_IP:$EXTERNAL_PORT/stream"

# Restart Docker container
echo "🔄 Restarting face recognition container..."
docker restart face-hands

if [ $? -eq 0 ]; then
    echo "✅ Container restarted successfully!"
    
    # Wait for startup
    sleep 5
    
    # Test port forwarded connection
    echo "🔍 Testing port forwarded stream..."
    if curl -s --connect-timeout 10 http://$WINDOWS_IP:$EXTERNAL_PORT/stream >/dev/null; then
        echo "✅ Port forwarded stream working!"
        echo ""
        echo "🎉 VPN Cleanup Complete!"
        echo "================================="
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
        echo "🔧 Container management:"
        echo "   View logs: docker logs -f face-hands"
        echo "   Restart: docker restart face-hands"
        echo "   Stop: docker stop face-hands"
    else
        echo "❌ Port forwarded stream test failed"
        echo "🔧 Please configure router port forwarding:"
        echo "   External Port: $EXTERNAL_PORT"
        echo "   Internal Port: 81"
        echo "   Internal IP: 192.168.110.150"
        echo "   Protocol: TCP"
    fi
else
    echo "❌ Failed to restart container"
    echo "🔍 Checking logs:"
    docker logs face-hands
fi

echo ""
echo "🧹 VPN removal complete!"
