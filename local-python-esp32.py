#!/usr/bin/env python3
"""
Local Python script to connect directly to ESP32 camera
This runs on your local Windows machine and connects to ESP32 at 192.168.110.150:81
"""

import cv2
import numpy as np
import requests
import face_recognition
import mediapipe as mp
from io import BytesIO
import time
import threading
import os

# ESP32 Camera Configuration
ESP32_STREAM_URL = "http://192.168.110.150:81/stream"
ESP32_SNAPSHOT_URL = "http://192.168.110.150/snapshot"

# Face Recognition Settings
TOLERANCE = 0.5
MODEL = "hog"

# Initialize MediaPipe
mp_face_detection = mp.solutions.face_detection
mp_hands = mp.solutions.hands

def stream_from_esp32():
    """Connect to ESP32 MJPEG stream and process frames"""
    print(f"🔗 Connecting to ESP32: {ESP32_STREAM_URL}")
    
    try:
        # Connect to ESP32 stream
        response = requests.get(ESP32_STREAM_URL, stream=True, timeout=10)
        response.raise_for_status()
        
        print("✅ Connected to ESP32 stream!")
        
        # Process MJPEG stream
        bytes_data = b''
        
        for chunk in response.iter_content(chunk_size=1024):
            bytes_data += chunk
            
            # Find JPEG boundaries
            a = bytes_data.find(b'\xff\xd8')
            b = bytes_data.find(b'\xff\xd9')
            
            if a != -1 and b != -1:
                # Extract JPEG frame
                jpg_data = bytes_data[a:b+2]
                bytes_data = bytes_data[b+2:]
                
                try:
                    # Decode JPEG
                    nparr = np.frombuffer(jpg_data, np.uint8)
                    frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                    
                    if frame is not None:
                        continue
                    
                    # Process frame for face recognition
                    process_frame(frame)
                    
                except Exception as e:
                    print(f"⚠️ Frame processing error: {e}")
                    
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection error: {e}")
        print(f"🔄 Retrying in 5 seconds...")
        time.sleep(5)
        return stream_from_esp32()
        
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        return None

def process_frame(frame):
    """Process frame for face and hand detection"""
    try:
        # Convert to RGB for face recognition
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # Face detection
        face_locations = face_recognition.face_locations(rgb_frame, model=MODEL)
        
        # Hand detection
        rgb_frame_hands = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results_hands = mp_hands.process(rgb_frame_hands)
        
        # Draw face rectangles
        for (top, right, bottom, left) in face_locations:
            cv2.rectangle(frame, (left, top), (right, bottom), (0, 255, 0), 2)
            cv2.putText(frame, "Face Detected", (left, top-10), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
        
        # Draw hand landmarks
        if results_hands.multi_hand_landmarks:
            for hand_landmarks in results_hands.multi_hand_landmarks:
                mp.solutions.drawing_utils.draw_landmarks(
                    frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
        
        # Display status
        status_text = f"Faces: {len(face_locations)} | Hands: {len(results_hands.multi_hand_landmarks) if results_hands.multi_hand_landmarks else 0}"
        cv2.putText(frame, status_text, (10, 30), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        
        # Show frame
        cv2.imshow('ESP32 Face & Hand Recognition', frame)
        
        # Exit on 'q' key
        if cv2.waitKey(1) & 0xFF == ord('q'):
            return False
            
    except Exception as e:
        print(f"⚠️ Frame processing error: {e}")
        return True

def main():
    """Main function"""
    print("🚀 Starting ESP32 Face Recognition (Local)")
    print("=====================================")
    print(f"📹 ESP32 Stream URL: {ESP32_STREAM_URL}")
    print(f"🎯 Face Recognition Tolerance: {TOLERANCE}")
    print(f"🤚 Hand Tracking: Enabled")
    print("")
    print("Controls:")
    print("  'q' - Quit")
    print("  's' - Save snapshot")
    print("")
    
    # Start streaming
    stream_result = stream_from_esp32()
    
    if stream_result is None:
        print("❌ Failed to start stream")
        return
    
    print("✅ Stream ended successfully")

if __name__ == "__main__":
    main()
