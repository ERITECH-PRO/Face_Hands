#!/bin/bash

# Restart container with updated configuration

echo "🔄 Restarting face recognition container..."
echo "=================================="

# Stop and remove existing container
echo "🛑 Stopping existing container..."
docker-compose down 2>/dev/null || true
docker stop face-hands 2>/dev/null || true
docker rm face-hands 2>/dev/null || true

# Wait a moment
sleep 2

# Start with updated configuration
echo "🚀 Starting with updated configuration..."
docker-compose up -d

if [ $? -eq 0 ]; then
    echo "✅ Container started successfully!"
    
    # Wait for startup
    sleep 5
    
    # Test service
    echo "🔍 Testing service health..."
    for i in {1..10}; do
        if curl -s http://localhost:8012/api/health >/dev/null 2>&1; then
            echo "✅ Service is healthy!"
            break
        else
            echo "⏳ Waiting for service... ($i/10)"
            sleep 2
        fi
    done
    
    # Get VPS IP for URLs
    VPS_IP="31.97.177.87"
    
    echo ""
    echo "🎉 Container Restart Complete!"
    echo "=================================="
    echo "🌐 Access URLs:"
    echo "   Main Interface: http://$VPS_IP:8012"
    echo "   Live Stream: http://$VPS_IP:8012/video.mjpeg"
    echo "   Upload Faces: http://$VPS_IP:8012/upload"
    echo "   API Health: http://$VPS_IP:8012/api/health"
    echo ""
    echo "📋 Container Status:"
    echo "   View logs: docker logs -f face-hands"
    echo "   Restart: docker-compose restart"
    echo "   Stop: docker-compose stop"
    
else
    echo "❌ Failed to start container"
    echo "🔍 Checking logs:"
    docker-compose logs
fi

echo ""
echo "🔧 Current Configuration:"
echo "STREAM_URL in docker-compose.yml:"
grep "STREAM_URL:" docker-compose.yml
echo ""
echo "STREAM_URL in .env:"
grep "STREAM_URL:" .env 2>/dev/null || echo "Not found"
