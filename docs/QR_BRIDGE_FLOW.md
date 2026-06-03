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
- `/bookings/{bookingId}` is permanent history; `/active_qr_tickets/{qrId}` is live-only and is deleted after exit, expiry, or cancellation.

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
| `ENTRY` | Entry accepted and booking moved to `active_parking` |
| `EXIT` | Exit accepted and booking moved to `completed` |
| `EXPIRED` | Ticket or booking is expired or already completed |
| `INVALID` | QR, booking, status, or location does not pass validation |
| `ERROR` | Server-side error; check Python logs |

## Entry Flow

1. Streamlit selects a parking area from Firebase `parking_areas`, or ESP32 uses its saved `locationId`.
2. Streamlit scans a QR through the browser camera or accepts a manually entered `qrId`.
3. ESP32 or Streamlit submits `qrId` and `locationId`.
4. Python reads `/active_qr_tickets/{qrId}`.
5. Python reads linked `/bookings/{bookingId}`.
6. Python verifies location, ticket status, and booking status.
7. If ticket `areaId` or booking `areaId` does not match scanner `locationId`, Python returns `INVALID`.
8. If `active_qr_tickets.status = active`, Python transaction updates:
   - `active_qr_tickets.status = entry_verified`
   - `active_qr_tickets.entryScannedAt = server timestamp`
   - `bookings.status = active_parking`
   - `bookings.entryVerified = true`
   - `bookings.entryScannedAt = server timestamp`
9. Python returns `ENTRY`.

The same opaque `qrId` remains tied to the booking after entry. The single lifecycle key changes from `active` to `entry_verified`, which lets the next scan act as exit.

## Exit Flow

The default Flask/ESP path infers entry or exit from `active_qr_tickets.status`.

Python returns `EXIT` only when:

- ticket status is `entry_verified`
- booking status is `active_parking`
- the scan location matches the ticket/booking area

Exit updates:

- `bookings.status = completed`
- `bookings.exitScannedAt = server timestamp`
- `bookings.completedAt = server timestamp`
- delete `/active_qr_tickets/{qrId}`
- `parking_areas.availableSpaces` increments by one

After exit completion, repeat scans return `EXPIRED` when booking history can be found by `qrId`; otherwise they return `INVALID`. Expiry/cancellation also removes the live QR doc.

## ESP32 Beep Mapping

| Python result | Buzzer |
| --- | --- |
| `ENTRY` | one short beep |
| `EXIT` | two short beeps |
| `EXPIRED`, `INVALID`, `ERROR` | long error beep |

## ESP32 Configuration From Streamlit

Streamlit can configure an ESP32 already connected to the same network:

```text
GET http://<esp32-ip>/status
GET http://<esp32-ip>/update_config?serverIp=<python-ip>&locationId=<areaId>
GET http://<esp32-ip>/reset_config
```

The ESP32 runs as:

```text
SSID: SIT-SmartGate
Password: parkhere123
IP: 192.168.4.1
Default Python server: http://192.168.4.2:5000
Default locationId: loc_1779943110578
```

The ESP32 saves `serverUrl` and `locationId` to Preferences/NVS. Future calls to:

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
