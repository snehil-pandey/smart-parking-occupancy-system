# Park Here QR Bridge Addon

This `addon` branch is a lightweight Python + ESP32 bridge for Park Here QR gate verification.

It is no longer a Flutter scanner app. The Android fallback scanner was removed from this branch so the addon can stay focused on:

- a Flask verification endpoint for ESP32 devices
- a Streamlit QR scan simulator for development/testing
- shared Firebase Admin SDK transaction logic
- ESP32 AP mode, NVS/Preferences config, and buzzer-based gate feedback
- ESP32 server/location configuration from Streamlit

The main Park Here user/admin Flutter apps live on the main project branches. This addon stays separate and should not be merged into `main` unless the project explicitly decides to ship hardware tooling with the app repository.

## Structure

```text
server/
  firebase_service.py
  parking_server.py
  streamlit_qr_control.py
  requirements.txt
  .env.example
  README.md

hardware/
  esp32_parking_gate/
    park_here_gate.ino
    README.md

docs/
  QR_BRIDGE_FLOW.md
```

## What It Does

1. User books parking in the Park Here user app.
2. The user app creates `/bookings/{bookingId}` and `/active_qr_tickets/{qrId}` in Firebase.
3. ESP32 or Streamlit submits only the opaque `qrId` and selected parking area `locationId`.
4. Python verifies the QR through Firestore in a transaction.
5. Python returns a plain command:

```text
ENTRY
EXIT
EXPIRED
INVALID
ERROR
```

Firebase remains the source of truth. QR payloads must not contain booking JSON, user details, admin details, or vehicle details.

## Run Streamlit Simulator

```powershell
cd server
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
streamlit run streamlit_qr_control.py
```

Use Streamlit when you do not have a physical QR reader yet. It lets you scan a QR using the browser camera or paste a `qrId`, choose a Firebase parking area, and simulate the same Firebase verification path used by the ESP32 bridge.

Streamlit also includes an **ESP32 Gate Configuration** section. Connect the laptop to `SIT-SmartGate`, enter the ESP32 IP address, Python server IP, and parking area `locationId`, then use:

- **Update ESP32 Config** to GET `/update_config`
- **Check ESP32 Status** to GET `/status`
- **Reset ESP32 Config** to GET `/reset_config`

## Run Flask Server For ESP32

```powershell
cd server
pip install -r requirements.txt
python parking_server.py
```

The ESP32 calls:

```text
GET http://<python-server>:5000/verify?id=<qrId>&locationId=<areaId>
```

The Python verifier rejects scans when the QR ticket or linked booking belongs to a different `areaId` than the scanner `locationId`.

The Flask endpoint uses the ticket status to decide whether a scan is entry or exit; no camera type is required.

## Firebase Setup

Create a local `.env` in `server/`:

```text
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
FIREBASE_PROJECT_ID=park-here-dev
PORT=5000
```

Place the Firebase Admin SDK service account JSON at `server/serviceAccountKey.json`.

Do not commit `.env` or service account keys.

## ESP32

The ESP32 sketch does not require hardcoded WiFi or server values. On boot it starts:

```text
SSID: SIT-SmartGate
Password: parkhere123
Device IP: http://192.168.4.1
Default Python server: http://192.168.4.2:5000
Default locationId: loc_1779943110578
```

Configure Python server IP and parking area `locationId` from Streamlit or the ESP32 HTTP endpoints. Values are saved permanently in ESP32 Preferences/NVS.

See [hardware/esp32_parking_gate/README.md](hardware/esp32_parking_gate/README.md).
