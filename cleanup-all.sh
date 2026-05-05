#!/bin/bash

# Clean up all previous work and restore original state

echo "🧹 Cleaning up all previous work..."
echo "=================================="

# Stop and remove all containers
echo "🛑 Stopping all containers..."
docker-compose down 2>/dev/null || true
docker stop face-hands 2>/dev/null || true
docker rm face-hands 2>/dev/null || true

# Remove Docker images
echo "🗑️ Removing Docker images..."
docker rmi face-recognition:latest 2>/dev/null || true
docker system prune -f

# Remove WireGuard completely
echo "🗑️ Removing WireGuard..."
sudo systemctl stop wg-quick@wg0 2>/dev/null || true
sudo systemctl disable wg-quick@wg0 2>/dev/null || true
sudo apt remove --purge -y wireguard wireguard-tools 2>/dev/null || true
sudo rm -rf /etc/wireguard/ 2>/dev/null || true
sudo ip link del wg0 2>/dev/null || true

# Remove VPN configurations
echo "🗑️ Removing VPN configurations..."
rm -f wg0-server.conf wg0-client.conf server-public.key client-public.key
rm -f quick-vpn-setup.sh manual-vpn-setup.ps1 setup-vpn-windows.ps1
rm -f update-vps-config.sh fix-vps-wireguard.sh linux-vps-client-commands.sh
rm -f troubleshoot-vpn.sh switch-to-port-forwarding.sh

# Remove port forwarding configurations
echo "🗑️ Removing port forwarding configurations..."
rm -f setup-port-forwarding.sh setup-port-forwarding-fixed.ps1
rm -f port-forwarding-setup.sh

# Remove configuration files
echo "🗑️ Removing configuration files..."
rm -f .env docker-compose.yml docker-compose.prod.yml docker-compose.simple.yml
rm -f wg0-server.conf wg0-client.conf server-public.key client-public.key
rm -f *.sh *.ps1 *.py *.md *.conf *.key *.yml *.txt

# Remove directories
echo "🗑️ Removing directories..."
rm -rf known_face data .windsurf

# Reset git to original state
echo "🔄 Resetting git to original state..."
git reset --hard HEAD
git clean -fd
git checkout main

# Pull original files
echo "📥 Pulling original files..."
git pull origin main

echo "✅ Cleanup complete!"
echo ""
echo "🎯 Original state restored!"
echo "=================================="
echo "📁 Current files:"
ls -la

echo ""
echo "🌐 Next steps:"
echo "1. Start fresh with your original setup"
echo "2. Use: python local-python-esp32.py for local testing"
echo "3. Or: docker-compose up -d for Docker setup"
