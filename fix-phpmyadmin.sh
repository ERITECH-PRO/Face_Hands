#!/bin/bash

# Fix phpMyAdmin database connection issue

echo "🔧 Fixing phpMyAdmin Database Connection..."
echo "========================================"

# Remove current phpMyAdmin
echo "🗑️ Removing current phpMyAdmin..."
docker rm -f phpmyadmin 2>/dev/null || true

# Check MySQL container name
MYSQL_CONTAINER=$(docker ps --format "table {{.Names}}" | grep mysql)
echo "🔍 Found MySQL container: $MYSQL_CONTAINER"

# Create phpMyAdmin with proper MySQL connection
echo "🚀 Creating phpMyAdmin with MySQL connection..."
docker run -d --name phpmyadmin --restart always \
  -p 8083:80 \
  --link mysql_central:db \
  -e PMA_HOST=mysql_central \
  -e PMA_PORT=3306 \
  phpmyadmin/phpmyadmin

# Wait for startup
echo "⏳ Waiting for phpMyAdmin to start..."
sleep 10

# Test phpMyAdmin
echo "🔍 Testing phpMyAdmin..."
if curl -s --max-time 10 http://localhost:8083 >/dev/null 2>&1; then
    echo "✅ phpMyAdmin is accessible"
else
    echo "❌ phpMyAdmin not responding"
fi

# Get MySQL credentials
echo ""
echo "📋 MySQL Connection Information:"
echo "   Host: mysql_central"
echo "   Port: 3306"
echo "   Username: root"
echo "   Password: (check MySQL container environment)"
echo ""

# Check MySQL container environment for password
echo "🔍 Checking MySQL container for password..."
docker inspect mysql_central | grep -A 10 -B 10 "MYSQL_ROOT_PASSWORD" || echo "Password not found in container environment"

echo ""
echo "🌐 Access phpMyAdmin at: http://31.97.177.87:8083"
echo ""
echo "🔧 If still having issues:"
echo "1. Check MySQL container: docker logs mysql_central"
echo "2. Test MySQL connection: docker exec -it mysql_central mysql -u root -p"
echo "3. Restart MySQL: docker restart mysql_central"
