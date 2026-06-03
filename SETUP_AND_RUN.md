# Park Here Addon Setup And Run Guide

This package is a testing build for the Park Here Streamlit + ESP32 + Firebase QR bridge. It is not a Flutter app.

## Prerequisites

- Python 3.10 or newer.
- A Firebase project used by the Park Here user/admin apps.
- Firebase Admin SDK service account JSON for that Firebase project.
- ESP32 board support installed in Arduino IDE or Arduino CLI.
- ESP32 libraries:
  - `WiFi`
  - `WebServer`
  - `HTTPClient`
  - `Preferences`
- Laptop connected to the ESP32 `SIT-SmartGate` access point when configuring the gate.

## Firebase Setup

1. Open Firebase Console for the Park Here project.
2. Go to Project settings -> Service accounts.
3. Generate a new private key for local testing.
4. Save the file locally as:

```text
server/serviceAccountKey.json
```

Do not commit or share this file.

5. Create `server/.env` from `server/.env.example`:

```powershell
cd server
copy .env.example .env
```

6. Configure:

```text
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
FIREBASE_PROJECT_ID=park-here-dev
PORT=5000
```

Use your real Firebase project id if it differs from `park-here-dev`.

## Install Python Dependencies

```powershell
cd server
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

On macOS/Linux:

```bash
cd server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run Streamlit

```powershell
cd server
streamlit run streamlit_qr_control.py
```

Streamlit is the easiest way to test without physical QR hardware.

Use it to:

- connect to Firebase
- select a parking location from `parking_areas`
- scan a QR through the browser camera, or enter a `qrId` manually
- simulate a scan
- view safe ticket/booking debug details
- view latest scan logs
- configure a reachable ESP32 gate

Scan flow:

```text
selected location -> qrId -> Firebase transaction
```

The Python endpoint uses `active_qr_tickets.status` to decide whether the scan is entry or exit, so no camera type selector is needed.

## Run Flask Server

```powershell
cd server
python parking_server.py
```

The ESP32 calls:

```text
GET /verify?id=<qrId>&locationId=<areaId>
```

Example:

```text
http://192.168.4.2:5000/verify?id=qr_live_example123&locationId=area_sit_main_lot
```

Returned plain-text commands:

```text
ENTRY
EXIT
BEFORE_TIME
USED
EXPIRED
INVALID
ERROR
```

## ESP32 Setup

1. Open `hardware/esp32_parking_gate/park_here_gate.ino` in Arduino IDE.
2. Select your ESP32 board and port.
3. Upload the firmware.
4. Open Serial Monitor at `115200`.
5. On boot, the ESP32 starts its gate access point:

```text
SSID: SIT-SmartGate
Password: parkhere123
Device IP: http://192.168.4.1
```

6. Connect a phone/laptop to `SIT-SmartGate`.
7. Start Streamlit and open the **ESP32 Gate Configuration** tab.
8. Configure:

- ESP32 IP address: `192.168.4.1`
- Python server IP: `192.168.4.2` by default
- parking area `locationId`

9. Click **Update ESP32 Config**.

The ESP32 stores `serverUrl` and `locationId` in Preferences/NVS. Defaults are:

```text
serverUrl: http://192.168.4.2:5000
locationId: loc_1779943110578
```

When scanning:

```text
GET /scan?id=<qrId>
```

The ESP32 forwards to:

```text
GET http://<python-server>:5000/verify?id=<qrId>&locationId=<saved-locationId>
```

## Testing Flow

1. Create a booking in the Park Here user app.
2. Confirm Firestore has:
   - `/bookings/{bookingId}`
   - `/active_qr_tickets/{qrId}`
3. Open Streamlit:

```powershell
cd server
streamlit run streamlit_qr_control.py
```

4. Select the matching parking location.
5. Scan the QR through the browser camera or paste/type the booking `qrId`.
6. Click `Simulate Scan`.
7. Verify the Firebase-backed result.
9. Check Firebase:
   - `active_qr_tickets/{qrId}.status = entry_verified`
   - `active_qr_tickets/{qrId}.entryScannedAt` is set
   - `bookings/{bookingId}.status = active_parking`
   - `bookings/{bookingId}.entryVerified = true`
10. To test the ESP32 endpoint directly, call:

```text
http://192.168.4.1/scan?id=<qrId>
```

## Troubleshooting

### Firebase connection issues

- Confirm `server/.env` exists.
- Confirm `FIREBASE_SERVICE_ACCOUNT_PATH` points to `serviceAccountKey.json`.
- Confirm the service account belongs to the same Firebase project as Park Here.
- Confirm `FIREBASE_PROJECT_ID` is correct.

### WiFi issues

- Connect to `SIT-SmartGate` and use Streamlit to check `http://192.168.4.1/status`.
- Use `/reset_config` to clear saved server/location config.

### Wrong location

Result: `INVALID`

Cause: QR ticket or booking `areaId` does not match selected `locationId`.

Fix: select/configure the correct parking area.

### Invalid QR

Result: `INVALID`

Cause: QR is empty, malformed, missing in Firebase, or has no linked booking.

Fix: use the opaque `qrId` from an active booking.

### BEFORE_TIME

Result: `BEFORE_TIME`

Cause: The QR was scanned before the active verification window, or backend phase logic rejected the current phase.

Fix: confirm booking time/status and retry in the allowed window.

### USED

Result: `USED`

Cause: The entry/exit phase has already been completed or the ticket is closed.

Fix: create a new booking for a new QR lifecycle.

### EXPIRED

Result: `EXPIRED`

Cause: The ticket or linked booking is marked expired.

Fix: create a new booking or inspect the booking status in Firebase.

## Notes

- QR payload must contain only `qrId`.
- Do not put user, admin, vehicle, or booking JSON into the QR.
- Firebase is the source of truth.
- ESP32 only plays beep patterns; no servo or gate motor is controlled yet.
