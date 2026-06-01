# QR Scanner Flow

Park Here Scanner is a standalone Android fallback for gate verification. ESP32 QR hardware remains the primary flow, with `server/parking_server.py` acting as the Firebase verification bridge for the ESP32.

## ESP32 + Python Bridge

The ESP32 never talks to Firebase directly. It calls:

```text
GET /scan?id=<qrId>&locationId=<parkingAreaId>
```

The ESP32 forwards that request to the Python server:

```text
GET /verify?id=<qrId>&locationId=<parkingAreaId>
```

The Python server returns plain text only:

- `BEFORE_TIME`: QR was scanned earlier than 5 minutes before `bookingStartAt`.
- `ENTRY`: entry accepted and booking moved to `active_parking`.
- `USED`: entry QR already scanned or parking already completed.
- `EXIT`: exit accepted when `mode=exit`.
- `INVALID`: QR, booking, location, or state is invalid.
- `EXPIRED`: QR/booking is outside its validity window.
- `ERROR`: server/Firebase failure.

ESP32 beep behavior:

- `ENTRY`: one short beep.
- `EXIT`: two short beeps.
- `BEFORE_TIME`: one long beep.
- `INVALID`, `USED`, `EXPIRED`, `ERROR`: long error beep.

Exit is explicit: the gate must call `mode=exit`. This keeps a normal second entry scan from completing a booking accidentally.

## Runtime Flow

1. Initialize Firebase.
2. Load Firebase regions, parking areas, and gate points.
3. Staff selects the scanner's simulated region, parking area, and gate.
4. Open the camera scanner.
5. Read the QR payload.
6. Accept only opaque `qr_live_...` ids.
7. Fetch `/active_qr_tickets/{qrId}`.
8. Verify the ticket exists, is `active`, and `expiresAt` is in the future.
9. Fetch `/bookings/{bookingId}`. Active tickets must not be rejected as booking-missing until this read completes.
10. Reject the scan if the booking area does not match the selected scanner area.
11. Accept only `active` or `confirmed` bookings.
12. Show the parking area, vehicle number, validity, and status.
13. On Confirm Entry, consume the QR in a transaction.

## Canonical States

`active_qr_tickets.status` values:

- `active`
- `used`
- `expired`
- `cancelled`

`bookings.status` values:

- `pending`
- `confirmed`
- `active`
- `active_parking`
- `completed`
- `cancelled`
- `expired`

## Rejection States

- `Invalid QR`: payload is not an opaque Park Here QR id.
- `Already Used`: ticket status is `used`.
- `Parking Active`: the booking has already had entry verified.
- `Expired Ticket`: ticket is expired or no longer active.
- `Cancelled Ticket`: ticket status is `cancelled`.
- `Booking Not Found`: linked booking is missing.
- `Booking Not Active`: linked booking is cancelled, completed, pending, or expired.
- `Wrong Location`: scanned QR belongs to a different parking area than the selected scanner location.
- `Network Error`: Firebase read/write failed.

## Double Scan Prevention

The UI ignores additional camera detections while verification is running. The Confirm Entry action also uses a Firestore transaction, so two devices cannot safely consume the same QR at the same time.

Inside the transaction the scanner re-reads `/active_qr_tickets/{qrId}` and `/bookings/{bookingId}`. A successful entry scan writes:

- `/active_qr_tickets/{qrId}.status = used`
- `/active_qr_tickets/{qrId}.scannedOnce = true`
- `/active_qr_tickets/{qrId}.scanPhase = entered`
- `/active_qr_tickets/{qrId}.usedAt = server scan time`
- `/bookings/{bookingId}.status = active_parking`
- `/bookings/{bookingId}.entryVerified = true`
- `/bookings/{bookingId}.entryScannedAt = server scan time`
- `/bookings/{bookingId}.entryVerifiedAt = server scan time`
- `/bookings/{bookingId}.entryGateId = selected gate id`
- `/bookings/{bookingId}.entryScannerMode = android_fallback`
- `/bookings/{bookingId}.qrUsedAt = server scan time`
- `/qr_scan_logs/{scanId}.areaId = selected area id`
- `/qr_scan_logs/{scanId}.gateId = selected gate id`

The used QR is never made active again. The user must complete the current parking cycle or create a new booking to receive a fresh QR id.

## Privacy

The scanner never trusts QR contents beyond `qrId`. It does not parse JSON QR payloads. User, admin, booking, vehicle, and parking data are resolved from Firebase only after the QR id is validated.

## Debug Logging

Debug logs include the raw scanned payload, normalized `qrId`, Firestore lookup start, booking lookup result, parking-area lookup result, and transaction outcome. These logs are for device debugging and should not be shown directly in gate-staff UI.
