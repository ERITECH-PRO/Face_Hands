#!/usr/bin/env python3
"""
Cloud ESP32 Setup for Face Recognition
This script configures ESP32 to stream to cloud service accessible by VPS
"""

import paho.mqtt.client as mqtt
import requests
import json
import time
import base64
from io import BytesIO
import cv2
import numpy as np

# MQTT Configuration
MQTT_BROKER = "broker.hivemq.com"  # Free public broker
MQTT_PORT = 1883
MQTT_TOPIC = "esp32_camera_stream"
MQTT_CLIENT_ID = "esp32_face_recognition"

# ESP32 Camera Configuration (for testing locally)
ESP32_STREAM_URL = "http://192.168.110.150:81/stream"

class CloudStreamBridge:
    def __init__(self):
        self.mqtt_client = mqtt.Client(MQTT_CLIENT_ID)
        self.mqtt_client.on_connect = self.on_connect
        self.mqtt_client.on_message = self.on_message
        
        # Frame buffer
        self.frame_buffer = []
        self.max_buffer_size = 10
        
    def on_connect(self, client, userdata, flags, rc):
        """MQTT connection callback"""
        if rc == 0:
            print("✅ Connected to MQTT broker")
            client.subscribe(MQTT_TOPIC)
        else:
            print(f"❌ Failed to connect to MQTT broker: {rc}")
    
    def on_message(self, client, userdata, msg):
        """Handle incoming MQTT messages"""
        try:
            # Decode base64 image
            image_data = base64.b64decode(msg.payload)
            nparr = np.frombuffer(image_data, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if frame is not None:
                self.frame_buffer.append(frame)
                if len(self.frame_buffer) > self.max_buffer_size:
                    self.frame_buffer.pop(0)
                    
        except Exception as e:
            print(f"❌ Error processing frame: {e}")
    
    def connect_mqtt(self):
        """Connect to MQTT broker"""
        try:
            self.mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
            self.mqtt_client.loop_start()
            return True
        except Exception as e:
            print(f"❌ MQTT connection failed: {e}")
            return False
    
    def get_latest_frame(self):
        """Get the latest frame from buffer"""
        return self.frame_buffer[-1] if self.frame_buffer else None

def esp32_to_mqtt_stream():
    """Bridge ESP32 stream to MQTT"""
    print("🌐 Starting ESP32 to MQTT bridge...")
    
    bridge = CloudStreamBridge()
    
    if not bridge.connect_mqtt():
        print("❌ Failed to setup MQTT connection")
        return
    
    try:
        response = requests.get(ESP32_STREAM_URL, stream=True, timeout=10)
        response.raise_for_status()
        
        bytes_data = b''
        frame_count = 0
        
        for chunk in response.iter_content(chunk_size=1024):
            bytes_data += chunk
            a = bytes_data.find(b'\xff\xd8')
            b = bytes_data.find(b'\xff\xd9')
            
            if a != -1 and b != -1:
                jpg = bytes_data[a:b+2]
                bytes_data = bytes_data[b+2:]
                
                try:
                    # Convert to base64 for MQTT
                    frame_b64 = base64.b64encode(jpg).decode('utf-8')
                    
                    # Publish to MQTT
                    bridge.mqtt_client.publish(MQTT_TOPIC, frame_b64)
                    
                    frame_count += 1
                    if frame_count % 30 == 0:
                        print(f"📹 Streamed {frame_count} frames")
                        
                except Exception as e:
                    print(f"❌ Error streaming frame: {e}")
                    
    except Exception as e:
        print(f"❌ ESP32 connection error: {e}")

def mqtt_to_face_recognition():
    """Receive MQTT stream and process for face recognition"""
    print("🤖 Starting MQTT to Face Recognition bridge...")
    
    bridge = CloudStreamBridge()
    
    if not bridge.connect_mqtt():
        print("❌ Failed to setup MQTT connection")
        return
    
    # Import face recognition modules
    try:
        import face_recognition
        import mediapipe as mp
        
        # Initialize face recognition
        known_encodings = []
        known_names = []
        
        # Load known faces (simplified)
        # TODO: Implement your face loading logic here
        
        print("✅ Face recognition modules loaded")
        
    except ImportError as e:
        print(f"❌ Missing face recognition modules: {e}")
        return
    
    print("🔄 Waiting for frames...")
    
    while True:
        frame = bridge.get_latest_frame()
        if frame is not None:
            try:
                # Process frame for face recognition
                rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                
                # Face detection (simplified)
                locations = face_recognition.face_locations(rgb, model="hog")
                
                # Draw rectangles around faces
                for (top, right, bottom, left) in locations:
                    cv2.rectangle(frame, (left, top), (right, bottom), (0, 255, 0), 2)
                    cv2.putText(frame, "Face", (left, top-10), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)
                
                # Display result
                cv2.imshow("Cloud Face Recognition", frame)
                
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
                    
            except Exception as e:
                print(f"❌ Face processing error: {e}")
        
        time.sleep(0.033)  # ~30 FPS

def generate_esp32_code():
    """Generate ESP32 code for MQTT streaming"""
    esp32_code = '''
/*
 * ESP32 Camera MQTT Streaming
 * Add this to your ESP32 camera sketch
 */

#include <WiFi.h>
#include <esp_camera.h>
#include <PubSubClient.h>
#include <base64.h>

// WiFi Configuration
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// MQTT Configuration
const char* mqtt_server = "broker.hivemq.com";
const int mqtt_port = 1883;
const char* mqtt_topic = "esp32_camera_stream";
const char* mqtt_client_id = "esp32_camera_1";

WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);

// Camera configuration (adjust for your model)
camera_config_t config;
#define CAMERA_MODEL_AI_THINKER

void setup() {
  Serial.begin(115200);
  
  // Connect to WiFi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\\nWiFi connected");
  
  // Setup camera
  setupCamera();
  
  // Setup MQTT
  mqttClient.setServer(mqtt_server, mqtt_port);
}

void setupCamera() {
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  
  if (psramFound()) {
    config.frame_size = FRAMESIZE_SVGA;
    config.jpeg_quality = 12;
    config.fb_count = 2;
  } else {
    config.frame_size = FRAMESIZE_CIF;
    config.jpeg_quality = 12;
    config.fb_count = 1;
  }
  
  esp_camera_init(&config);
}

void loop() {
  if (!mqttClient.connected()) {
    reconnectMQTT();
  }
  
  // Capture and stream frame
  camera_fb_t* fb = esp_camera_fb_get();
  if (fb) {
    // Encode to base64
    String encoded = base64::encode(fb->buf, fb->len);
    
    // Publish to MQTT
    mqttClient.publish(mqtt_topic, encoded.c_str());
    
    esp_camera_fb_return(fb);
  }
  
  mqttClient.loop();
  delay(33); // ~30 FPS
}

void reconnectMQTT() {
  while (!mqttClient.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (mqttClient.connect(mqtt_client_id)) {
      Serial.println("connected");
    } else {
      Serial.print("failed, rc=");
      Serial.print(mqttClient.state());
      delay(5000);
    }
  }
}
'''
    
    with open("esp32_mqtt_stream.ino", "w") as f:
        f.write(esp32_code)
    
    print("✅ ESP32 MQTT code generated: esp32_mqtt_stream.ino")
    print("📝 Update WiFi credentials and upload to ESP32")

if __name__ == "__main__":
    print("🌐 Cloud ESP32 Setup Options:")
    print("1) Bridge ESP32 to MQTT (run on local network)")
    print("2) Receive MQTT stream for face recognition (run on VPS)")
    print("3) Generate ESP32 MQTT code")
    print()
    
    choice = input("Enter choice (1-3): ").strip()
    
    if choice == "1":
        esp32_to_mqtt_stream()
    elif choice == "2":
        mqtt_to_face_recognition()
    elif choice == "3":
        generate_esp32_code()
    else:
        print("❌ Invalid choice")
