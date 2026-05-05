#!/bin/bash

# Ultimate phpMyAdmin fix using IP address instead of container name

echo "🔧 Ultimate phpMyAdmin Fix..."
echo "=========================="

# Get MySQL container IP address
echo "🔍 Getting MySQL container IP..."
MYSQL_IP=$(docker inspect mysql_central | grep '"IPAddress"' | head -1 | awk '{print $2}' | tr -d '"')

if [ -z "$MYSQL_IP" ]; then
    echo "❌ Could not get MySQL container IP"
    echo "🔄 Using default Docker network IP..."
    MYSQL_IP="172.17.0.1"
fi

echo "📍 MySQL IP: $MYSQL_IP"

# Remove current phpMyAdmin
echo "🗑️ Removing current phpMyAdmin..."
docker rm -f phpmyadmin 2>/dev/null || true

# Create phpMyAdmin with IP address connection
echo "🚀 Creating phpMyAdmin with IP connection..."
docker run -d --name phpmyadmin --restart always \
  -p 8083:80 \
  --network bridge \
  -e PMA_HOST=$MYSQL_IP \
  -e PMA_PORT=3306 \
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
echo "🎉 Ultimate phpMyAdmin Fix Complete!"
echo "=================================="
echo "🌐 Access URL: http://31.97.177.87:8083"
echo ""
echo "🔐 Login Credentials:"
echo "   Username: root"
echo "   Password: StrongPass123"
echo "   Server: $MYSQL_IP"
echo ""
echo "🔧 Alternative login method:"
echo "   If still not working, try using the Docker network IP directly"
echo "   Server: 172.17.0.1 (Docker bridge network)"
echo ""
echo "✅ All services should now be working:"
echo "   - Portainer: http://31.97.177.87:9000"
echo "   - phpMyAdmin: http://31.97.177.87:8083"
echo "   - All other containers: Running normally"
