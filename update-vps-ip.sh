#!/bin/bash

# Update VPS IP address to correct value

echo "🔄 Updating VPS IP configuration..."
echo

# Set correct VPS IP
VPS_IP="31.97.177.87"

echo "📍 Using VPS IP: $VPS_IP"

# Update .env with correct VPS IP
sed -i "s|STREAM_URL=.*|STREAM_URL=http://$VPS_IP:8012/stream|g" .env

echo "✅ Updated .env with correct VPS IP"
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
    echo "🌐 Updated Access URLs:"
    echo "   Main Interface: http://$VPS_IP:8012"
    echo "   Live Stream: http://$VPS_IP:8012/video.mjpeg"
    echo "   Upload Faces: http://$VPS_IP:8012/upload"
    echo "   API Health: http://$VPS_IP:8012/api/health"
    
else
    echo "❌ Failed to restart container"
    echo "🔍 Checking logs:"
    docker logs face-hands
fi

echo ""
echo "📋 Current .env contents:"
cat .env
