#!/bin/bash

# Fix VPS container issues caused by VPN and port forwarding

echo "🔧 Fixing VPS Container Issues..."
echo "================================"

# Remove VPN and port forwarding that caused issues
echo "🗑️ Removing VPN and port forwarding..."
sudo systemctl stop wg-quick@wg0 2>/dev/null || true
sudo systemctl disable wg-quick@wg0 2>/dev/null || true
sudo ip link del wg0 2>/dev/null || true

# Remove WireGuard packages
sudo apt remove --purge -y wireguard wireguard-tools 2>/dev/null || true

# Remove VPN config files
sudo rm -rf /etc/wireguard/ 2>/dev/null || true

# Reset network configuration
echo "🔄 Resetting network configuration..."
sudo systemctl restart networking 2>/dev/null || true
sudo systemctl restart docker 2>/dev/null || true

# Check and restart important containers
echo "🔄 Checking and restarting important containers..."

# Restart Portainer
if docker ps -a | grep -q "portainer"; then
    echo "🚀 Starting Portainer..."
    docker start $(docker ps -a | grep portainer | awk '{print $1}')
else
    echo "🚀 Creating Portainer..."
    docker volume create portainer_data
    docker run -d -p 9000:9000 --name portainer --restart always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce:latest
fi

# Restart phpMyAdmin
if docker ps -a | grep -q "phpmyadmin"; then
    echo "🚀 Starting phpMyAdmin..."
    docker start $(docker ps -a | grep phpmyadmin | awk '{print $1}')
else
    echo "🚀 Creating phpMyAdmin..."
    docker run -d --name phpmyadmin --restart always \
      -p 8083:80 \
      --link mysql_central:db \
      phpmyadmin/phpmyadmin
fi



# Check all containers status
echo "📊 Checking container status..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Test services
echo "🔍 Testing services..."

# Test Portainer
if curl -s --max-time 10 http://localhost:9000 >/dev/null 2>&1; then
    echo "✅ Portainer is working"
else
    echo "❌ Portainer not responding"
fi

# Test phpMyAdmin
if curl -s --max-time 10 http://localhost:8083 >/dev/null 2>&1; then
    echo "✅ phpMyAdmin is working"
else
    echo "❌ phpMyAdmin not responding"
fi

# Get VPS IP for access URLs
VPS_IP=$(curl -s ifconfig.me 2>/dev/null || echo "31.97.177.87")

echo ""
echo "🎉 Container Recovery Complete!"
echo "================================"
echo "🌐 Access URLs:"
echo "   Portainer: http://$VPS_IP:9000"
echo "   phpMyAdmin: http://$VPS_IP:8083"
echo ""
echo "📋 Management Commands:"
echo "   View all containers: docker ps -a"
echo "   Start stopped containers: docker start [container_name]"
echo "   View logs: docker logs [container_name]"
echo "   Restart Docker: systemctl restart docker"
echo ""
echo "🔧 If containers still not working:"
echo "   1. Check Docker status: systemctl status docker"
echo "   2. Restart Docker: systemctl restart docker"
echo "   3. Check system resources: free -h && df -h"
echo "   4. Check system load: top"

echo ""
echo "✅ VPN and port forwarding removed - containers should work normally now"
