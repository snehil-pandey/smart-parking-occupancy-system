# Park Here Python QR Verification Server

This Flask server is the bridge between ESP32 gate hardware and Park Here Firebase data.

The ESP32 calls:

```text
GET /verify?id=<qrId>&locationId=<parkingAreaId>
```

The response is plain text only:

```text
ENTRY
EXIT
BEFORE_TIME
INVALID
USED
EXPIRED
ERROR
```

## Setup

```powershell
cd server
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
```

Place your Firebase Admin SDK service account JSON at:

```text
server/serviceAccountKey.json
```

Do not commit the service account key.

Then run:

```powershell
python parking_server.py
```

## Environment

```text
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
FIREBASE_PROJECT_ID=park-here-dev
PORT=5000
```

## Timing Rules

- QR unlocks 5 minutes before `bookingStartAt`.
- Before unlock, the server returns `BEFORE_TIME`.
- A valid first entry scan returns `ENTRY`.
- The entry scan atomically marks the QR `used`, sets `scannedOnce = true`, sets `scanPhase = entered`, and updates the booking to `active_parking`.
- A normal second scan of the same QR returns `USED`.
- Exit requires an explicit gate mode: `mode=exit`.
- Exit returns `EXIT` only when the linked booking is already `active_parking` and the ticket phase is `entered` or `exit_pending`.

Example exit call:

```text
GET /verify?id=qr_live_...&locationId=area_123&mode=exit
```

## Firebase Collections

Reads and writes:

- `/active_qr_tickets/{qrId}`
- `/bookings/{bookingId}`
- `/qr_scan_logs/{scanId}`

The server uses Firestore transactions for scan updates, which prevents two devices from confirming entry for the same QR at the same time.
