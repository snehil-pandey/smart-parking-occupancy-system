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

The scanner currently initializes Firebase with explicit FlutterFire options in `lib/firebase_options.dart`. A local `google-services.json` is still useful for Android tooling, but it must match the scanner package if you later enable the Google Services Gradle plugin. A file downloaded for the admin or user app can point at the correct project while still having the wrong Android package registration.

On startup the scanner logs:

- Firebase initialized
- Firebase project id
- Firestore instance ready
- Auth not used in fallback mode

## Firestore Collections Used

```text
/active_qr_tickets/{qrId}
/bookings/{bookingId}
/parking_areas/{areaId}
/qr_scan_logs/{scanId}
```

The scanner reads `regions` and `parking_areas.gatePoints` at startup so the Android device can emulate a specific physical gate. If no parking areas or gates exist, the scanner shows an empty state until the Admin app creates them.

## Firestore Transaction

Confirm Entry reads the QR ticket and booking in one transaction, rejects invalid states, rejects wrong-location scans, marks the QR ticket `used`, sets the booking to `active_parking`, records `entryVerified`, `entryScannedAt`, `entryVerifiedAt`, `entryGateId`, `entryScannerMode`, and `qrUsedAt`, then writes a minimal scan log.

## Security Note

For production, prefer staff-authenticated scanner accounts or a small server/API layer. This fallback app currently assumes Firestore rules allow the scanner to read active tickets/bookings and update the specific verification fields.
