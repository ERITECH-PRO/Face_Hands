#!/bin/bash

# ESP32 Face Recognition VPS Deployment Script
# This script deploys the face recognition system with ESP32 camera support

set -e

echo "🚀 Deploying ESP32 Face Recognition System to VPS..."
echo

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
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

# Build and start the container
echo "🔨 Building Docker image..."
docker-compose build

echo "🔄 Starting services..."
docker-compose up -d

# Check if service is running
echo "🔍 Checking service status..."
sleep 5

if docker-compose ps | grep -q "Up"; then
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
    echo "🔧 To check logs: docker-compose logs -f"
    echo "🛑 To stop: docker-compose down"
    echo "🔄 To restart: docker-compose restart"
else
    echo "❌ Service failed to start. Check logs:"
    docker-compose logs
    exit 1
fi
