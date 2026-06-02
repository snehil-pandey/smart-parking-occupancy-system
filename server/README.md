# Park Here QR Bridge Server

This folder contains the Python side of the Park Here QR gate bridge.

- `firebase_service.py` contains the shared Firebase Admin SDK and Firestore transaction logic.
- `parking_server.py` exposes a plain-text Flask endpoint for ESP32.
- `streamlit_qr_control.py` provides a small browser UI that simulates QR scans when physical QR hardware is unavailable.

## Install

```powershell
cd server
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
```

Place your Firebase Admin SDK JSON at:

```text
server/serviceAccountKey.json
```

Never commit real service account files or `.env`.

## Environment

```text
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
FIREBASE_PROJECT_ID=park-here-dev
PORT=5000
```

## Run Streamlit QR Control

Use this while there is no physical QR camera/reader.

```powershell
cd server
streamlit run streamlit_qr_control.py
```

Features:

- manually enter an opaque `qrId`
- choose a Firebase parking area/location
- simulate entry or exit scans
- call the same `verify_qr_scan` logic used by Flask
- show `ENTRY`, `EXIT`, `BEFORE_TIME`, `USED`, `EXPIRED`, `INVALID`, or `ERROR`
- show a safe ticket/booking summary
- show recent `/qr_scan_logs`

## Run Flask Server For ESP32

```powershell
cd server
python parking_server.py
```

ESP32 calls:

```text
GET /verify?id=<qrId>&locationId=<parkingAreaId>
```

Exit mode is explicit:

```text
GET /verify?id=<qrId>&locationId=<parkingAreaId>&mode=exit
```

Responses are plain text only:

```text
ENTRY
EXIT
BEFORE_TIME
INVALID
USED
EXPIRED
ERROR
```

## Firebase Collections

The server reads/writes:

- `/active_qr_tickets/{qrId}`
- `/bookings/{bookingId}`
- `/parking_areas/{areaId}` for Streamlit location selection
- `/qr_scan_logs/{scanId}`

Firestore transactions prevent double entry scans and race conditions when two devices scan the same QR at the same time.

## QR Rules

- QR payload is only the opaque `qrId`.
- Before `bookingStartAt - 5 minutes`, the result is `BEFORE_TIME`.
- During the valid entry window, the first scan returns `ENTRY`.
- Entry marks the QR `used`, `scannedOnce = true`, and `scanPhase = entered`.
- A repeated entry scan returns `USED`.
- Expired/cancelled tickets return `EXPIRED` or `INVALID`.
- Exit returns `EXIT` only when `mode=exit`, the booking is `active_parking`, and the ticket phase supports exit.
