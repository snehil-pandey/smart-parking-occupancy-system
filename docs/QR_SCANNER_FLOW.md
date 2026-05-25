# QR Scanner Flow

Park Here Scanner is a standalone Android fallback for gate verification. ESP32 QR hardware remains the primary flow.

## Runtime Flow

1. Initialize Firebase.
2. Open the camera scanner.
3. Read the QR payload.
4. Accept only opaque `qr_live_...` ids.
5. Fetch `/active_qr_tickets/{qrId}`.
6. Verify the ticket exists, is `active`, and `expiresAt` is in the future.
7. Fetch `/bookings/{bookingId}`. Active tickets must not be rejected as booking-missing until this read completes.
8. Accept only `active` or `confirmed` bookings.
9. Show the parking area, vehicle number, validity, and status.
10. On Confirm Entry, consume the QR in a transaction.

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
- `Network Error`: Firebase read/write failed.

## Double Scan Prevention

The UI ignores additional camera detections while verification is running. The Confirm Entry action also uses a Firestore transaction, so two devices cannot safely consume the same QR at the same time.

Inside the transaction the scanner re-reads `/active_qr_tickets/{qrId}` and `/bookings/{bookingId}`. A successful entry scan writes:

- `/active_qr_tickets/{qrId}.status = used`
- `/active_qr_tickets/{qrId}.usedAt = server scan time`
- `/bookings/{bookingId}.status = active_parking`
- `/bookings/{bookingId}.entryVerified = true`
- `/bookings/{bookingId}.entryScannedAt = server scan time`
- `/bookings/{bookingId}.qrUsedAt = server scan time`

The used QR is never made active again. The user must complete the current parking cycle or create a new booking to receive a fresh QR id.

## Privacy

The scanner never trusts QR contents beyond `qrId`. It does not parse JSON QR payloads. User, admin, booking, vehicle, and parking data are resolved from Firebase only after the QR id is validated.

## Debug Logging

Debug logs include the raw scanned payload, normalized `qrId`, Firestore lookup start, booking lookup result, parking-area lookup result, and transaction outcome. These logs are for device debugging and should not be shown directly in gate-staff UI.
