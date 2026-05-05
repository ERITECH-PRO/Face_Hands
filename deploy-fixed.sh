#!/bin/bash

# ESP32 Face Recognition VPS Deployment Script (Fixed)
# This script deploys the face recognition system with ESP32 camera support

set -e

echo "🚀 Deploying ESP32 Face Recognition System to VPS..."
echo

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p known_face
mkdir -p data

# Copy environment file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your ESP32 camera IP address"
fi

# Stop and remove existing containers
echo "🧹 Cleaning up existing containers..."
docker stop face-hands 2>/dev/null || true
docker rm face-hands 2>/dev/null || true
docker rmi face_hands_face-hands 2>/dev/null || true

# Build Docker image
echo "🔨 Building Docker image..."
docker build -t face-recognition:latest .

# Run container directly (avoiding docker-compose issues)
echo "🔄 Starting container..."
docker run -d \
  --name face-hands \
  --restart unless-stopped \
  -p 8012:8000 \
  -e STREAM_URL="${STREAM_URL:-http://192.168.110.150:81/stream}" \
  -e TOLERANCE="${TOLERANCE:-0.5}" \
  -e MODEL="${MODEL:-hog}" \
  -e DATA_DIR="/app/data" \
  -e PORT="8000" \
  -e HOST="0.0.0.0" \
  -e FRAME_WIDTH="${FRAME_WIDTH:-1280}" \
  -e FRAME_HEIGHT="${FRAME_HEIGHT:-720}" \
  -e JPEG_QUALITY="${JPEG_QUALITY:-80}" \
  -v "$(pwd)/known_face:/app/known_face:ro" \
  -v "$(pwd)/data:/app/data" \
  face-recognition:latest

# Check if service is running
echo "🔍 Checking service status..."
sleep 5

if docker ps | grep -q "face-hands"; then
    echo "✅ Service is running successfully!"
    echo
    echo "🌐 Access your face recognition system at:"
    echo "   http://your-vps-ip:8012"
    echo
    echo "📹 Camera stream:"
    echo "   http://your-vps-ip:8012/video.mjpeg"
    echo
    echo "📸 Upload interface:"
    echo "   http://your-vps-ip:8012/upload"
    echo
    echo "🔧 To check logs: docker logs -f face-hands"
    echo "🛑 To stop: docker stop face-hands"
    echo "🔄 To restart: docker restart face-hands"
else
    echo "❌ Service failed to start. Check logs:"
    docker logs face-hands
    exit 1
fi
