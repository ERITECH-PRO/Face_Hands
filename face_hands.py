import face_recognition
import cv2
import os
import sys
import mediapipe as mp

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
