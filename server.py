import os
import sys
import time
import uuid
from threading import Lock
from typing import Generator, Optional, Tuple

import cv2
import face_recognition
import mediapipe as mp
import numpy as np
from flask import Flask, Response, abort, jsonify, render_template_string, request, send_file
from werkzeug.utils import secure_filename


TOLERANCE = float(os.getenv("TOLERANCE", "0.5"))
MODEL = os.getenv("MODEL", "hog")
STREAM_URL = os.getenv("STREAM_URL", "0")
FRAME_WIDTH = int(os.getenv("FRAME_WIDTH", "1280"))
FRAME_HEIGHT = int(os.getenv("FRAME_HEIGHT", "720"))
JPEG_QUALITY = int(os.getenv("JPEG_QUALITY", "80")) 
DATA_DIR = os.getenv("DATA_DIR", os.path.join(os.path.dirname(os.path.abspath(__file__)), "data"))

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
KNOWN_DIR = os.path.join(BASE_DIR, "known_face")

_last_jpeg_lock = Lock()
_last_jpeg: Optional[bytes] = None
_last_jpeg_ts: float = 0.0


def _load_known_faces(known_dir: str) -> Tuple[list, list]:
    known_encodings = []
    known_names = []

    if not os.path.exists(known_dir):
        return known_encodings, known_names

    for name in os.listdir(known_dir):
        person_path = os.path.join(known_dir, name)
        if not os.path.isdir(person_path):
            continue

        for img_name in os.listdir(person_path):
            img_path = os.path.join(person_path, img_name)
            try:
                image = face_recognition.load_image_file(img_path)
                encodings = face_recognition.face_encodings(image)
                if encodings:
                    known_encodings.append(encodings[0])
                    known_names.append(name)
            except Exception:
                continue

    return known_encodings, known_names


def _open_capture(stream_url: str) -> cv2.VideoCapture:
    if stream_url.strip() == "0":
        cap = cv2.VideoCapture(0)
    else:
        cap = cv2.VideoCapture(stream_url)

    if FRAME_WIDTH > 0:
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, FRAME_WIDTH)
    if FRAME_HEIGHT > 0:
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, FRAME_HEIGHT)

    return cap


def _mjpeg_chunk(jpg_bytes: bytes) -> bytes:
    return b"--frame\r\n" b"Content-Type: image/jpeg\r\n\r\n" + jpg_bytes + b"\r\n"


def _error_jpeg(message: str, size: Tuple[int, int] = (1280, 720)) -> bytes:
    w, h = size
    img = np.zeros((h, w, 3), dtype=np.uint8)
    lines = [
        "VIDEO STREAM ERROR",
        "",
        message,
        "",
        "Sur VPS: definis STREAM_URL (rtsp://... ou http://...).",
    ]
    y = 60
    for line in lines:
        cv2.putText(
            img,
            line[:110],
            (30, y),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.9,
            (0, 0, 255) if line else (255, 255, 255),
            2,
        )
        y += 45
    ok, jpg = cv2.imencode(".jpg", img, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
    return jpg.tobytes() if ok else b""


def _process_frame(
    frame_bgr,
    rgb,
    known_encodings,
    known_names,
    hands,
    mp_draw,
    mp_hands,
    tip_ids,
):
    face_recognized = False

    locations = face_recognition.face_locations(rgb, model=MODEL)
    encodings = face_recognition.face_encodings(rgb, locations)

    for (top, right, bottom, left), face_encoding in zip(locations, encodings):
        matches = face_recognition.compare_faces(known_encodings, face_encoding, TOLERANCE)

        name = "Inconnu"
        color = (0, 0, 255)

        if True in matches:
            index = matches.index(True)
            name = known_names[index]
            color = (0, 255, 0)
            face_recognized = True

        cv2.rectangle(frame_bgr, (left, top), (right, bottom), color, 2)
        cv2.putText(
            frame_bgr,
            name.upper(),
            (left, max(20, top - 10)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.9,
            color,
            2,
        )

    if face_recognized:
        results = hands.process(rgb)

        if results.multi_hand_landmarks and results.multi_handedness:
            for hand_index, hand_lms in enumerate(results.multi_hand_landmarks):
                lm_list = []
                h, w, _ = frame_bgr.shape

                for idx, lm in enumerate(hand_lms.landmark):
                    cx, cy = int(lm.x * w), int(lm.y * h)
                    lm_list.append([idx, cx, cy])

                mp_draw.draw_landmarks(frame_bgr, hand_lms, mp_hands.HAND_CONNECTIONS)

                fingers = []
                hand_label = results.multi_handedness[hand_index].classification[0].label

                # Thumb
                if hand_label == "Right":
                    fingers.append(1 if lm_list[4][1] < lm_list[3][1] else 0)
                else:
                    fingers.append(1 if lm_list[4][1] > lm_list[3][1] else 0)

                # Other fingers
                for i in range(1, 5):
                    fingers.append(1 if lm_list[tip_ids[i]][2] < lm_list[tip_ids[i] - 2][2] else 0)

                total_fingers = fingers.count(1)
                x_text = 20 if hand_label == "Left" else 300
                cv2.putText(
                    frame_bgr,
                    f"{hand_label} hand: {total_fingers}",
                    (x_text, 60),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1.1,
                    (255, 0, 0),
                    3,
                )
    else:
        cv2.putText(
            frame_bgr,
            "Hand Tracking Locked",
            (20, 50),
            cv2.FONT_HERSHEY_SIMPLEX,
            1,
            (0, 0, 255),
            3,
        )

    return frame_bgr


def _ensure_data_dir() -> str:
    os.makedirs(DATA_DIR, exist_ok=True)
    return DATA_DIR


def _allowed_ext(filename: str) -> bool:
    ext = os.path.splitext(filename.lower())[1]
    return ext in {".jpg", ".jpeg", ".png", ".webp"}


def _parse_person_from_id(image_id: str) -> Optional[str]:
    if "__" not in image_id:
        return None
    person, _rest = image_id.split("__", 1)
    person = secure_filename(person)
    return person or None


def _frame_generator() -> Generator[bytes, None, None]:
    known_encodings, known_names = _load_known_faces(KNOWN_DIR)

    mp_hands = mp.solutions.hands
    hands = mp_hands.Hands(
        static_image_mode=False,
        max_num_hands=2,
        min_detection_confidence=0.7,
        min_tracking_confidence=0.7,
    )
    mp_draw = mp.solutions.drawing_utils
    tip_ids = [4, 8, 12, 16, 20]

    cap = _open_capture(STREAM_URL)
    if not cap.isOpened():
        msg = f"Impossible d'ouvrir la source video STREAM_URL={STREAM_URL!r}"
        jpg = _error_jpeg(msg, size=(FRAME_WIDTH, FRAME_HEIGHT))
        while True:
            yield _mjpeg_chunk(jpg)
            time.sleep(1)

    encode_params = [int(cv2.IMWRITE_JPEG_QUALITY), max(0, min(100, JPEG_QUALITY))]

    last_ok = time.time()
    try:
        while True:
            ret, frame = cap.read()
            if not ret or frame is None:
                if time.time() - last_ok > 10:
                    raise RuntimeError("Perte du flux vidéo (10s sans frame).")
                time.sleep(0.05)
                continue

            last_ok = time.time()

            frame = cv2.flip(frame, 1)
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            processed = _process_frame(
                frame,
                rgb,
                known_encodings,
                known_names,
                hands,
                mp_draw,
                mp_hands,
                tip_ids,
            )

            ok, jpg = cv2.imencode(".jpg", processed, encode_params)
            if not ok:
                continue

            jpg_bytes = jpg.tobytes()
            global _last_jpeg, _last_jpeg_ts
            with _last_jpeg_lock:
                _last_jpeg = jpg_bytes
                _last_jpeg_ts = time.time()

            yield _mjpeg_chunk(jpg_bytes)
    except Exception as e:
        msg = f"{type(e).__name__}: {e}"
        jpg = _error_jpeg(msg, size=(FRAME_WIDTH, FRAME_HEIGHT))
        while True:
            yield _mjpeg_chunk(jpg)
            time.sleep(1)
    finally:
        cap.release()


app = Flask(__name__)


@app.get("/")
def index():
    return render_template_string(
        """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8"/>
            <meta name="viewport" content="width=device-width, initial-scale=1"/>
            <title>Face + Hands</title>
            <style>
              body { font-family: Arial, sans-serif; margin: 24px; }
              .hint { color: #666; margin-top: 8px; }
              img { max-width: 100%; height: auto; border: 1px solid #ddd; }
              code { background: #f4f4f4; padding: 2px 6px; border-radius: 4px; }
            </style>
          </head>
          <body>
            <h2>Face + Hands (MJPEG)</h2>
            <img src="/video.mjpeg" alt="video stream"/>
            <div class="hint">Source: <code>{{ stream_url }}</code></div>
            <div class="hint" style="margin-top: 10px;">
              <a href="/upload">Upload images</a>
            </div>
          </body>
        </html>
        """,
        stream_url=STREAM_URL,
    )


@app.get("/upload")
def upload_page():
    return render_template_string(
        """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8"/>
            <meta name="viewport" content="width=device-width, initial-scale=1"/>
            <title>Upload images</title>
            <style>
              body { font-family: Arial, sans-serif; margin: 24px; max-width: 900px; }
              label { display:block; margin-top: 10px; }
              input, button { font-size: 14px; }
              .row { display:flex; gap: 10px; align-items: center; flex-wrap: wrap; }
              .hint { color: #666; margin-top: 8px; }
              .ok { color: #0a7; }
              .err { color: #c00; }
              code { background: #f4f4f4; padding: 2px 6px; border-radius: 4px; }
              img { max-width: 220px; border: 1px solid #ddd; }
              .grid { display:grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 12px; margin-top: 16px; }
              .card { border: 1px solid #eee; padding: 10px; border-radius: 8px; }
              .small { font-size: 12px; color: #666; word-break: break-all; }
            </style>
          </head>
          <body>
            <h2>Uploader une image</h2>
            <div class="hint">
              L’API attend un champ <code>file</code> + (optionnel) <code>person</code>.
            </div>

            <div class="row">
              <label>Personne (ex: Aziz)</label>
              <input id="person" type="text" placeholder="Aziz"/>
            </div>

            <div class="row">
              <label>Fichier</label>
              <input id="file" type="file" accept="image/*"/>
            </div>

            <div class="row">
              <button id="btn" onclick="upload()">Uploader</button>
            </div>

            <div id="status" class="hint"></div>

            <h3 style="margin-top: 24px;">Images stockées</h3>
            <div class="hint">Clique une image pour l’ouvrir via l’API.</div>
            <div id="grid" class="grid"></div>

            <script>
              async function api(path, opts) {
                opts = opts || {};
                opts.headers = opts.headers || {};
                const res = await fetch(path, opts);
                const ct = res.headers.get('content-type') || '';
                let data = null;
                if (ct.includes('application/json')) data = await res.json();
                return { res, data };
              }

              function setStatus(msg, cls) {
                const el = document.getElementById('status');
                el.className = cls || 'hint';
                el.textContent = msg;
              }

              async function refresh() {
                const { res, data } = await api('/api/images');
                const grid = document.getElementById('grid');
                grid.innerHTML = '';
                if (!res.ok) {
                  setStatus('Erreur liste: ' + (data && data.error ? data.error : res.status), 'err');
                  return;
                }
                (data.files || []).reverse().forEach(f => {
                  const card = document.createElement('div');
                  card.className = 'card';
                  const a = document.createElement('a');
                  a.href = f.url;
                  a.target = '_blank';
                  const img = document.createElement('img');
                  img.src = f.url;
                  img.alt = f.id;
                  a.appendChild(img);
                  const p = document.createElement('div');
                  p.className = 'small';
                  p.textContent = (f.person ? ('person=' + f.person + ' | ') : '') + f.id;
                  card.appendChild(a);
                  card.appendChild(p);
                  grid.appendChild(card);
                });
                setStatus('OK: ' + (data.files || []).length + ' image(s).', 'ok');
              }

              async function upload() {
                const file = document.getElementById('file').files[0];
                if (!file) return setStatus('Choisis un fichier.', 'err');
                const person = document.getElementById('person').value.trim();
                const fd = new FormData();
                fd.append('file', file);
                if (person) fd.append('person', person);
                setStatus('Upload en cours...', 'hint');
                const { res, data } = await api('/api/images', { method: 'POST', body: fd });
                if (!res.ok) {
                  return setStatus('Erreur upload: ' + (data && data.error ? data.error : res.status), 'err');
                }
                setStatus('Upload OK: ' + data.id, 'ok');
                document.getElementById('file').value = '';
                await refresh();
              }

              refresh();
            </script>
          </body>
        </html>
        """
    )


@app.get("/video.mjpeg")
def video_mjpeg():
    return Response(_frame_generator(), mimetype="multipart/x-mixed-replace; boundary=frame")


@app.get("/api/health")
def api_health():
    return jsonify(
        ok=True,
        stream_url=STREAM_URL,
    )


@app.get("/api/images")
def api_list_images():
    data_dir = _ensure_data_dir()
    files = []
    for name in sorted(os.listdir(data_dir)):
        path = os.path.join(data_dir, name)
        if os.path.isfile(path):
            person = _parse_person_from_id(name)
            files.append(
                {
                    "id": name,
                    "url": f"/api/images/{name}",
                    "size": os.path.getsize(path),
                    "modified": int(os.path.getmtime(path)),
                    "person": person,
                }
            )
    return jsonify(files=files)


@app.get("/api/images/<image_id>")
def api_get_image(image_id: str):
    image_id = secure_filename(image_id)
    path = os.path.join(_ensure_data_dir(), image_id)
    if not os.path.isfile(path):
        abort(404)
    return send_file(path, conditional=True)


@app.post("/api/images")
def api_upload_image():
    if "file" not in request.files:
        return jsonify(error="missing file field 'file'"), 400
    f = request.files["file"]
    if not f.filename:
        return jsonify(error="empty filename"), 400

    filename = secure_filename(f.filename)
    if not _allowed_ext(filename):
        return jsonify(error="unsupported file type (jpg/jpeg/png/webp)"), 400

    person_raw = (request.form.get("person") or "").strip()
    person = secure_filename(person_raw)[:60]

    ext = os.path.splitext(filename)[1].lower()
    if person:
        image_id = f"{person}__{uuid.uuid4().hex}{ext}"
    else:
        image_id = f"{uuid.uuid4().hex}{ext}"
    path = os.path.join(_ensure_data_dir(), image_id)
    f.save(path)
    return jsonify(id=image_id, url=f"/api/images/{image_id}"), 201


@app.post("/api/snapshot")
def api_snapshot():
    """
    Sauvegarde la dernière frame MJPEG générée (si disponible).
    """
    with _last_jpeg_lock:
        jpg = _last_jpeg
        ts = _last_jpeg_ts

    if not jpg or (time.time() - ts) > 15:
        return jsonify(error="no recent frame available; open /video.mjpeg first"), 409

    image_id = f"snapshot_{int(time.time())}_{uuid.uuid4().hex}.jpg"
    path = os.path.join(_ensure_data_dir(), image_id)
    with open(path, "wb") as out:
        out.write(jpg)
    return jsonify(id=image_id, url=f"/api/images/{image_id}"), 201


def main():
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    debug = os.getenv("DEBUG", "0") == "1"

    try:
        app.run(host=host, port=port, debug=debug, threaded=True)
    except KeyboardInterrupt:
        return 0
    except Exception as e:
        print(f"❌ Erreur serveur: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
