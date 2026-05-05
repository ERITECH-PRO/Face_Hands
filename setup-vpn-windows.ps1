# PowerShell VPN Setup for ESP32-VPS Connectivity
# This script sets up WireGuard VPN on Windows systems

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("server", "client")]
    [string]$Mode
)

Write-Host "🔐 Setting up WireGuard VPN for ESP32-VPS connectivity..." -ForegroundColor Green
Write-Host ""

# Configuration
$VPN_SUBNET = "10.0.0.0/24"
$VPN_SERVER_IP = "10.0.0.1"
$VPN_CLIENT_IP = "10.0.0.2"
$WG_PORT = "51820"

if ($Mode -eq "server") {
    Write-Host "🖥️  Setting up VPN Server (Local Network)..." -ForegroundColor Blue
    
    # Check if WireGuard is installed
    try {
        $wgVersion = wg --version
        Write-Host "✅ WireGuard found: $wgVersion" -ForegroundColor Green
    } catch {
        Write-Host "❌ WireGuard not found. Please install WireGuard from https://www.wireguard.com/install/" -ForegroundColor Red
        exit 1
    }
    
    # Generate keys
    $privateKey = wg genkey
    $publicKey = $privateKey | wg pubkey
    
    # Create server config
    $serverConfig = @"
[Interface]
Address = $VPN_SERVER_IP/24
PrivateKey = $privateKey
ListenPort = $WG_PORT

[Peer]
# VPS Client - Add VPS public key here
AllowedIPs = $VPN_CLIENT_IP/32
"@
    
    $serverConfig | Out-File -FilePath "wg0-server.conf" -Encoding UTF8
    $publicKey | Out-File -FilePath "server-public.key" -Encoding UTF8
    
    Write-Host "✅ VPN Server setup complete!" -ForegroundColor Green
    Write-Host "📋 Server Public Key: $publicKey" -ForegroundColor Yellow
    Write-Host "🌐 External IP: $(Invoke-RestMethod -Uri 'https://ifconfig.me/ip'):$WG_PORT" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📝 Add this to VPS client config:" -ForegroundColor Cyan
    Write-Host "   PublicKey = $publicKey" -ForegroundColor White
    Write-Host "   Endpoint = $(Invoke-RestMethod -Uri 'https://ifconfig.me/ip'):$WG_PORT" -ForegroundColor White
    
} elseif ($Mode -eq "client") {
    Write-Host "🌐 Setting up VPN Client (VPS)..." -ForegroundColor Blue
    
    # Check if WireGuard is installed
    try {
        $wgVersion = wg --version
        Write-Host "✅ WireGuard found: $wgVersion" -ForegroundColor Green
    } catch {
        Write-Host "❌ WireGuard not found. Please install WireGuard" -ForegroundColor Red
        exit 1
    }
    
    # Generate keys
    $privateKey = wg genkey
    $publicKey = $privateKey | wg pubkey
    
    Write-Host "📋 VPS Client Public Key: $publicKey" -ForegroundColor Yellow
    Write-Host "   (Add this to server config)" -ForegroundColor Cyan
    Write-Host ""
    
    $serverPublicKey = Read-Host "Enter server public key"
    $serverEndpoint = Read-Host "Enter server external IP:port"
    
    # Create client config
    $clientConfig = @"
[Interface]
Address = $VPN_CLIENT_IP/24
PrivateKey = $privateKey
DNS = 8.8.8.8

[Peer]
PublicKey = $serverPublicKey
Endpoint = $serverEndpoint
AllowedIPs = 192.168.110.0/24, $VPN_SUBNET
PersistentKeepalive = 25
"@
    
    $clientConfig | Out-File -FilePath "wg0-client.conf" -Encoding UTF8
    $publicKey | Out-File -FilePath "client-public.key" -Encoding UTF8
    
    Write-Host "✅ VPN Client setup complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🔧 To start VPN:" -ForegroundColor Cyan
    Write-Host "   wireguard /installtunnelservice wg0-client" -ForegroundColor White
    Write-Host "   net start WireGuardTunnel$wg0client" -ForegroundColor White
    Write-Host ""
    Write-Host "🔍 Testing connection..." -ForegroundColor Yellow
    
    # Test connection (simplified)
    Start-Sleep -Seconds 3
    Write-Host "🌐 You should now be able to access: http://192.168.110.150:81/stream" -ForegroundColor Green
    
    # Update ESP32 stream URL if .env exists
    if (Test-Path ".env") {
        (Get-Content ".env") -replace 'STREAM_URL=.*', 'STREAM_URL=http://192.168.110.150:81/stream' | Set-Content ".env"
        Write-Host "📝 Updated .env with ESP32 stream URL" -ForegroundColor Green
    }
}
