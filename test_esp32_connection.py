import requests
import cv2
import numpy as np
from io import BytesIO

ESP32_IP = "192.168.110.150"
ESP32_STREAM_URL = f"http://{ESP32_IP}:81/stream"

def test_esp32_connection():
    """Test connection to ESP32 camera and display a few frames"""
    print(f"🔍 Testing ESP32 camera connection...")
    print(f"   IP: {ESP32_IP}")
    print(f"   Stream URL: {ESP32_STREAM_URL}")
    print()
    
    # Test basic HTTP connection
    try:
        response = requests.get(f"http://{ESP32_IP}/", timeout=5)
        print(f"✅ Basic HTTP connection successful (status: {response.status_code})")
    except requests.exceptions.RequestException as e:
        print(f"❌ Basic HTTP connection failed: {e}")
        return False
    
    # Test MJPEG stream
    try:
        session = requests.Session()
        response = session.get(ESP32_STREAM_URL, stream=True, timeout=10)
        response.raise_for_status()
        
        print("✅ MJPEG stream connection successful")
        print("📺 Displaying 5 frames to test...")
        
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
                    img_array = np.frombuffer(jpg, dtype=np.uint8)
                    frame = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
                    
                    if frame is not None:
                        frame_count += 1
                        print(f"   Frame {frame_count}: {frame.shape}")
                        
                        if frame_count <= 5:
                            cv2.imshow(f"ESP32 Test Frame {frame_count}", frame)
                            cv2.waitKey(1000)  # Show each frame for 1 second
                            cv2.destroyWindow(f"ESP32 Test Frame {frame_count}")
                        
                        if frame_count >= 5:
                            print("✅ Successfully received and decoded frames")
                            return True
                            
                except Exception as e:
                    print(f"❌ Error decoding frame {frame_count}: {e}")
                    continue
                    
    except requests.exceptions.RequestException as e:
        print(f"❌ MJPEG stream connection failed: {e}")
        return False
    
    print("⚠️  No frames received within timeout period")
    return False

if __name__ == "__main__":
    success = test_esp32_connection()
    
    if success:
        print("\n🎉 ESP32 camera is ready for face recognition!")
        print("   Run: python esp32_face_recognition.py")
    else:
        print("\n❌ ESP32 camera connection failed")
        print("   Please check:")
        print("   - ESP32 is powered on and connected to WiFi")
        print(f"   - ESP32 IP address is {ESP32_IP}")
        print("   - Camera streaming server is running on port 81")
        print("   - No firewall blocking the connection")
    
    cv2.destroyAllWindows()
