#!/bin/bash

# Complete face recognition setup - clean git issues and finalize

echo "🎯 Completing Face Recognition Setup..."
echo "======================================"
echo

# Handle git conflicts
echo "🧹 Cleaning up git issues..."

# Remove untracked files that cause conflicts
echo "🗑️ Removing problematic files..."
rm -f fix-networking.sh update-vps-config.sh switch-to-port-forwarding.sh cleanup-vpn.sh 2>/dev/null || true

# Stash any local changes
echo "📦 Stashing local changes..."
git stash push -m "Stash changes before pull" 2>/dev/null || true

# Pull latest changes
echo "📥 Pulling latest changes..."
git pull origin main

if [ $? -eq 0 ]; then
    echo "✅ Git pull successful!"
    
    # Restore stashed changes if any
    if git stash list | grep -q "stash@{0}"; then
        echo "📦 Restoring stashed changes..."
        git stash pop
    fi
    
    # Ensure .env is properly configured for port forwarding
    echo "📝 Finalizing .env configuration..."
    
    # Get Windows public IP
    WINDOWS_IP="196.179.202.142"
    EXTERNAL_PORT="8181"
    
    # Update or create .env with port forwarding
    if [ -f .env ]; then
        # Update existing .env
        sed -i "s|STREAM_URL=.*|STREAM_URL=http://$WINDOWS_IP:$EXTERNAL_PORT/stream|g" .env
        sed -i "s|PUBLIC_PORT=.*|PUBLIC_PORT=8012|g" .env
    else
        # Create new .env
        cat > .env << EOF
# ESP32 Camera Configuration
STREAM_URL=http://$WINDOWS_IP:$EXTERNAL_PORT/stream

# Face Recognition Settings
TOLERANCE=0.5
MODEL=hog

# Server Configuration
HOST=0.0.0.0
PORT=8000
PUBLIC_PORT=8012

# Video Stream Settings
FRAME_WIDTH=1280
FRAME_HEIGHT=720
JPEG_QUALITY=80

# Data Directory
DATA_DIR=/app/data
EOF
    fi
    
    echo "✅ .env configured for port forwarding"
    echo "   STREAM_URL=http://$WINDOWS_IP:$EXTERNAL_PORT/stream"
    
    # Restart Docker container
    echo "🔄 Restarting face recognition container..."
    if docker ps | grep -q "face-hands"; then
        docker restart face-hands
    else
        echo "🚀 Starting new container..."
        docker run -d \
          --name face-hands \
          --restart unless-stopped \
          -p 8012:8000 \
          --env-file .env \
          -v "$(pwd)/known_face:/app/known_face:ro" \
          -v "$(pwd)/data:/app/data" \
          face-recognition:latest
    fi
    
    # Wait for container to start
    sleep 5
    
    # Test the service
    echo "🔍 Testing face recognition service..."
    
    # Test health endpoint
    for i in {1..10}; do
        if curl -s http://localhost:8012/api/health >/dev/null 2>&1; then
            echo "✅ Health check passed!"
            break
        else
            echo "⏳ Waiting for service... ($i/10)"
            sleep 2
        fi
    done
    
    # Test external access
    echo "🌐 Testing external access..."
    VPS_IP=$(curl -s ifconfig.me 2>/dev/null || echo "2a02:4780:28f7::1")
    
    if curl -s --connect-timeout 10 http://$VPS_IP:8012/api/health >/dev/null 2>&1; then
        echo "✅ External access working!"
    else
        echo "⚠️  External access test failed"
    fi
    
    echo ""
    echo "🎉 SETUP COMPLETE!"
    echo "======================================"
    echo "🌐 Your ESP32 Face Recognition System is ready!"
    echo ""
    echo "📱 Access URLs:"
    echo "   Main Interface: http://$VPS_IP:8012"
    echo "   Live Stream: http://$VPS_IP:8012/video.mjpeg"
    echo "   Upload Faces: http://$VPS_IP:8012/upload"
    echo "   API Health: http://$VPS_IP:8012/api/health"
    echo ""
    echo "📋 Management Commands:"
    echo "   View logs: docker logs -f face-hands"
    echo "   Restart: docker restart face-hands"
    echo "   Stop: docker stop face-hands"
    echo "   Update: git pull && ./complete-setup.sh"
    echo ""
    echo "🔧 Router Configuration (if needed):"
    echo "   External Port: $EXTERNAL_PORT"
    echo "   Internal Port: 81"
    echo "   Internal IP: 192.168.110.150"
    echo "   Protocol: TCP"
    
else
    echo "❌ Git pull failed!"
    echo "🔧 Manual setup..."
    
    # Create .env manually
    WINDOWS_IP="196.179.202.142"
    EXTERNAL_PORT="8181"
    
    cat > .env << EOF
# ESP32 Camera Configuration
STREAM_URL=http://$WINDOWS_IP:$EXTERNAL_PORT/stream

# Face Recognition Settings
TOLERANCE=0.5
MODEL=hog

# Server Configuration
HOST=0.0.0.0
PORT=8000
PUBLIC_PORT=8012

# Video Stream Settings
FRAME_WIDTH=1280
FRAME_HEIGHT=720
JPEG_QUALITY=80

# Data Directory
DATA_DIR=/app/data
EOF
    
    echo "✅ .env created manually"
    echo "🔄 Starting container..."
    
    docker run -d \
      --name face-hands \
      --restart unless-stopped \
      -p 8012:8000 \
      --env-file .env \
      -v "$(pwd)/known_face:/app/known_face:ro" \
      -v "$(pwd)/data:/app/data" \
      face-recognition:latest
fi

echo ""
echo "✅ Setup process completed!"
