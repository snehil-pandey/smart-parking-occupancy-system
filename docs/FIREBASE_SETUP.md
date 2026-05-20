# Firebase Setup

This addon branch intentionally does not include real Firebase secrets.

## Required Firebase Services

- Firebase Core
- Cloud Firestore
- Optional Firebase Auth if project rules require staff login

## Android Configuration

1. In Firebase Console, add or select an Android app for the scanner.
2. Use package name `com.example.park_here_scanner`, or update the Android package and Firebase app together.
3. Download `google-services.json`.
4. Place it at:

   ```text
   android/app/google-services.json
   ```

5. If you use FlutterFire CLI, generate local Firebase options as needed. Do not commit real secrets unless the project policy allows it.

## Firestore Collections Used

```text
/active_qr_tickets/{qrId}
/bookings/{bookingId}
/parking_areas/{areaId}
/qr_scan_logs/{scanId}
```

## Firestore Transaction

Confirm Entry reads the QR ticket and booking in one transaction, rejects invalid states, marks the QR ticket `used`, updates booking `qrUsedAt`, and writes a minimal scan log.

## Security Note

For production, prefer staff-authenticated scanner accounts or a small server/API layer. This fallback app currently assumes Firestore rules allow the scanner to read active tickets/bookings and update the specific verification fields.
