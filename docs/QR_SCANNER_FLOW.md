# QR Scanner Flow

Park Here Scanner is a standalone Android fallback for gate verification. ESP32 QR hardware remains the primary flow.

## Runtime Flow

1. Initialize Firebase.
2. Open the camera scanner.
3. Read the QR payload.
4. Accept only opaque `qr_live_...` ids.
5. Fetch `/active_qr_tickets/{qrId}`.
6. Verify the ticket exists, is `active`, and `expiresAt` is in the future.
7. Fetch `/bookings/{bookingId}`.
8. Accept only `active` or `confirmed` bookings.
9. Show the parking area, vehicle number, validity, and status.
10. On Confirm Entry, consume the QR in a transaction.

## Rejection States

- `Invalid QR`: payload is not an opaque Park Here QR id.
- `Already Used`: ticket status is `used`.
- `Expired Ticket`: ticket is expired or no longer active.
- `Booking Not Found`: linked booking is missing.
- `Booking Not Active`: linked booking is cancelled, completed, pending, or expired.
- `Network Error`: Firebase read/write failed.

## Double Scan Prevention

The UI ignores additional camera detections while verification is running. The Confirm Entry action also uses a Firestore transaction, so two devices cannot safely consume the same QR at the same time.

## Privacy

The scanner never trusts QR contents beyond `qrId`. It does not parse JSON QR payloads. User, admin, booking, vehicle, and parking data are resolved from Firebase only after the QR id is validated.
