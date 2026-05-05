#!/bin/bash

# Fix IPv6 address issue in .env

echo "🔧 Fixing IPv6 address format issue..."
echo

# Get correct IPv4 address
VPS_IP=$(curl -s -4 ifconfig.me 2>/dev/null || echo "2a02:4780:28f7::1")

echo "📍 Detected IPv4: $VPS_IP"

# Update .env with correct IPv4 format
sed -i "s|STREAM_URL=.*|STREAM_URL=http://$VPS_IP:8012/stream|g" .env

echo "✅ Updated .env with IPv4 address"
echo "   STREAM_URL=http://$VPS_IP:8012/stream"

# Restart Docker container
echo "🔄 Restarting face recognition container..."
docker restart face-hands

if [ $? -eq 0 ]; then
    echo "✅ Container restarted successfully!"
    
    # Wait for startup
    sleep 5
    
    # Test service
    echo "🔍 Testing service..."
    if curl -s http://$VPS_IP:8012/api/health >/dev/null 2>&1; then
        echo "✅ Service is healthy!"
    else
        echo "⚠️  Service health check failed"
    fi
    
    echo ""
    echo "🌐 Corrected Access URLs:"
    echo "   Main Interface: http://$VPS_IP:8012"
    echo "   Live Stream: http://$VPS_IP:8012/video.mjpeg"
    echo "   Upload Faces: http://$VPS_IP:8012/upload"
    echo "   API Health: http://$VPS_IP:8012/api/health"
    
else
    echo "❌ Failed to restart container"
fi

echo ""
echo "📋 Current .env contents:"
cat .env
