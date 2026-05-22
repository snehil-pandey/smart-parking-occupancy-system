# Park Here Scanner

Park Here Scanner is a standalone Android fallback QR scanner for Park Here gate and security verification.

The primary Park Here gate flow is still ESP32-based QR hardware. This app exists for the practical case where the ESP32 scanner is unavailable, being repaired, or not yet installed. It is not the Park Here user app, not the admin app, and not a booking interface.

## What This App Does

- Opens the Android camera with `mobile_scanner`
- Reads only an opaque `qrId`
- Validates the `qr_live_...` format
- Fetches `/active_qr_tickets/{qrId}` from Firebase
- Fetches the linked `/bookings/{bookingId}`
- Optionally fetches `/parking_areas/{areaId}` for display
- Shows a simple gate-staff result
- Confirms entry with a Firestore transaction
- Marks the booking as `active_parking` after entry verification

## QR Privacy Rule

The QR payload must be only the opaque ticket id:

```text
qr_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

The QR must not contain JSON, `userId`, `adminId`, vehicle number, booking details, timestamps, or parking area data. Firebase is the source of truth.

## Build

Install Flutter, configure Firebase, then run:

```bash
flutter pub get
flutter build apk --dart-define=NO_ESP=true
```

`NO_ESP=true` means this APK is the Android fallback scanner mode and verifies directly through Firebase instead of ESP32 hardware.

### Windows Kotlin Build Troubleshooting

On Windows, Kotlin incremental compilation can occasionally crash while compiling Android plugins such as `mobile_scanner` with an error like `this and base files have different roots`. The scanner disables Kotlin incremental compilation in `android/gradle.properties`:

```properties
kotlin.incremental=false
kotlin.incremental.useClasspathSnapshot=false
org.gradle.caching=false
```

If the cache issue appears again, reset only generated files:

```powershell
cd android
.\gradlew --stop
cd ..
flutter clean
Remove-Item -Recurse -Force .dart_tool, build, android\.gradle, android\app\build -ErrorAction SilentlyContinue
flutter pub get
flutter build apk --release --dart-define=NO_ESP=true
```

## Firebase Setup

This branch does not commit real Firebase secrets. Add Android Firebase configuration locally before running on a device:

1. Create/select the Firebase project used by Park Here.
2. Add an Android app with package `com.example.park_here_scanner` or update the package name and Firebase app to match.
3. Download `google-services.json`.
4. Place it at `android/app/google-services.json`.
5. Follow `docs/FIREBASE_SETUP.md` if your FlutterFire setup requires generated options or Gradle plugin changes.

## Transaction Behavior

Confirm Entry runs a Firestore transaction:

1. Read `/active_qr_tickets/{qrId}`.
2. Reject missing, used, expired, or non-active tickets.
3. Read linked `/bookings/{bookingId}`.
4. Reject missing or inactive bookings.
5. Mark the ticket `used`.
6. Update booking `status` to `active_parking`.
7. Set booking `entryVerified`, `entryScannedAt`, and `qrUsedAt`.
8. Write a minimal `/qr_scan_logs/{scanId}` record.

This prevents double-scan/double-entry behavior.

The used QR is never reactivated. A user receives another scannable QR only after completing the parking cycle and creating a new booking.

## Project Structure

```text
lib/main.dart
lib/src/app.dart
lib/src/firebase_bootstrap.dart
lib/src/scanner_screen.dart
lib/src/result_screen.dart
lib/src/qr_models.dart
lib/src/qr_verification_service.dart
docs/QR_SCANNER_FLOW.md
docs/FIREBASE_SETUP.md
```
