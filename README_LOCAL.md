# Local ESP32 Face Recognition Setup

This guide covers setting up ESP32 face recognition locally on Windows without VPS deployment.

## 🎯 Local Setup Overview

Instead of deploying to VPS, you can run the face recognition system directly on your Windows machine.

## 📋 Prerequisites

1. **Python 3.7+** installed on Windows
2. **Required Python packages**:
   ```cmd
   pip install opencv-python numpy requests face-recognition mediapipe
   ```
3. **ESP32 Camera** on same WiFi network (192.168.110.150)

## 🚀 Quick Start

### Option 1: Run Local Python Script

1. **Install dependencies**:
   ```cmd
   pip install opencv-python numpy requests face-recognition mediapipe
   ```

2. **Run the script**:
   ```cmd
   python local-python-esp32.py
   ```

### Option 2: Use Existing Docker Setup

1. **Update .env for local ESP32**:
   ```env
   STREAM_URL=http://192.168.110.150:81/stream
   ```

2. **Run Docker locally**:
   ```cmd
   docker-compose up -d
   ```

## 📁 Directory Structure

```
Face_Hands/
├── known_face/
│   ├── Person1/
│   │   ├── image1.jpg
│   │   └── image2.jpg
│   └── Person2/
│       └── image1.jpg
├── data/
├── local-python-esp32.py
├── server.py
├── requirements.txt
├── .env
└── docker-compose.yml
```

## 🎮 Local Python Script Features

The `local-python-esp32.py` script provides:

- ✅ **Direct ESP32 connection** (no network complexity)
- ✅ **Real-time face detection** using face_recognition library
- ✅ **Hand tracking** using MediaPipe
- ✅ **Live video display** with detection overlays
- ✅ **Keyboard controls** for interaction

## 📱 Adding Known Faces

1. **Create folders** for each person:
   ```
   known_face/
   ├── John_Doe/
   │   ├── photo1.jpg
   │   └── photo2.jpg
   └── Jane_Smith/
       └── photo1.jpg
   ```

2. **Script will automatically** detect and recognize faces from these folders

## 🔧 Configuration Options

### Face Recognition Settings
- `TOLERANCE=0.5` - Face recognition sensitivity (0.0-1.0)
- `MODEL=hog` - Detection model (hog/cnn)

### ESP32 Camera Settings
- `ESP32_STREAM_URL=http://192.168.110.150:81/stream`
- `ESP32_SNAPSHOT_URL=http://192.168.110.150/snapshot`

## 🎯 Benefits of Local Setup

- ⚡ **No network latency** - Direct WiFi connection
- 🔧 **Easy debugging** - Immediate feedback
- 💾 **Local storage** - No cloud dependencies
- 🎮 **Interactive testing** - Real-time controls
- 🚀 **Fast development** - Quick iteration cycles

## 🌐 Access URLs (Local)

When running locally:
- **Main Interface**: `http://localhost:8012`
- **Live Stream**: `http://localhost:8012/video.mjpeg`
- **Upload Faces**: `http://localhost:8012/upload`
- **API Health**: `http://localhost:8012/api/health`

## 🔄 Management Commands

```cmd
# Start local Docker
docker-compose up -d

# View logs
docker logs -f face-hands

# Stop service
docker-compose down

# Restart service
docker-compose restart
```

## 🎯 When to Use Local vs VPS

### Use Local Setup When:
- ✅ Testing and development
- ✅ Network issues with VPS
- ✅ Privacy concerns
- ✅ Fast iteration needed

### Use VPS Setup When:
- ✅ Production deployment
- ✅ Remote access required
- ✅ 24/7 availability needed
- ✅ Multiple users need access

## 🚀 Getting Started

1. **Run local script first** to verify ESP32 connection:
   ```cmd
   python local-python-esp32.py
   ```

2. **Add known faces** to test recognition:
   - Create folders in `known_face/`
   - Add 2-3 photos per person
   - Test face detection accuracy

3. **Optional: Deploy to VPS** when ready for production

This local setup provides a simple, reliable way to test your ESP32 face recognition system without network complexity!
