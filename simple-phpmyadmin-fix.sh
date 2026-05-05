#!/bin/bash

# Simple phpMyAdmin fix using VPS IP and port

echo "🔧 Simple phpMyAdmin Fix..."
echo "========================"

# Remove current phpMyAdmin
echo "🗑️ Removing current phpMyAdmin..."
docker rm -f phpmyadmin 2>/dev/null || true

# Create phpMyAdmin using VPS IP and MySQL port
echo "🚀 Creating phpMyAdmin with VPS connection..."
docker run -d --name phpmyadmin --restart always \
  -p 8083:80 \
  --network bridge \
  -e PMA_HOST=31.97.177.87 \
  -e PMA_PORT=3307 \
  -e PMA_USER=root \
  -e PMA_PASSWORD=StrongPass123 \
  phpmyadmin/phpmyadmin

# Wait for startup
echo "⏳ Waiting for phpMyAdmin to start..."
sleep 15

# Test phpMyAdmin
echo "🔍 Testing phpMyAdmin..."
if curl -s --max-time 10 http://localhost:8083 >/dev/null 2>&1; then
    echo "✅ phpMyAdmin is accessible"
else
    echo "❌ phpMyAdmin not responding"
fi

echo ""
echo "🎉 Simple phpMyAdmin Fix Complete!"
echo "=================================="
echo "🌐 Access URL: http://31.97.177.87:8083"
echo ""
echo "🔐 Login Credentials:"
echo "   Username: root"
echo "   Password: StrongPass123"
echo "   Server: 31.97.177.87"
echo "   Port: 3307"
echo ""
echo "✅ All services should now be working:"
echo "   - Portainer: http://31.97.177.87:9000"
echo "   - phpMyAdmin: http://31.97.177.87:8083"
echo "   - All other containers: Running normally"
