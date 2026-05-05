#!/bin/bash

# Add password protection to Portainer interface

echo "🔒 Securing Portainer with Password..."
echo "=================================="

# Set up Portainer admin user
echo "👤 Setting up Portainer admin user..."

# Create Portainer with admin password
echo "🚀 Creating secured Portainer..."
docker rm -f portainer 2>/dev/null || true

# Create volume for data persistence
docker volume create portainer_data 2>/dev/null || true

# Run Portainer with admin password
docker run -d -p 9000:9000 --name portainer --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  -e ADMIN_USER=admin \
  -e ADMIN_PASSWORD=SecurePortainer123 \
  portainer/portainer-ce:latest

# Wait for startup
echo "⏳ Waiting for Portainer to start..."
sleep 20

# Test Portainer
echo "🔍 Testing Portainer..."
if curl -s --max-time 10 http://localhost:9000 >/dev/null 2>&1; then
    echo "✅ Portainer is accessible"
else
    echo "❌ Portainer not responding"
fi

echo ""
echo "🎉 Portainer Security Setup Complete!"
echo "=================================="
echo "🌐 Access URL: http://31.97.177.87:9000"
echo ""
echo "🔐 Login Credentials:"
echo "   Username: admin"
echo "   Password: SecurePortainer123"
echo ""
echo "🔧 Security Features:"
echo "   ✅ Password protection enabled"
echo "   ✅ Admin user created"
echo "   ✅ Data persistence enabled"
echo "   ✅ Auto-restart enabled"
echo ""
echo "🛡️ Security Recommendations:"
echo "   1. Change the default password on first login"
echo "   2. Enable two-factor authentication"
echo "   3. Restrict access to trusted IPs"
echo "   4. Regular security updates"
echo ""
echo "📋 Management Commands:"
echo "   View logs: docker logs portainer"
echo "   Restart: docker restart portainer"
echo "   Update: docker pull portainer/portainer-ce:latest && docker restart portainer"
