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
- scan a QR image through the browser camera
- choose a Firebase parking area/location as the scanner context
- simulate the same Firebase key/value update path used by ESP32
- call the same `verify_qr_scan` logic used by Flask
- reject scans where the QR ticket or booking belongs to another parking area
- show `ENTRY`, `EXIT`, `EXPIRED`, `INVALID`, or `ERROR`
- show a safe ticket/booking summary
- show recent `/qr_scan_logs`
- configure ESP32 Python server IP and saved location over HTTP

The Streamlit **Select Scanner Location** section loads `parking_areas` from Firebase. The selected `areaId` is used as `locationId` for scan simulation, matching a physical gate installed at that parking area.

The **ESP32 Configuration** section calls:

```text
GET  http://<esp32-ip>/status
GET  http://<esp32-ip>/update_config?serverIp=<python-ip>&locationId=<areaId>
GET  http://<esp32-ip>/reset_config
```

The ESP32 currently runs AP mode as:

```text
SSID: SIT-SmartGate
Password: parkhere123
Default ESP IP: 192.168.4.1
Default Python IP: 192.168.4.2
Default locationId: loc_1779943110578
```

The laptop must be connected to `SIT-SmartGate` for Streamlit to reach the ESP32 config endpoints.

## Run Flask Server For ESP32

```powershell
cd server
python parking_server.py
```

ESP32 calls:

```text
GET /verify?id=<qrId>&locationId=<parkingAreaId>
```

Responses are plain text only:

```text
ENTRY
EXIT
INVALID
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
`/bookings/{bookingId}` is permanent history. `/active_qr_tickets/{qrId}` is temporary/live only.

## QR Rules

- QR payload is only the opaque `qrId`.
- Scanner `locationId` must match both the active QR ticket area and the linked booking area when those fields are present.
- `active_qr_tickets.status = active` means the next valid scan is entry.
- Entry changes ticket status to `entry_verified` and booking status to `active_parking`.
- `active_qr_tickets.status = entry_verified` means the next valid scan is exit.
- Exit is allowed whenever the ticket status remains `entry_verified`.
- Exit marks the booking `completed`, deletes `/active_qr_tickets/{qrId}`, and increments `parking_areas.availableSpaces`.
- Repeat scans after exit return `EXPIRED`.
- Expired/cancelled bookings remove the live QR doc and return `EXPIRED` or `INVALID`.
