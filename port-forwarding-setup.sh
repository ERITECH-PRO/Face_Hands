#!/bin/bash

# Port Forwarding Setup Guide for ESP32 Camera
# This script helps configure port forwarding for ESP32-VPS connectivity

set -e

echo "🌐 Setting up Port Forwarding for ESP32 Camera..."
echo

ESP32_IP="192.168.110.150"
ESP32_PORT="81"
EXTERNAL_PORT="8181"

# Get public IP
get_public_ip() {
    curl -s ifconfig.me 2>/dev/null || \
    curl -s ipinfo.io/ip 2>/dev/null || \
    curl -s icanhazip.com 2>/dev/null || \
    echo "YOUR_PUBLIC_IP"
}

PUBLIC_IP=$(get_public_ip)

echo "📋 Configuration:"
echo "   ESP32 Local IP: $ESP32_IP:$ESP32_PORT"
echo "   External Port: $EXTERNAL_PORT"
echo "   Public IP: $PUBLIC_IP"
echo

echo "🔧 Router Setup Instructions:"
echo "1. Access your router admin panel (usually: 192.168.1.1)"
echo "2. Find 'Port Forwarding' or 'NAT' section"
echo "3. Create new rule with these settings:"
echo "   - External Port: $EXTERNAL_PORT"
echo "   - Internal Port: $ESP32_PORT"
echo "   - Internal IP: $ESP32_IP"
echo "   - Protocol: TCP"
echo "   - Enable: Yes"
echo

# Test port forwarding
test_port_forwarding() {
    echo "🔍 Testing port forwarding..."
    
    # Test local ESP32 first
    if timeout 5 bash -c "</dev/tcp/$ESP32_IP/$ESP32_PORT" 2>/dev/null; then
        echo "✅ ESP32 is accessible locally"
    else
        echo "❌ ESP32 not accessible locally - check ESP32 is running"
        return 1
    fi
    
    # Test external access
    echo "🌐 Testing external access to $PUBLIC_IP:$EXTERNAL_PORT..."
    if timeout 10 bash -c "</dev/tcp/$PUBLIC_IP/$EXTERNAL_PORT" 2>/dev/null; then
        echo "✅ Port forwarding is working!"
        return 0
    else
        echo "❌ Port forwarding not working"
        echo "   Check:"
        echo "   - Router port forwarding rules"
        echo "   - Firewall settings"
        echo "   - ISP blocking ports"
        return 1
    fi
}

# Update configuration files
update_config() {
    echo "📝 Updating configuration files..."
    
    # Update .env file
    if [ -f .env ]; then
        sed -i "s|STREAM_URL=.*|STREAM_URL=http://$PUBLIC_IP:$EXTERNAL_PORT/stream|" .env
        echo "✅ Updated .env with: http://$PUBLIC_IP:$EXTERNAL_PORT/stream"
    else
        echo "STREAM_URL=http://$PUBLIC_IP:$EXTERNAL_PORT/stream" > .env
        echo "✅ Created .env with stream URL"
    fi
    
    # Restart Docker service if running
    if docker ps | grep -q "face-hands"; then
        docker restart face-hands
        echo "🔄 Restarted face recognition service"
    fi
}

# Security check
security_warning() {
    echo "⚠️  Security Warning:"
    echo "   Port forwarding exposes your ESP32 to the internet"
    echo "   Consider these security measures:"
    echo "   - Change default ESP32 passwords"
    echo "   - Use firewall rules to restrict access"
    echo "   - Consider VPN for better security"
    echo "   - Monitor access logs"
    echo
}

# Main execution
main() {
    echo "Choose action:"
    echo "1) Test current setup"
    echo "2) Update configuration"
    echo "3) Show security info"
    echo "4) Full setup (test + update)"
    echo
    
    read -p "Enter choice (1-4): " choice
    
    case $choice in
        1)
            test_port_forwarding
            ;;
        2)
            update_config
            ;;
        3)
            security_warning
            ;;
        4)
            if test_port_forwarding; then
                update_config
                echo
                echo "🎉 Setup complete!"
                echo "🌐 Access your camera at: http://$PUBLIC_IP:$EXTERNAL_PORT/stream"
                echo "📱 Face recognition at: http://your-vps-ip:8012"
            else
                echo "❌ Setup failed - fix issues and retry"
            fi
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
}

# Run main function
main
