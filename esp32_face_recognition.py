import face_recognition
import cv2
import os
import sys
import mediapipe as mp
import requests
import numpy as np
from io import BytesIO
import threading
import time

# =============================
# ESP32 CAMERA CONFIGURATION
# =============================
ESP32_IP = "192.168.110.150"
ESP32_STREAM_URL = f"http://{ESP32_IP}:81/stream"

# =============================
# CONFIG FACE RECOGNITION
# =============================
TOLERANCE = 0.5
MODEL = "hog"

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
KNOWN_DIR = os.path.join(BASE_DIR, "known_face")

known_encodings = []
known_names = []

if not os.path.exists(KNOWN_DIR):
    os.makedirs(KNOWN_DIR, exist_ok=True)

# Load known faces from local directory
for name in os.listdir(KNOWN_DIR):
    person_path = os.path.join(KNOWN_DIR, name)

    if not os.path.isdir(person_path):
        continue

    for img_name in os.listdir(person_path):
        img_path = os.path.join(person_path, img_name)
        image = face_recognition.load_image_file(img_path)
        encodings = face_recognition.face_encodings(image)

        if encodings:
            known_encodings.append(encodings[0])
            known_names.append(name)

print("✅ Visages chargés :", set(known_names))

# =============================
# MEDIAPIPE HANDS
# =============================
mpHands = mp.solutions.hands
hands = mpHands.Hands(
    static_image_mode=False,
    max_num_hands=2,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.7
)

mpDraw = mp.solutions.drawing_utils
tipIds = [4, 8, 12, 16, 20]

# =============================
# ESP32 CAMERA STREAM FUNCTIONS
# =============================

def stream_from_esp32():
    """Generator function to stream frames from ESP32 camera"""
    session = requests.Session()
    try:
        response = session.get(ESP32_STREAM_URL, stream=True, timeout=10)
        response.raise_for_status()
        
        bytes_data = b''
        for chunk in response.iter_content(chunk_size=1024):
            bytes_data += chunk
            a = bytes_data.find(b'\xff\xd8')
            b = bytes_data.find(b'\xff\xd9')
            if a != -1 and b != -1:
                jpg = bytes_data[a:b+2]
                bytes_data = bytes_data[b+2:]
                
                # Decode JPEG to numpy array
                try:
                    img_array = np.frombuffer(jpg, dtype=np.uint8)
                    frame = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
                    if frame is not None:
                        yield frame
                except Exception as e:
                    print(f"Error decoding frame: {e}")
                    continue
                    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error connecting to ESP32 camera: {e}")
        print(f"   Make sure ESP32 is running at {ESP32_STREAM_URL}")
        return None

def test_esp32_connection():
    """Test if ESP32 camera is accessible"""
    try:
        response = requests.get(f"http://{ESP32_IP}/", timeout=5)
        if response.status_code == 200:
            print(f"✅ ESP32 camera found at {ESP32_IP}")
            return True
    except:
        pass
    
    try:
        response = requests.get(ESP32_STREAM_URL, timeout=5, stream=True)
        if response.status_code == 200:
            print(f"✅ ESP32 camera stream accessible at {ESP32_STREAM_URL}")
            return True
    except:
        pass
    
    print(f"❌ Cannot connect to ESP32 camera at {ESP32_STREAM_URL}")
    print("   Make sure:")
    print(f"   - ESP32 is powered on and connected to WiFi")
    print(f"   - ESP32 IP address is {ESP32_IP}")
    print(f"   - Camera streaming server is running")
    return False

# =============================
# MAIN FACE RECOGNITION LOOP
# =============================
def main():
    print("🎥 ESP32 OV2640 Face Recognition System")
    print(f"   Camera URL: {ESP32_STREAM_URL}")
    print()
    
    # Test connection first
    if not test_esp32_connection():
        print("\n⚠️  Cannot proceed without camera connection")
        return
    
    print("\n🔄 Starting face recognition...")
    print("   Press 'q' to quit, 's' to save snapshot")
    
    frame_count = 0
    start_time = time.time()
    
    try:
        for frame in stream_from_esp32():
            if frame is None:
                continue
                
            frame_count += 1
            
            # Calculate FPS
            if frame_count % 30 == 0:
                elapsed = time.time() - start_time
                fps = frame_count / elapsed
                print(f"📊 FPS: {fps:.1f}")
            
            # Flip frame horizontally for mirror effect
            frame = cv2.flip(frame, 1)
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            # =============================
            # FACE RECOGNITION
            # =============================
            face_recognized = False

            locations = face_recognition.face_locations(rgb, model=MODEL)
            encodings = face_recognition.face_encodings(rgb, locations)

            for (top, right, bottom, left), face_encoding in zip(locations, encodings):

                matches = face_recognition.compare_faces(
                    known_encodings, face_encoding, TOLERANCE
                )

                name = "Inconnu"
                color = (0, 0, 255)

                if True in matches:
                    index = matches.index(True)
                    name = known_names[index]
                    color = (0, 255, 0)
                    face_recognized = True

                cv2.rectangle(frame, (left, top), (right, bottom), color, 2)
                cv2.putText(frame,
                            name.upper(),
                            (left, top - 10),
                            cv2.FONT_HERSHEY_SIMPLEX,
                            0.9,
                            color,
                            2)

            # =============================
            # HAND TRACKING (only if face recognized)
            # =============================
            if face_recognized:

                results = hands.process(rgb)

                if results.multi_hand_landmarks and results.multi_handedness:
                    for handIndex, handLms in enumerate(results.multi_hand_landmarks):

                        lmList = []
                        h, w, c = frame.shape

                        for id, lm in enumerate(handLms.landmark):
                            cx, cy = int(lm.x * w), int(lm.y * h)
                            lmList.append([id, cx, cy])

                        mpDraw.draw_landmarks(
                            frame,
                            handLms,
                            mpHands.HAND_CONNECTIONS
                        )

                        fingers = []

                        handLabel = results.multi_handedness[handIndex].classification[0].label

                        # Thumb
                        if handLabel == "Right":
                            fingers.append(1 if lmList[4][1] < lmList[3][1] else 0)
                        else:
                            fingers.append(1 if lmList[4][1] > lmList[3][1] else 0)

                        # Other fingers
                        for i in range(1, 5):
                            fingers.append(
                                1 if lmList[tipIds[i]][2] < lmList[tipIds[i] - 2][2] else 0
                            )

                        totalFingers = fingers.count(1)

                        xText = 20 if handLabel == "Left" else 300

                        cv2.putText(
                            frame,
                            f'{handLabel} hand: {totalFingers}',
                            (xText, 60),
                            cv2.FONT_HERSHEY_SIMPLEX,
                            1.1,
                            (255, 0, 0),
                            3
                        )
            else:
                cv2.putText(
                    frame,
                    "Hand Tracking Locked",
                    (20, 50),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1,
                    (0, 0, 255),
                    3
                )

            # Add status info
            cv2.putText(frame, f"ESP32: {ESP32_IP}", (10, frame.shape[0] - 40), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)
            cv2.putText(frame, f"Faces: {len(locations)}", (10, frame.shape[0] - 20), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)

            cv2.imshow("ESP32 Face + Hand Recognition", frame)

            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break
            elif key == ord('s'):
                # Save snapshot
                timestamp = int(time.time())
                filename = f"snapshot_{timestamp}.jpg"
                cv2.imwrite(filename, frame)
                print(f"📸 Snapshot saved: {filename}")

    except KeyboardInterrupt:
        print("\n👋 Stopping...")
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        cv2.destroyAllWindows()
        hands.close()

if __name__ == "__main__":
    main()
