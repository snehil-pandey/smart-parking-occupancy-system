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
- Streamlit simulates QR scans without physical QR hardware.

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

1. ESP32 or Streamlit submits `qrId` and `locationId`.
2. Python reads `/active_qr_tickets/{qrId}`.
3. Python reads linked `/bookings/{bookingId}`.
4. Python verifies location, status, timing, and scan phase.
5. If too early, Python returns `BEFORE_TIME` and does not change QR state.
6. If valid, Python transaction updates:
   - `active_qr_tickets.status = used`
   - `active_qr_tickets.scannedOnce = true`
   - `active_qr_tickets.scanPhase = entered`
   - `active_qr_tickets.entryScannedAt = server timestamp`
   - `bookings.status = active_parking`
   - `bookings.entryVerified = true`
   - `bookings.entryScannedAt = server timestamp`
7. Python returns `ENTRY`.

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

## Local Development

```powershell
cd server
pip install -r requirements.txt
streamlit run streamlit_qr_control.py
python parking_server.py
```

Use Streamlit first to verify Firebase connectivity and QR lifecycle before flashing/testing ESP32 hardware.
