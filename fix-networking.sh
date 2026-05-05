#!/bin/bash

# Fix networking and complete face recognition setup

echo "🔧 Fixing networking and completing setup..."
echo

# Test DNS resolution
echo "🌐 Testing DNS resolution..."
if nslookup github.com >/dev/null 2>&1; then
    echo "✅ DNS working"
else
    echo "❌ DNS not working - using Google DNS"
    echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
    echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf
fi

# Test internet connectivity
echo "🌐 Testing internet..."
if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
    echo "✅ Internet working"
else
    echo "❌ Internet not working"
    exit 1
fi

echo
echo "📝 Manual setup since git pull failed..."

# Create .env file if missing
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cat > .env << EOF
# ESP32 Camera Configuration
STREAM_URL=http://192.168.110.150:81/stream

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
    echo "✅ .env file created"
fi

# Update with VPN stream URL
echo "📝 Updating .env with VPN stream URL..."
sed -i 's|STREAM_URL=.*|STREAM_URL=http://192.168.110.150:81/stream|' .env

echo "✅ .env updated with ESP32 stream URL"

# Check if Docker is running
echo "🐳 Checking Docker..."
if systemctl is-active --quiet docker; then
    echo "✅ Docker is running"
else
    echo "🚀 Starting Docker..."
    sudo systemctl start docker
    sleep 3
fi

# Check if container exists
if docker ps -a | grep -q "face-hands"; then
    echo "🔄 Removing existing container..."
    docker stop face-hands 2>/dev/null || true
    docker rm face-hands 2>/dev/null || true
fi

# Build and run container
echo "🔨 Building and starting face recognition..."
docker build -t face-recognition:latest .

if [ $? -eq 0 ]; then
    echo "✅ Docker image built successfully"
    
    docker run -d \
      --name face-hands \
      --restart unless-stopped \
      -p 8012:8000 \
      -e STREAM_URL="http://192.168.110.150:81/stream" \
      -e TOLERANCE="0.5" \
      -e MODEL="hog" \
      -e DATA_DIR="/app/data" \
      -e PORT="8000" \
      -e HOST="0.0.0.0" \
      -e FRAME_WIDTH="1280" \
      -e FRAME_HEIGHT="720" \
      -e JPEG_QUALITY="80" \
      -v "$(pwd)/known_face:/app/known_face:ro" \
      -v "$(pwd)/data:/app/data" \
      face-recognition:latest
    
    if [ $? -eq 0 ]; then
        echo "✅ Face recognition container started!"
        
        # Wait for container to start
        sleep 5
        
        # Check if container is running
        if docker ps | grep -q "face-hands"; then
            echo "✅ Container is running!"
            
            # Test health endpoint
            echo "🔍 Testing health endpoint..."
            for i in {1..10}; do
                if curl -s http://localhost:8012/api/health >/dev/null 2>&1; then
                    echo "✅ Health check passed!"
                    break
                else
                    echo "⏳ Waiting for service... ($i/10)"
                    sleep 2
                fi
            done
            
            echo ""
            echo "🎉 Setup Complete!"
            echo "================================="
            echo "🌐 Access your system at:"
            echo "   Main Interface: http://2a02:4780:28f7::1:8012"
            echo "   Live Stream: http://2a02:4780:28f7::1:8012/video.mjpeg"
            echo "   Upload Faces: http://2a02:4780:28f7::1:8012/upload"
            echo "   API Health: http://2a02:4780:28f7::1:8012/api/health"
            echo ""
            echo "📋 Container management:"
            echo "   View logs: docker logs -f face-hands"
            echo "   Restart: docker restart face-hands"
            echo "   Stop: docker stop face-hands"
            
        else
            echo "❌ Container failed to start"
            echo "🔍 Checking logs:"
            docker logs face-hands
        fi
    else
        echo "❌ Docker build failed"
    fi
else
    echo "❌ Docker not available - installing..."
    # Try to install Docker (Ubuntu/Debian)
    sudo apt update
    sudo apt install -y docker.io docker-compose
    sudo systemctl start docker
    sudo systemctl enable docker
    
    echo "🔄 Please run this script again after Docker installation"
fi

echo
echo "🔧 VPN Status Check:"
if command -v wg >/dev/null 2>&1; then
    if wg show >/dev/null 2>&1; then
        echo "✅ WireGuard is running"
        echo "📊 Tunnel status:"
        wg show
    else
        echo "❌ WireGuard is not running"
        echo "🚀 Starting WireGuard..."
        sudo wg-quick up /etc/wireguard/wg0.conf
    fi
else
    echo "⚠️  WireGuard not installed"
fi
