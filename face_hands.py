import face_recognition
import cv2
import os
import sys
import mediapipe as mp
import requests


def sync_known_faces_from_api(known_dir: str) -> None:
   
    base = os.getenv("API_BASE_URL", "").rstrip("/")
    if not base:
        return

    headers = {}

    os.makedirs(known_dir, exist_ok=True)

    r = requests.get(f"{base}/api/images", headers=headers, timeout=20)
    r.raise_for_status()
    data = r.json()
    files = data.get("files", [])

    for f in files:
        image_id = f.get("id")
        url = f.get("url")
        person = f.get("person") or "Unknown"
        if not image_id or not url:
            continue

        person_dir = os.path.join(known_dir, person)
        os.makedirs(person_dir, exist_ok=True)

        local_path = os.path.join(person_dir, image_id)
        if os.path.exists(local_path):
            continue

        img_res = requests.get(f"{base}{url}", headers=headers, timeout=30)
        img_res.raise_for_status()
        with open(local_path, "wb") as out:
            out.write(img_res.content)


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
    print("❌ dossier known_face introuvable")
    sys.exit()

try:
    sync_known_faces_from_api(KNOWN_DIR)
except Exception as e:
    print(f"⚠️ Sync API échouée: {e}")

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
# CAMERA
# =============================
cap = cv2.VideoCapture(0)

while True:
    ret, frame = cap.read()
    if not ret:
        break

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

    cv2.imshow("Face + Hand System - Aziz & Molka", frame)

    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()
