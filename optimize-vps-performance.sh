#!/bin/bash

# Optimize VPS performance for face recognition system

echo "🚀 Optimizing VPS Performance..."
echo "================================"

# Check current resource usage
echo "📊 Current Resource Usage:"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
echo ""

# Optimize Docker container
echo "🐳 Optimizing Docker Container..."

# Check container resource limits
echo "🔍 Checking container resource limits..."
docker stats --no-stream face-hands 2>/dev/null || echo "Container not running"

# Stop resource-intensive container
echo "🛑 Stopping current container..."
docker-compose down 2>/dev/null || docker stop face-hands 2>/dev/null || true

# Clean up Docker
echo "🧹 Cleaning up Docker..."
docker system prune -f
docker image prune -f

# Update docker-compose.yml with resource limits
echo "📝 Updating docker-compose.yml with resource limits..."
cat > docker-compose.yml << 'EOF'
services:
  face-hands:
    build: .
    container_name: face-hands
    restart: unless-stopped
    environment:
      STREAM_URL: "${STREAM_URL:-http://192.168.110.150:81/stream}"
      TOLERANCE: "${TOLERANCE:-0.5}"
      MODEL: "${MODEL:-hog}"
      DATA_DIR: "/app/data"
      PORT: "8000"
      HOST: "0.0.0.0"
      FRAME_WIDTH: "${FRAME_WIDTH:-640}"
      FRAME_HEIGHT: "${FRAME_HEIGHT:-480}"
      JPEG_QUALITY: "${JPEG_QUALITY:-60}"
    ports:
      - "${PUBLIC_PORT:-8012}:8000"
    volumes:
      - ./known_face:/app/known_face:ro
      - ./data:/app/data
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF

# Update .env with optimized settings
echo "📝 Updating .env with optimized settings..."
cat > .env << 'EOF'
# ESP32 Camera Configuration
STREAM_URL=http://192.168.110.150:81/stream

# Face Recognition Settings
TOLERANCE=0.5
MODEL=hog

# Server Configuration
HOST=0.0.0.0
PORT=8000
PUBLIC_PORT=8012

# Optimized Video Stream Settings
FRAME_WIDTH=640
FRAME_HEIGHT=480
JPEG_QUALITY=60

# Data Directory
DATA_DIR=/app/data
EOF

# Start optimized container
echo "🚀 Starting optimized container..."
docker-compose up -d

if [ $? -eq 0 ]; then
    echo "✅ Optimized container started!"
    
    # Wait for startup
    sleep 5
    
    # Test performance
    echo "🔍 Testing optimized performance..."
    
    # Test health endpoint
    for i in {1..5}; do
        if curl -s --max-time 5 http://localhost:8012/api/health >/dev/null 2>&1; then
            echo "✅ Health check passed in $(($i*2)) seconds!"
            break
        else
            echo "⏳ Waiting for service... ($i/5)"
            sleep 2
        fi
    done
    
    echo ""
    echo "📊 Performance Optimizations Applied:"
    echo "✅ Reduced frame resolution (640x480)"
    echo "✅ Lower JPEG quality (60%)"
    echo "✅ CPU limit (1.0 core)"
    echo "✅ Memory limit (512MB)"
    echo "✅ Health check enabled"
    echo "✅ Docker cleanup performed"
    echo ""
    
    echo "🌐 Access URLs:"
    VPS_IP=$(curl -s ifconfig.me 2>/dev/null || echo "31.97.177.87")
    echo "   Main Interface: http://$VPS_IP:8012"
    echo "   Live Stream: http://$VPS_IP:8012/video.mjpeg"
    echo "   Upload Faces: http://$VPS_IP:8012/upload"
    echo ""
    
    echo "📋 Performance Monitoring:"
    echo "   Docker stats: docker stats face-hands"
    echo "   System load: top"
    echo "   Memory: free -h"
    echo "   Disk: df -h"
    
else
    echo "❌ Failed to start optimized container"
    echo "🔍 Checking logs:"
    docker-compose logs
fi

echo ""
echo "🎯 Alternative: Switch to Local Setup"
echo "If VPS continues to be slow, consider local setup:"
echo "1. Run: python local-python-esp32.py"
echo "2. No network latency"
echo "3. Better performance"
echo "4. Easier debugging"
