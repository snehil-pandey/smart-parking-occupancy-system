# Firebase Setup

This addon branch initializes Firebase with the same `park-here-dev` FlutterFire project options used by the Park Here user/admin apps. Firebase API keys and app ids are client configuration, not service-account secrets. Do not commit service account JSON files or private admin credentials.

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

5. If you use FlutterFire CLI, regenerate `lib/firebase_options.dart` against the same Park Here Firebase project if the Android app id changes.

## Firestore Collections Used

```text
/active_qr_tickets/{qrId}
/bookings/{bookingId}
/parking_areas/{areaId}
/qr_scan_logs/{scanId}
```

## Firestore Transaction

Confirm Entry reads the QR ticket and booking in one transaction, rejects invalid states, marks the QR ticket `used`, sets the booking to `active_parking`, records `entryVerified`, `entryScannedAt`, and `qrUsedAt`, then writes a minimal scan log.

## Security Note

For production, prefer staff-authenticated scanner accounts or a small server/API layer. This fallback app currently assumes Firestore rules allow the scanner to read active tickets/bookings and update the specific verification fields.
