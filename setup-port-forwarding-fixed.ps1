# PowerShell Port Forwarding Setup for ESP32 Camera (Fixed)
# This script helps configure port forwarding for ESP32-VPS connectivity

param(
    [Parameter()]
    [ValidateSet("test", "update", "security", "full")]
    [string]$Action = "full"
)

Write-Host "Setting up Port Forwarding for ESP32 Camera..." -ForegroundColor Green
Write-Host ""

# Configuration
$ESP32_IP = "192.168.110.150"
$ESP32_PORT = "81"
$EXTERNAL_PORT = "8181"

# Get public IP
function Get-PublicIP {
    try {
        return (Invoke-RestMethod -Uri 'https://ifconfig.me/ip' -TimeoutSec 5)
    } catch {
        try {
            return (Invoke-RestMethod -Uri 'https://ipinfo.io/ip' -TimeoutSec 5)
        } catch {
            try {
                return (Invoke-RestMethod -Uri 'https://icanhazip.com' -TimeoutSec 5)
            } catch {
                return "YOUR_PUBLIC_IP"
            }
        }
    }
}

$PUBLIC_IP = Get-PublicIP

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "   ESP32 Local IP: $ESP32_IP`:$ESP32_PORT" -ForegroundColor White
Write-Host "   External Port: $EXTERNAL_PORT" -ForegroundColor White
Write-Host "   Public IP: $PUBLIC_IP" -ForegroundColor White
Write-Host ""

# Test port forwarding
function Test-PortForwarding {
    Write-Host "Testing port forwarding..." -ForegroundColor Yellow
    
    # Test local ESP32 first
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($ESP32_IP, $ESP32_PORT)
        $tcpClient.Close()
        Write-Host "ESP32 is accessible locally" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "ESP32 not accessible locally - check ESP32 is running" -ForegroundColor Red
        return $false
    }
}

# Update configuration files
function Update-Config {
    Write-Host "Updating configuration files..." -ForegroundColor Yellow
    
    # Update .env file
    if (Test-Path ".env") {
        $envContent = Get-Content ".env"
        $envContent = $envContent -replace 'STREAM_URL=.*', "STREAM_URL=http://$PUBLIC_IP`:$EXTERNAL_PORT/stream"
        $envContent | Set-Content ".env"
        Write-Host "Updated .env with: http://$PUBLIC_IP`:$EXTERNAL_PORT/stream" -ForegroundColor Green
    } else {
        "STREAM_URL=http://$PUBLIC_IP`:$EXTERNAL_PORT/stream" | Out-File ".env"
        Write-Host "Created .env with stream URL" -ForegroundColor Green
    }
    
    # Restart Docker service if running
    try {
        $dockerStatus = docker ps --filter "name=face-hands" --format "{{.Names}}" 2>$null
        if ($dockerStatus -eq "face-hands") {
            docker restart face-hands
            Write-Host "Restarted face recognition service" -ForegroundColor Green
        }
    } catch {
        Write-Host "Docker not available or service not running" -ForegroundColor Yellow
    }
}

# Security warning
function Show-SecurityWarning {
    Write-Host "Security Warning:" -ForegroundColor Red
    Write-Host "   Port forwarding exposes your ESP32 to internet" -ForegroundColor Yellow
    Write-Host "   Consider these security measures:" -ForegroundColor Cyan
    Write-Host "   - Change default ESP32 passwords" -ForegroundColor White
    Write-Host "   - Use firewall rules to restrict access" -ForegroundColor White
    Write-Host "   - Consider VPN for better security" -ForegroundColor White
    Write-Host "   - Monitor access logs" -ForegroundColor White
    Write-Host ""
}

# Router setup instructions
function Show-RouterInstructions {
    Write-Host "Router Setup Instructions:" -ForegroundColor Cyan
    Write-Host "1. Access your router admin panel (usually: 192.168.1.1)" -ForegroundColor White
    Write-Host "2. Find 'Port Forwarding' or 'NAT' section" -ForegroundColor White
    Write-Host "3. Create new rule with these settings:" -ForegroundColor White
    Write-Host "   - External Port: $EXTERNAL_PORT" -ForegroundColor Gray
    Write-Host "   - Internal Port: $ESP32_PORT" -ForegroundColor Gray
    Write-Host "   - Internal IP: $ESP32_IP" -ForegroundColor Gray
    Write-Host "   - Protocol: TCP" -ForegroundColor Gray
    Write-Host "   - Enable: Yes" -ForegroundColor Gray
    Write-Host ""
}

# Main execution
switch ($Action) {
    "test" {
        Test-PortForwarding
    }
    "update" {
        Update-Config
    }
    "security" {
        Show-SecurityWarning
    }
    "full" {
        Show-RouterInstructions
        if (Test-PortForwarding) {
            Update-Config
            Write-Host ""
            Write-Host "Setup complete!" -ForegroundColor Green
            Write-Host "Access your camera at: http://$PUBLIC_IP`:$EXTERNAL_PORT/stream" -ForegroundColor Yellow
            Write-Host "Face recognition at: http://your-vps-ip:8012" -ForegroundColor Yellow
        } else {
            Write-Host "Setup failed - fix issues and retry" -ForegroundColor Red
        }
    }
    default {
        Write-Host "Invalid action: $Action" -ForegroundColor Red
        Write-Host "Valid actions: test, update, security, full" -ForegroundColor Yellow
        exit 1
    }
}
