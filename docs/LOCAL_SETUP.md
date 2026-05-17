# Local Setup

## Requirements

- Flutter stable
- Dart SDK bundled with Flutter
- Android Studio/Xcode only when building Android/iOS
- Chrome or Edge for quick web runs

## First Run

```bash
git status
cd apps/park_here_user
flutter pub get
flutter run -d chrome
```

In a second terminal:

```bash
cd apps/park_here_admin
flutter pub get
flutter run -d chrome
```

## Local Mode

Both apps use in-memory repositories. Restarting the app resets demo data. That is deliberate: it keeps the MVP easy to run before Firebase configuration exists.

## Demo Data

Run this from the repository root to print Firestore-shaped JSON:

```bash
dart run scripts/seed_demo_data.dart
```

## Firebase Mode

The current repository is intentionally local-first. It has Firebase-ready models, collection path constants, repository interfaces, and placeholder Firebase repositories, but it does **not** include real Firebase app configuration yet.

Current Firebase-related files already in the repo:

- `shared/lib/services/firebase_collection_paths.dart`
- `shared/lib/services/firebase_readiness_service.dart`
- `shared/lib/repositories/firebase_parking_repository.dart`
- `shared/lib/repositories/firebase_booking_repository.dart`
- `docs/FIREBASE_SCHEMA.md`
- `.env.example`
- `.gitignore` entries for `.env`, `firebase_options.dart`, `google-services.json`, and `GoogleService-Info.plist`

Files that do **not** exist yet and must be generated or downloaded during setup:

- `apps/park_here_user/lib/firebase_options.dart`
- `apps/park_here_admin/lib/firebase_options.dart`
- `apps/park_here_user/android/app/google-services.json`
- `apps/park_here_admin/android/app/google-services.json`
- `apps/park_here_user/ios/Runner/GoogleService-Info.plist`
- `apps/park_here_admin/ios/Runner/GoogleService-Info.plist`

### 1. Create the Firebase project

Use one Firebase project for the MVP unless you specifically want separate staging/production projects.

Firebase Console path:

1. Open the [Firebase console](https://console.firebase.google.com/).
2. Select **Add project**.
3. Name it something like `park-here-dev`.
4. Google Analytics is optional for this MVP.
5. Copy the final Firebase project id. The examples below use `<firebase-project-id>`.

CLI alternative:

```bash
firebase projects:create park-here-dev
firebase projects:list
```

### 2. Install Firebase CLI

Install Node.js first if `node` and `npm` are not available.

```bash
npm install -g firebase-tools
firebase login
firebase projects:list
```

If `firebase` is not recognized on Windows, restart the terminal and confirm npm's global bin directory is on `PATH`.

### 3. Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
flutterfire --version
```

If `flutterfire` is not recognized, add Dart's global pub cache bin folder to `PATH`.

Common locations:

- Windows: `%LOCALAPPDATA%\Pub\Cache\bin`
- macOS/Linux: `$HOME/.pub-cache/bin`

### 4. Enable Firebase products

In the Firebase console for `<firebase-project-id>`:

Authentication:

1. Go to **Build > Authentication**.
2. Click **Get started**.
3. Open **Sign-in method**.
4. Enable **Email/Password** for the first production pass.
5. Optional later: enable Phone, Google, or Apple sign-in.

Cloud Firestore:

1. Go to **Build > Firestore Database**.
2. Click **Create database**.
3. Choose a region close to your users.
4. Use **Test mode** only for local development.
5. Before production, replace test rules with role-based rules matching `docs/FIREBASE_SCHEMA.md`.

Firebase Storage:

1. Go to **Build > Storage**.
2. Click **Get started**.
3. Choose the same general region as Firestore when possible.
4. Start with authenticated-only rules for admin image upload.
5. Note that new Firebase Storage projects may require the Blaze plan depending on current Firebase/Google Cloud policy.

### 5. Add Flutter Firebase packages

Run these from the repository root. Because this repo uses Dart workspace resolution, the root `pubspec.lock` is the active lockfile.

User app:

```bash
cd apps/park_here_user
flutter pub add firebase_core firebase_auth cloud_firestore firebase_storage
cd ../..
```

Admin app:

```bash
cd apps/park_here_admin
flutter pub add firebase_core firebase_auth cloud_firestore firebase_storage
cd ../..
```

### 6. Configure the User app

Run FlutterFire from the user app directory so it reads the correct Android package and iOS bundle id.

Project identifiers already present:

- Android package/application id: `com.parkhere.park_here_user`
- iOS bundle id: `com.parkhere.parkHereUser`

Command:

```bash
cd apps/park_here_user
flutterfire configure --project=<firebase-project-id> --platforms=android,ios,web --out=lib/firebase_options.dart
cd ../..
```

Expected output:

- `apps/park_here_user/lib/firebase_options.dart`
- A Firebase Android app registered for `com.parkhere.park_here_user`
- A Firebase iOS app registered for `com.parkhere.parkHereUser`
- A Firebase Web app registered for the user app

If you manually download native config files from the Firebase console, put them here:

- Android: `apps/park_here_user/android/app/google-services.json`
- iOS: `apps/park_here_user/ios/Runner/GoogleService-Info.plist`

### 7. Configure the Admin app

Run FlutterFire again from the admin app directory. The admin app should be a separate Firebase Android/iOS/Web app inside the same Firebase project.

Project identifiers already present:

- Android package/application id: `com.parkhere.park_here_admin`
- iOS bundle id: `com.parkhere.parkHereAdmin`

Command:

```bash
cd apps/park_here_admin
flutterfire configure --project=<firebase-project-id> --platforms=android,ios,web --out=lib/firebase_options.dart
cd ../..
```

Expected output:

- `apps/park_here_admin/lib/firebase_options.dart`
- A Firebase Android app registered for `com.parkhere.park_here_admin`
- A Firebase iOS app registered for `com.parkhere.parkHereAdmin`
- A Firebase Web app registered for the admin app

If you manually download native config files from the Firebase console, put them here:

- Android: `apps/park_here_admin/android/app/google-services.json`
- iOS: `apps/park_here_admin/ios/Runner/GoogleService-Info.plist`

### 8. Initialize Firebase in each app

After packages and `firebase_options.dart` exist, each app's `main.dart` needs Firebase initialization before `runApp`.

Pattern for both apps:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: ParkHereUserApp()));
}
```

Use `ParkHereAdminApp` in the admin app. Keep the local-first fallback until Firebase repositories are fully implemented so missing config remains easy to diagnose.

### 9. Wire repositories after setup

After Firebase config is generated, dependencies are added, and the repository methods are implemented, replace the local providers with Firebase providers.

```dart
final parkingRepositoryProvider = Provider<ParkingRepository>(
  (ref) => FirebaseParkingRepository(),
);
```

Do the same for booking and auth repositories when their Firebase implementations are ready.

### 10. Platform notes

Android:

- `google-services.json` belongs in `android/app/`.
- The user app package is `com.parkhere.park_here_user`.
- The admin app package is `com.parkhere.park_here_admin`.
- If Firebase or a plugin adds Android Gradle plugin changes, run `flutterfire configure` again from that app folder.

Web:

- FlutterFire stores web config in `lib/firebase_options.dart`.
- Do not paste Firebase JS SDK snippets into `web/index.html` when using FlutterFire configuration.
- Add local dev domains in Firebase Auth authorized domains if needed.

iOS:

- `GoogleService-Info.plist` belongs in `ios/Runner/`.
- The user app bundle id is `com.parkhere.parkHereUser`.
- The admin app bundle id is `com.parkhere.parkHereAdmin`.
- Build and final iOS signing must be done on macOS with Xcode.

### 11. Secrets and commits

This repo currently ignores Firebase config files:

- `firebase_options.dart`
- `google-services.json`
- `GoogleService-Info.plist`

Firebase web/mobile API keys identify a Firebase project but are not server secrets. Still, for this academic/local-first repo, keep generated real project config out of git unless the team deliberately decides to track non-production Firebase config.

Never commit:

- `.env`
- service account JSON files
- private signing keys
- CI tokens
- production Firebase Admin SDK credentials

### 12. Troubleshooting

`firebase: command not found` or `firebase is not recognized`:

- Reinstall with `npm install -g firebase-tools`.
- Restart the terminal.
- Check that npm's global binary directory is on `PATH`.

`flutterfire: command not found`:

- Run `dart pub global activate flutterfire_cli`.
- Add the Dart pub cache bin directory to `PATH`.

`flutterfire configure` creates the wrong Firebase app:

- Run it from `apps/park_here_user` or `apps/park_here_admin`, not from the repo root.
- Confirm the Android package and iOS bundle ids listed above.
- Delete the incorrect Firebase app in the Firebase console if it was created accidentally.

`DefaultFirebaseOptions` is missing:

- Confirm `lib/firebase_options.dart` exists in the app you are running.
- Confirm `main.dart` imports `firebase_options.dart`.
- Rerun `flutterfire configure` from that app directory.

Android build cannot find `google-services.json`:

- If using manual/native config, place it in `apps/<app>/android/app/google-services.json`.
- If using only `firebase_options.dart`, make sure no Gradle file was manually changed to require the Google Services plugin without the file.

iOS build cannot find `GoogleService-Info.plist`:

- Place it in `apps/<app>/ios/Runner/GoogleService-Info.plist`.
- Open `ios/Runner.xcworkspace` in Xcode and make sure the plist is included in the Runner target if manually added.

Firestore permission denied:

- Check Firestore rules.
- Confirm the user is signed in.
- Confirm role fields match the schema: `/users/{userId}.role == user` and `/admins/{adminId}.role == admin`.

Storage upload denied:

- Check Storage rules and bucket creation.
- Confirm the admin is authenticated.
- Confirm the file path convention, for example `parking_locations/{locationId}/images/{fileName}`.
