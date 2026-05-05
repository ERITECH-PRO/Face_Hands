#!/bin/bash

# Force phpMyAdmin to show login form

echo "🔧 Forcing phpMyAdmin Login Form..."
echo "================================"

# Remove current phpMyAdmin
echo "🗑️ Removing current phpMyAdmin..."
docker rm -f phpmyadmin 2>/dev/null || true

# Create phpMyAdmin without pre-configured credentials
echo "🚀 Creating phpMyAdmin with login form..."
docker run -d --name phpmyadmin --restart always \
  -p 8083:80 \
  --network bridge \
  -e PMA_ABSOLUTE_URI=http://31.97.177.87:8083/ \
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
echo "🎉 phpMyAdmin Login Form Setup Complete!"
echo "======================================"
echo "🌐 Access URL: http://31.97.177.87:8083"
echo ""
echo "🔐 Login Form Will Show:"
echo "   Server: 31.97.177.87:3307"
echo "   Username: root"
echo "   Password: StrongPass123"
echo ""
echo "🔧 Manual Login Steps:"
echo "   1. Visit: http://31.97.177.87:8083"
echo "   2. Enter Server: 31.97.177.87:3307"
echo "   3. Enter Username: root"
echo "   4. Enter Password: StrongPass123"
echo "   5. Click 'Go' to login"
echo ""
echo "✅ This will force phpMyAdmin to show the login form"
