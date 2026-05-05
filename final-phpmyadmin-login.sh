#!/bin/bash

# Final phpMyAdmin login form with correct server

echo "🔧 Final phpMyAdmin Login Form Setup..."
echo "====================================="

# Remove current phpMyAdmin
echo "🗑️ Removing current phpMyAdmin..."
docker rm -f phpmyadmin 2>/dev/null || true

# Create phpMyAdmin with login form and correct server
echo "🚀 Creating phpMyAdmin with login form..."
docker run -d --name phpmyadmin --restart always \
  -p 8083:80 \
  --network bridge \
  -e PMA_HOST=31.97.177.87 \
  -e PMA_PORT=3307 \
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
echo "🎉 Final phpMyAdmin Login Form Ready!"
echo "==================================="
echo "🌐 Access URL: http://31.97.177.87:8083"
echo ""
echo "🔐 Login Information:"
echo "   Server: 31.97.177.87:3307"
echo "   Username: root"
echo "   Password: StrongPass123"
echo ""
echo "📝 Login Steps:"
echo "   1. Visit: http://31.97.177.87:8083"
echo "   2. Server field will show: 31.97.177.87:3307"
echo "   3. Username: root"
echo "   4. Password: StrongPass123"
echo "   5. Click 'Go' to login"
echo ""
echo "✅ This will show the login form with correct server configuration"
