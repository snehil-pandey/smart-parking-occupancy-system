# QR Verification Flow

The user app creates a privacy-preserving QR ticket and the gate verifier reads the same Firebase records. This document matches the current user-app QR model: one opaque `qrId` and one lifecycle field on `/active_qr_tickets/{qrId}.status`.

## Payload

The rendered QR contains only the opaque live QR id:

```text
qr_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

It must not contain `userId`, `adminId`, `areaId`, vehicle number, booking JSON, timestamps, or signatures. The full mapping stays in Firebase:

```text
/active_qr_tickets/{qrId}
  qrId
  bookingId
  userId
  adminId
  areaId
  status
  bookingStartAt
  bookingEndAt
  expiresAt
  entryScannedAt
  exitScannedAt
```

The parser remains migration-safe for old JSON QR payloads: it extracts `qrId` when present and does not crash. New QR generation writes opaque ids only.

## Booking Creation

1. The user selects a bookable `/parking_areas/{areaId}` document.
2. The app blocks booking if the user already has a `confirmed` or `active_parking` booking.
3. The app reserves one slot with a Firestore transaction.
4. The app creates `/bookings/{bookingId}` with `status = confirmed`, `qrId`, `qrPayload`, `bookingStartAt`, and `bookingEndAt`.
5. The app creates `/active_qr_tickets/{qrId}` with `status = active` and the same booking time range.
6. The Bookings tab listens to booking and active QR snapshots.

## Active QR Status

```mermaid
stateDiagram-v2
  [*] --> active: booking confirmed
  active --> active: before unlock, QR locked in UI
  active --> entry_verified: entry scan
  entry_verified --> completed: exit scan before bookingEndAt
  active --> expired: now > bookingEndAt
  entry_verified --> expired: now > bookingEndAt
  active --> cancelled: booking cancelled
  entry_verified --> cancelled: booking cancelled
  completed --> [*]
  expired --> [*]
  cancelled --> [*]
```

Allowed `active_qr_tickets.status` values:

- `active`: booking exists and QR can unlock for entry.
- `entry_verified`: entry scan is done; the same QR remains linked for exit.
- `completed`: exit scan is done; QR is no longer active.
- `expired`: booking time expired; QR is no longer active.
- `cancelled`: booking was cancelled; QR is no longer active.

The user app does not rely on `scanPhase` or `scannedOnce`.

## User QR Visibility

- Before `bookingStartAt - 5 minutes`: show a locked countdown instead of the QR.
- `active` during the unlock window: show the QR with entry-gate guidance.
- `entry_verified`: show the same QR with exit-gate guidance until `bookingEndAt`.
- `completed`, `expired`, or `cancelled`: hide the QR from the active booking section and show the booking in history.
- Expired status takes precedence over entry-verified display.

## Verifier Rules

The verifier should use a Firestore transaction so two scanners cannot update the same QR state at the same time:

1. Read `/active_qr_tickets/{qrId}`.
2. Read the linked `/bookings/{bookingId}`.
3. Reject if the QR is missing, cancelled, completed, expired, or scanned at the wrong `areaId`.
4. If current time is before `bookingStartAt - 5 minutes`, return `BEFORE_TIME` and do not write state.
5. If current time is after `bookingEndAt`, mark the ticket and booking `expired`, preserve booking history, and return `EXPIRED`.
6. If ticket status is `active`, this is entry: set ticket `status = entry_verified`, set booking `status = active_parking`, and write `entryVerified`/`entryScannedAt`.
7. If ticket status is `entry_verified`, this is exit before `bookingEndAt`: set ticket `status = completed`, set booking `status = completed`, and write `exitScannedAt`/`completedAt`.

Expected plain-text verifier commands:

- `BEFORE_TIME`: QR is not unlocked yet.
- `ENTRY`: entry verification succeeded.
- `EXIT`: exit verification succeeded and booking completed.
- `EXPIRED`: booking/QR is expired or already completed.
- `INVALID`: QR is malformed, missing, cancelled, or belongs to another parking area.
- `ERROR`: verifier or Firebase failure.

## Notifications

The user app shows QR countdowns in the booking QR viewer and writes in-app notification records before expiry. It also schedules best-effort local notifications at 10 minutes, 2 minutes, and expiry where the platform/plugin supports it. Web and some desktop targets may ignore brightness or local notification APIs; the Updates tab remains the reliable in-app fallback.
