# QR Verification Flow

The user app creates a privacy-preserving QR ticket and the ESP32/Python bridge verifies it through the same Firebase project.

## Payload

The QR code now contains only one opaque live QR id:

```text
qr_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

It must not contain `userId`, `adminId`, `areaId`, vehicle number, booking JSON, timestamps, or signatures. The app stores the full mapping only in Firebase:

```text
/active_qr_tickets/{qrId}
  qrId
  bookingId
  userId
  adminId
  areaId
  status
  createdAt
  expiresAt
```

The parser remains migration-safe for old JSON QR payloads: it extracts `qrId` when present and never crashes. New QR generation always writes opaque ids only.

## Verification Flow

1. The app reserves one parking area slot.
2. The app creates `/bookings/{bookingId}` with `status: confirmed`, `qrId`, `qrPayload`, `bookingStartAt`, and `bookingEndAt`.
3. The app creates `/active_qr_tickets/{qrId}` with `status: active`, `scannedOnce: false`, and `scanPhase: entry_pending`.
4. The user app hides the QR until five minutes before `bookingStartAt`.
5. The driver shows the QR at the entry gate during the unlock window.
6. The standalone scanner or ESP32 bridge reads only `qrId`.
7. The verifier fetches the active QR and booking records from Firebase.
8. The verifier compares:
   - booking exists
   - active QR ticket exists
   - QR ticket status is `active`
   - booking status is `confirmed`
   - `areaId` / `parkingLocationId` matches the gate
   - current time is between `bookingStartAt - 5 minutes` and `bookingEndAt`
9. On entry success, the verifier marks entry verified and moves the booking to `active_parking`.
10. The same `qrId` stays linked to the booking for exit, then closes only after exit or expiry.

## Active QR Lifecycle

```mermaid
sequenceDiagram
  participant User
  participant App
  participant Firestore
  participant Gate

  User->>App: Book parking area
  App->>Firestore: Transaction reserves slot
  App->>Firestore: Create confirmed booking + active_qr_ticket
  App-->>User: Countdown until QR unlock window
  Gate->>Firestore: Transaction reads active_qr_tickets/{qrId}
  Gate->>Firestore: Mark entry scanned/scannedOnce and booking active_parking
  Firestore-->>Gate: ENTRY
  Firestore-->>App: Snapshot updates parking active state
  Gate->>Firestore: Same qrId scanned near booking end
  Gate->>Firestore: Mark booking completed and QR used
  Firestore-->>Gate: EXIT
  Firestore-->>App: Snapshot moves booking to history
```

`/active_qr_tickets/{qrId}` may be marked `active`, `used`, `expired`, or `cancelled`. Entry keeps the ticket `active` with `scanPhase = entered`; exit marks it `used`. The permanent booking remains in `/bookings/{bookingId}` for user/admin history and income reporting.

Firestore verification should use a transaction or callable API so two scanners cannot consume the same QR at the same time:

1. Read `active_qr_tickets/{qrId}`.
2. Reject with `BEFORE_TIME` if the current time is earlier than `bookingStartAt - 5 minutes`.
3. Read linked `/bookings/{bookingId}`.
4. Reject if the QR is missing, cancelled, expired, already exited, or scanned at the wrong `areaId`.
5. For entry, require booking status `confirmed`, QR status `active`, no `entryScannedAt`, and current time from `bookingStartAt - 5 minutes` through `bookingEndAt`.
6. Update QR `scannedOnce = true`, `scanPhase = entered`, and `entryScannedAt`; keep QR status `active`.
7. Update booking `status = active_parking`, `entryVerified = true`, and `entryScannedAt`.
8. For exit, require booking status `active_parking`, `entryVerified = true`, no `exitScannedAt`, and current time from `bookingEndAt - 10 minutes` through `bookingEndAt + 10 minutes`.
9. Update booking `status = completed` and `exitScannedAt`.
10. Update QR `scanPhase = exited`, `status = used`, `exitScannedAt`, and `completedAt`.

The scanner re-reads the QR state inside the transaction. A second entry scan cannot reopen entry; before the exit window it returns `BEFORE_TIME`, after completion it returns `USED`. The user app listens to booking and active QR snapshots, so it changes from entry QR to parking-active state to exit QR/history without a reload.

The ESP32 bridge returns plain text commands for hardware:

- `BEFORE_TIME`: one long beep, no Firestore state change.
- `ENTRY`: one short beep after the transaction marks the entry scan.
- `EXIT`: two short beeps when a valid exit-mode scan completes the booking.
- `INVALID`, `USED`, `EXPIRED`, or `ERROR`: long error beep.

Exit is handled through booking state using the same opaque `qrId`. A new QR is created only by a new booking.

## QR Expiry Alerts

The user app shows an active countdown in the booking QR viewer and writes in-app notification records before expiry. It also schedules best-effort local notifications at 10 minutes, 2 minutes, and expiry where the platform/plugin supports it. Web and some desktop targets may ignore brightness or local notification APIs; the in-app Updates tab remains the reliable fallback.

## Firestore/API Option

For small pilots, the gate can use a locked-down service account or callable HTTPS function:

```text
POST /verify-booking
{
  "qrId": "...",
  "parkingLocationId": "gate_area_id"
}
```

The API returns `allow`, `reject_reason`, and optional booking metadata. This keeps security rules simple and avoids putting broad Firestore credentials on gate devices.
