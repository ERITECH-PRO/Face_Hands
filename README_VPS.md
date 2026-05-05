# ESP32 Face Recognition System - VPS Deployment

Deploy your ESP32 OV2640 face recognition system on a VPS with Docker.

## 🎯 Features

- **Real-time Face Recognition** using ESP32 OV2640 camera
- **Hand Tracking** when faces are recognized
- **Web Interface** for live viewing and management
- **Dockerized** for easy VPS deployment
- **REST API** for integration

## 📋 Prerequisites

- VPS with Docker and Docker Compose installed
- ESP32 OV2640 camera running on your local network
- Network connectivity between VPS and ESP32 camera

## 🚀 Quick Deployment

### 1. Clone and Configure

```bash
git clone <your-repo>
cd Face_Hands

# Copy environment template
cp .env.example .env

# Edit .env with your ESP32 IP
nano .env
```

### 2. Configure Environment

Edit `.env` file:

```bash
# ESP32 Camera IP (must be accessible from VPS)
STREAM_URL=http://192.168.110.150:81/stream

# Server settings
PUBLIC_PORT=8012
TOLERANCE=0.5
```

### 3. Deploy

```bash
# Make deploy script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh
```

## 🔧 Manual Deployment

### Using Docker Compose

```bash
# Build and start
docker-compose -f docker-compose.prod.yml up -d

# Check status
docker-compose -f docker-compose.prod.yml ps

# View logs
docker-compose -f docker-compose.prod.yml logs -f
```

### Using Docker directly

```bash
# Build image
docker build -t face-recognition .

# Run container
docker run -d \
  --name face-recognition \
  -p 8012:8000 \
  -e STREAM_URL=http://192.168.110.150:81/stream \
  -v $(pwd)/known_face:/app/known_face:ro \
  -v $(pwd)/data:/app/data \
  --restart unless-stopped \
  face-recognition
```

## 🌐 Access Points

Once deployed, access your system at:

- **Main Interface**: `http://your-vps-ip:8012`
- **Live Stream**: `http://your-vps-ip:8012/video.mjpeg`
- **Upload Faces**: `http://your-vps-ip:8012/upload`
- **API Health**: `http://your-vps-ip:8012/api/health`

## 📸 Adding Known Faces

### Method 1: Web Interface
1. Visit `http://your-vps-ip:8012/upload`
2. Enter person name
3. Upload face images
4. Images are stored in `known_face/[person_name]/`

### Method 2: Direct File Upload
```bash
# Create directory for person
mkdir -p known_face/JohnDoe

# Copy face images
cp john_face1.jpg known_face/JohnDoe/
cp john_face2.jpg known_face/JohnDoe/

# Restart container to reload faces
docker-compose restart
```

## 🔍 Network Configuration

### ESP32 Camera Access

The VPS must be able to reach your ESP32 camera. Options:

1. **VPN**: Set up VPN between VPS and local network
2. **Port Forwarding**: Forward ESP32 port 81 to internet
3. **Cloud ESP32**: Use ESP32 with internet connectivity

### Example Port Forwarding

```bash
# On your router, forward:
# External port: 8081 -> Internal IP: 192.168.110.150:81

# Then use in .env:
STREAM_URL=http://your-public-ip:8081/stream
```

## 🛠️ Troubleshooting

### Camera Connection Issues

```bash
# Check ESP32 connectivity from VPS
curl -I http://192.168.110.150:81/stream

# Test stream
curl http://192.168.110.150:81/stream | head
```

### Container Issues

```bash
# Check logs
docker-compose logs face-hands

# Restart container
docker-compose restart face-hands

# Rebuild if needed
docker-compose build --no-cache
```

### Performance Issues

Adjust environment variables:

```bash
# Lower resolution for better performance
FRAME_WIDTH=640
FRAME_HEIGHT=480

# Reduce JPEG quality for bandwidth
JPEG_QUALITY=60
```

## 📊 Monitoring

### Health Check

```bash
# Check API health
curl http://localhost:8012/api/health

# Expected response
{"ok": true, "stream_url": "http://192.168.110.150:81/stream"}
```

### Resource Usage

```bash
# Check container stats
docker stats face-hands

# Check disk usage
docker system df
```

## 🔒 Security Considerations

1. **Firewall**: Only expose necessary ports
2. **VPN**: Use VPN for ESP32 camera access
3. **Authentication**: Add reverse proxy with auth
4. **HTTPS**: Use SSL termination

### Example Nginx Reverse Proxy

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:8012;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # Add authentication if needed
    auth_basic "Restricted";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

## 📝 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `STREAM_URL` | `http://192.168.110.150:81/stream` | ESP32 camera stream URL |
| `TOLERANCE` | `0.5` | Face recognition tolerance |
| `MODEL` | `hog` | Face detection model (hog/cnn) |
| `PUBLIC_PORT` | `8012` | External port |
| `FRAME_WIDTH` | `1280` | Video frame width |
| `FRAME_HEIGHT` | `720` | Video frame height |
| `JPEG_QUALITY` | `80` | JPEG compression quality |

## 🔄 Updates

```bash
# Pull latest code
git pull

# Rebuild and restart
docker-compose build
docker-compose up -d
```

## 📞 Support

For issues:
1. Check container logs: `docker-compose logs -f`
2. Verify ESP32 connectivity
3. Check environment variables
4. Review network configuration
