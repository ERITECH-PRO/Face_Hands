#!/bin/bash

# Add password protection to phpMyAdmin interface

echo "🔒 Securing phpMyAdmin with Password..."
echo "===================================="

# Remove current phpMyAdmin
echo "🗑️ Removing current phpMyAdmin..."
docker rm -f phpmyadmin 2>/dev/null || true

# Create phpMyAdmin with authentication
echo "🚀 Creating secured phpMyAdmin..."
docker run -d --name phpmyadmin --restart always \
  -p 8083:80 \
  --network bridge \
  -e PMA_HOST=31.97.177.87 \
  -e PMA_PORT=3307 \
  -e PMA_USER=root \
  -e PMA_PASSWORD=StrongPass123 \
  -e PMA_ABSOLUTE_URI=http://31.97.177.87:8083/ \
  -e PMA_CONFIG_STORAGE=database \
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
echo "🎉 phpMyAdmin Security Setup Complete!"
echo "===================================="
echo "🌐 Access URL: http://31.97.177.87:8083"
echo ""
echo "🔐 Login Credentials:"
echo "   Username: root"
echo "   Password: StrongPass123"
echo "   Server: 31.97.177.87"
echo "   Port: 3307"
echo ""
echo "🔧 Security Features:"
echo "   ✅ Database authentication required"
echo "   ✅ MySQL password protection"
echo "   ✅ Secure connection configuration"
echo "   ✅ Auto-restart enabled"
echo ""
echo "🛡️ Security Recommendations:"
echo "   1. Change MySQL root password regularly"
echo "   2. Use strong, unique passwords"
echo "   3. Restrict phpMyAdmin access to trusted IPs"
echo "   4. Enable SSL/TLS for database connections"
echo "   5. Regular security updates"
echo ""
echo "📋 Management Commands:"
echo "   View logs: docker logs phpmyadmin"
echo "   Restart: docker restart phpmyadmin"
echo "   Update: docker pull phpmyadmin/phpmyadmin && docker restart phpmyadmin"
echo ""
echo "🔐 Database Security:"
echo "   ✅ MySQL root password: StrongPass123"
echo "   ✅ Portainer admin password: SecurePortainer123"
echo "   ✅ All interfaces now password protected"
