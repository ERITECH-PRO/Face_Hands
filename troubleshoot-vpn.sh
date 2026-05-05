#!/bin/bash

# Troubleshoot VPN connection issues

echo "🔧 VPN Connection Troubleshooting"
echo "================================="
echo

echo "📊 Current WireGuard status:"
sudo wg show
echo

echo "🌐 Network interface status:"
ip addr show wg0
echo

echo "🔍 Testing connectivity..."

# Test 1: Can VPS reach Windows server?
echo "1. Testing VPS to Windows server:"
if ping -c 3 196.179.202.142 >/dev/null 2>&1; then
    echo "✅ VPS can reach Windows server"
else
    echo "❌ VPS cannot reach Windows server"
    echo "   Check: Windows firewall allows ICMP"
fi

# Test 2: Is Windows WireGuard listening?
echo "2. Testing Windows WireGuard port:"
if timeout 5 bash -c "</dev/tcp/196.179.202.142/51820" 2>/dev/null; then
    echo "✅ Windows WireGuard port is open"
else
    echo "❌ Windows WireGuard port is blocked"
    echo "   Check: Windows firewall allows UDP 51820"
fi

# Test 3: Can we ping Windows VPN IP?
echo "3. Testing VPN tunnel:"
if ping -c 3 10.0.0.1 >/dev/null 2>&1; then
    echo "✅ VPN tunnel is working"
else
    echo "❌ VPN tunnel not working"
    echo "   Check: WireGuard configuration"
fi

# Test 4: Can we reach ESP32 through VPN?
echo "4. Testing ESP32 access through VPN:"
if ping -c 2 192.168.110.150 >/dev/null 2>&1; then
    echo "✅ Can reach ESP32 through VPN"
else
    echo "❌ Cannot reach ESP32 through VPN"
    echo "   Check: ESP32 is on local network"
fi

# Test 5: Direct ESP32 test
echo "5. Testing ESP32 HTTP stream:"
if curl -s --connect-timeout 3 http://192.168.110.150:81/stream >/dev/null; then
    echo "✅ ESP32 HTTP stream is accessible"
else
    echo "❌ ESP32 HTTP stream not accessible"
    echo "   Check: ESP32 camera is running"
fi

echo
echo "🔧 Common fixes:"
echo

# Check Windows firewall
echo "Windows Firewall (run on Windows):"
echo "1. Open Windows Defender Firewall"
echo "2. Allow WireGuard: UDP 51820"
echo "3. Allow ping: ICMPv4"
echo

# Check VPS firewall
echo "VPS Firewall:"
echo "sudo ufw allow 51820/udp"
echo "sudo ufw allow out 196.179.202.142"
echo

echo "🔄 Restart WireGuard:"
echo "# On VPS:"
echo "sudo wg-quick down /etc/wireguard/wg0.conf"
echo "sudo wg-quick up /etc/wireguard/wg0.conf"
echo

echo "# On Windows:"
echo "1. Deactivate tunnel in WireGuard app"
echo "2. Reactivate tunnel"
echo

echo "🌐 Alternative: Port Forwarding Setup:"
echo "If VPN continues to fail, try port forwarding:"
echo "1. On Windows router: External 8181 -> 192.168.110.150:81"
echo "2. On VPS: echo 'STREAM_URL=http://196.179.202.142:8181/stream' >> .env"
echo "3. Restart: docker restart face-hands"
