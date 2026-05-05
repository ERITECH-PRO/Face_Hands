# Manual VPN Setup - Find WireGuard and Create Config
# This script finds WireGuard installation and creates proper config files

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("server", "client")]
    [string]$Mode
)

Write-Host "Manual WireGuard VPN Setup" -ForegroundColor Green
Write-Host ""

# Find WireGuard installation
$wgPaths = @(
    "C:\Program Files\WireGuard\wg.exe",
    "C:\Program Files (x86)\WireGuard\wg.exe",
    "${env:ProgramFiles}\WireGuard\wg.exe",
    "${env:ProgramFiles(x86)}\WireGuard\wg.exe"
)

$wgPath = $null
foreach ($path in $wgPaths) {
    if (Test-Path $path) {
        $wgPath = $path
        Write-Host "Found WireGuard at: $wgPath" -ForegroundColor Green
        break
    }
}

if (-not $wgPath) {
    Write-Host "WireGuard not found in standard locations" -ForegroundColor Red
    Write-Host "Please install from: https://www.wireguard.com/install/" -ForegroundColor Yellow
    exit 1
}

if ($Mode -eq "server") {
    Write-Host "=== Creating VPN Server Config ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Generate keys using full path
    $privateKey = & $wgPath genkey
    $publicKey = $privateKey | & $wgPath pubkey
    
    Write-Host "Keys generated successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Create server config (without BOM)
    $serverConfig = @"
[Interface]
Address = 10.0.0.1/24
PrivateKey = $privateKey
ListenPort = 51820

[Peer]
# VPS Client - Add VPS public key here
AllowedIPs = 10.0.0.2/32
"@
    
    # Save with UTF-8 without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText("$(Resolve-Path .)\wg0-server.conf", $serverConfig, $utf8NoBom)
    [System.IO.File]::WriteAllText("$(Resolve-Path .)\server-public.key", $publicKey, $utf8NoBom)
    
    Write-Host "Files created:" -ForegroundColor Yellow
    Write-Host "  - wg0-server.conf" -ForegroundColor White
    Write-Host "  - server-public.key" -ForegroundColor White
    Write-Host ""
    
    try {
        $publicIP = Invoke-RestMethod -Uri 'https://ifconfig.me/ip' -TimeoutSec 5
    } catch {
        $publicIP = "YOUR_PUBLIC_IP"
    }
    
    Write-Host "=== SERVER INFORMATION ===" -ForegroundColor Cyan
    Write-Host "Server Public Key: $publicKey" -ForegroundColor Yellow
    Write-Host "External IP:Port: $publicIP`:51820" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== NEXT STEPS ===" -ForegroundColor Cyan
    Write-Host "1. Open WireGuard application" -ForegroundColor White
    Write-Host "2. Click 'Importer le(s) tunnel(s) à partir du fichier'" -ForegroundColor White
    Write-Host "3. Select 'wg0-server.conf'" -ForegroundColor White
    Write-Host "4. Click 'Activate'" -ForegroundColor White
    Write-Host ""
    Write-Host "Send the Server Public Key to your VPS!" -ForegroundColor Green
    
} elseif ($Mode -eq "client") {
    Write-Host "=== Linux VPS Client Setup ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Run these commands on your Linux VPS:" -ForegroundColor White
    Write-Host ""
    Write-Host "# Install WireGuard" -ForegroundColor Gray
    Write-Host "sudo apt update && sudo apt install -y wireguard" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "# Generate keys" -ForegroundColor Gray
    Write-Host "wg genkey | sudo tee /etc/wireguard/client_private.key" -ForegroundColor Yellow
    Write-Host "sudo chmod 600 /etc/wireguard/client_private.key" -ForegroundColor Yellow
    Write-Host "sudo cat /etc/wireguard/client_private.key | wg pubkey | sudo tee /etc/wireguard/client_public.key" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "# Create client config" -ForegroundColor Gray
    Write-Host "sudo tee /etc/wireguard/wg0.conf << 'EOF'" -ForegroundColor Yellow
    Write-Host "[Interface]" -ForegroundColor White
    Write-Host "Address = 10.0.0.2/24" -ForegroundColor White
    Write-Host "PrivateKey = \$(cat /etc/wireguard/client_private.key)" -ForegroundColor White
    Write-Host "DNS = 8.8.8.8" -ForegroundColor White
    Write-Host ""
    Write-Host "[Peer]" -ForegroundColor White
    Write-Host "PublicKey = SERVER_PUBLIC_KEY_HERE" -ForegroundColor White
    Write-Host "Endpoint = SERVER_PUBLIC_IP:51820" -ForegroundColor White
    Write-Host "AllowedIPs = 192.168.110.0/24, 10.0.0.0/24" -ForegroundColor White
    Write-Host "PersistentKeepalive = 25" -ForegroundColor White
    Write-Host "EOF" -ForegroundColor White
    Write-Host ""
    Write-Host "# Start WireGuard" -ForegroundColor Gray
    Write-Host "sudo systemctl enable wg-quick@wg0" -ForegroundColor Yellow
    Write-Host "sudo systemctl start wg-quick@wg0" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "# Test connection" -ForegroundColor Gray
    Write-Host "ping 10.0.0.1" -ForegroundColor Yellow
    Write-Host "curl -I http://192.168.110.150:81/stream" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "# Update ESP32 stream URL" -ForegroundColor Gray
    Write-Host "echo 'STREAM_URL=http://192.168.110.150:81/stream' >> .env" -ForegroundColor Yellow
    Write-Host "docker restart face-hands" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Replace SERVER_PUBLIC_KEY_HERE with your Windows server public key" -ForegroundColor Red
    Write-Host "Replace SERVER_PUBLIC_IP with your Windows public IP" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== PORT FORWARDING ALTERNATIVE ===" -ForegroundColor Magenta
Write-Host "If VPN is too complex, try port forwarding:" -ForegroundColor White
Write-Host ""
Write-Host "1. Configure router: External 8181 -> Internal 192.168.110.150:81" -ForegroundColor Gray
Write-Host "2. Run: .\setup-port-forwarding-fixed.ps1" -ForegroundColor Yellow
Write-Host "3. Much simpler setup!" -ForegroundColor Green
