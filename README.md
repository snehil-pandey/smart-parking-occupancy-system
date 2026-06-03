# Park Here QR Bridge Addon

This `addon` branch is a lightweight Python + ESP32 bridge for Park Here QR gate verification.

It is no longer a Flutter scanner app. The Android fallback scanner was removed from this branch so the addon can stay focused on:

- a Flask verification endpoint for ESP32 devices
- a Streamlit QR scan simulator for development/testing
- shared Firebase Admin SDK transaction logic
- ESP32 WiFi provisioning and buzzer-based gate feedback
- ESP32 WiFi/server/location configuration from Streamlit

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
3. ESP32 or Streamlit submits only the opaque `qrId`, selected parking area `locationId`, and configured `cameraType`.
4. Python verifies the QR through Firestore in a transaction.
5. Python returns a plain command:

```text
ENTRY
EXIT
BEFORE_TIME
USED
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

Use Streamlit when you do not have a physical QR reader yet. It lets you paste a `qrId`, choose a parking area, choose Entry Camera or Exit Camera, and simulate the same key/value Firebase updates used by the ESP32 bridge.

Streamlit also includes an **ESP32 Configuration** section. Enter the ESP32 IP address, WiFi SSID/password, Python server IP, parking area `locationId`, and camera type, then use:

- **Update ESP32 Config** to POST `/config`
- **Check ESP32 Status** to GET `/status`
- **Reset ESP32 Config** to POST `/reset-config`

## Run Flask Server For ESP32

```powershell
cd server
pip install -r requirements.txt
python parking_server.py
```

The ESP32 calls:

```text
GET http://<python-server>:5000/verify?id=<qrId>&locationId=<areaId>&cameraType=<entry_or_exit>
```

The Python verifier rejects scans when the QR ticket or linked booking belongs to a different `areaId` than the scanner `locationId`.

Entry cameras only process `scanPhase = entry_pending` and update it to `entered`. Exit cameras only process `scanPhase = entered` or `exit_pending` and close the ticket as `used`.

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

The ESP32 sketch does not require hardcoded WiFi credentials. On first boot it starts:

```text
SSID: ParkHere-Gate-Setup
Password: parkhere123
Setup page: http://192.168.4.1
```

Configure WiFi, Python server IP, parking area `locationId`, and camera type from the setup page.

See [hardware/esp32_parking_gate/README.md](hardware/esp32_parking_gate/README.md).
