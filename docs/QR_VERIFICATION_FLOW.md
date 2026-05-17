# QR Verification Flow

The MVP creates a QR-ready booking payload in the user app and stores the same payload on the booking record. Hardware gate scanning is intentionally outside this repository, but the data shape is ready for it.

## Payload

The QR payload is a JSON string:

```json
{
  "issuer": "park_here",
  "bookingId": "book_...",
  "userId": "user_...",
  "parkingLocationId": "loc_...",
  "vehicleNumber": "KA 05 MN 4242",
  "startTime": "2026-05-17T10:00:00.000",
  "endTime": "2026-05-17T12:00:00.000",
  "version": 1,
  "signature": "local-checksum"
}
```

## MVP Verification Idea

1. The app creates `/bookings/{bookingId}` with `status: active` and `qrPayload`.
2. The driver shows the QR at the entry gate.
3. A future scanner reads `bookingId`, `vehicleNumber`, time window, and signature.
4. The scanner calls Firestore or a small API to fetch `/bookings/{bookingId}`.
5. The scanner compares:
   - booking exists
   - status is `active`
   - `parkingLocationId` matches the gate
   - current time is between `startTime` and `endTime`
   - scanned vehicle matches `vehicleNumber`
   - signature is valid

## Production Signing

The current checksum is useful for local demos, not security. Production should sign the payload server-side using an HMAC secret or asymmetric key. The gate should verify the signature without exposing the private signing secret to mobile clients.

## Firestore/API Option

For small pilots, the gate can use a locked-down service account or callable HTTPS function:

```text
POST /verify-booking
{
  "bookingId": "...",
  "parkingLocationId": "...",
  "qrPayload": "..."
}
```

The API returns `allow`, `reject_reason`, and optional booking metadata. This keeps security rules simple and avoids putting broad Firestore credentials on gate devices.

