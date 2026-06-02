# Park Here QR Bridge Flow

The addon branch provides a Python + ESP32 bridge for QR gate verification. It is separate from the Park Here user/admin Flutter apps.

## Components

```text
User app -> Firebase -> Python bridge -> ESP32 buzzer
                         ^
                         |
                     Streamlit simulator
```

- User app creates bookings and active QR ticket documents.
- Python reads Firebase through Admin SDK and updates scan state transactionally.
- ESP32 sends QR ids to Python and plays beep feedback.
- Streamlit simulates QR scans without physical QR hardware and can configure ESP32 gates.

## QR Privacy

The QR code contains only:

```text
qrId
```

It must not contain JSON, user ids, admin ids, vehicle data, booking details, or timestamps. Firebase resolves all truth from:

```text
/active_qr_tickets/{qrId}
/bookings/{bookingId}
/parking_areas/{areaId}
```

## Verification Results

| Result | Meaning |
| --- | --- |
| `BEFORE_TIME` | QR is valid but scanned earlier than `bookingStartAt - 5 minutes` |
| `ENTRY` | Entry accepted and booking moved to `active_parking` |
| `USED` | Entry QR has already been consumed or scan phase is no longer pending |
| `EXIT` | Exit accepted and booking moved to `completed` |
| `EXPIRED` | Ticket or booking is expired |
| `INVALID` | QR, booking, status, or location does not pass validation |
| `ERROR` | Server-side error; check Python logs |

## Entry Flow

1. Streamlit selects a parking area from Firebase `parking_areas`, or ESP32 uses its saved `locationId`.
2. ESP32 or Streamlit submits `qrId` and `locationId`.
3. Python reads `/active_qr_tickets/{qrId}`.
4. Python reads linked `/bookings/{bookingId}`.
5. Python verifies location, status, timing, and scan phase.
6. If ticket `areaId` or booking `areaId` does not match scanner `locationId`, Python returns `INVALID`.
7. If too early, Python returns `BEFORE_TIME` and does not change QR state.
8. If valid, Python transaction updates:
   - `active_qr_tickets.status = used`
   - `active_qr_tickets.scannedOnce = true`
   - `active_qr_tickets.scanPhase = entered`
   - `active_qr_tickets.entryScannedAt = server timestamp`
   - `bookings.status = active_parking`
   - `bookings.entryVerified = true`
   - `bookings.entryScannedAt = server timestamp`
9. Python returns `ENTRY`.

The transaction prevents two devices from confirming entry with the same QR.

## Exit Flow

Exit mode is explicit:

```text
GET /verify?id=<qrId>&locationId=<areaId>&mode=exit
```

Python returns `EXIT` only when:

- booking status is `active_parking`
- ticket `scanPhase` is `entered` or `exit_pending`
- the scan location matches the ticket/booking area

Exit updates:

- `bookings.status = completed`
- `bookings.exitScannedAt = server timestamp`
- `active_qr_tickets.scanPhase = exited`
- `active_qr_tickets.exitScannedAt = server timestamp`

## ESP32 Beep Mapping

| Python result | Buzzer |
| --- | --- |
| `ENTRY` | one short beep |
| `EXIT` | two short beeps |
| `BEFORE_TIME` | one long beep |
| `USED`, `EXPIRED`, `INVALID`, `ERROR` | long error beep |

## ESP32 Configuration From Streamlit

Streamlit can configure an ESP32 already connected to the same network:

```text
GET  http://<esp32-ip>/status
POST http://<esp32-ip>/config
POST http://<esp32-ip>/reset-config
```

`POST /config` body:

```json
{
  "ssid": "Campus WiFi",
  "password": "wifi-password",
  "serverIp": "192.168.1.10",
  "locationId": "area_sit_main_lot"
}
```

The ESP32 saves the values to Preferences/NVS. Future calls to:

```text
GET /scan?id=<qrId>
```

are forwarded as:

```text
GET http://<python-server-ip>:5000/verify?id=<qrId>&locationId=<saved-locationId>
```

## Local Development

```powershell
cd server
pip install -r requirements.txt
streamlit run streamlit_qr_control.py
python parking_server.py
```

Use Streamlit first to verify Firebase connectivity and QR lifecycle before flashing/testing ESP32 hardware.
