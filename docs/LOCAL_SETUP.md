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

To seed a real Firebase project with SIT Tumkur demo data:

```bash
cd demo
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
python seed_firebase_demo.py
```

Edit `demo/.env` before running:

```text
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
FIREBASE_PROJECT_ID=your-project-id
```

See `demo/setup_demo.md` for the full service-account and verification flow. Never commit `serviceAccountKey.json`.

## Firebase Mode

The current repository is intentionally local-first. It has Firebase-ready models, collection path constants, repository interfaces, and Firestore repository implementations. Real Firebase config files can exist locally, but app logic still defaults to in-memory repositories until you wire the Firebase providers.

Current Firebase-related code/docs already in the repo:

- `shared/lib/services/firebase_collection_paths.dart`
- `shared/lib/services/firebase_readiness_service.dart`
- `shared/lib/repositories/firebase_parking_repository.dart`
- `shared/lib/repositories/firebase_booking_repository.dart`
- `shared/lib/repositories/firebase_region_repository.dart`
- `shared/lib/repositories/firebase_review_repository.dart`
- `shared/lib/repositories/firebase_issue_repository.dart`
- `shared/lib/repositories/firestore_image_repository.dart`
- `shared/lib/services/firestore_model_mapper.dart`
- `docs/FIREBASE_SCHEMA.md`
- `.env.example`
- `.gitignore` entries for `.env`, `firebase_options.dart`, `google-services.json`, and `GoogleService-Info.plist`

Local Firebase config files currently present in this workspace:

- `apps/park_here_user/lib/firebase_options.dart`
- `apps/park_here_admin/lib/firebase_options.dart`
- `apps/park_here_user/android/app/google-services.json`
- `apps/park_here_admin/android/app/google-services.json`

These files are intentionally ignored by git. Treat them as local Firebase setup artifacts, and regenerate them for your own project with FlutterFire CLI when moving machines or Firebase projects.

Files still missing unless you configure iOS manually or via FlutterFire:

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
5. Treat this as optional. Firebase Storage may require the Blaze/pay-as-you-go plan depending on current Firebase/Google Cloud policy.

### Firestore-only image mode is the default

Park Here now uses hybrid image architecture:

1. **Default**: Firestore-only optimized image documents.
2. **Future optional**: Firebase Storage-backed image repository.

Why: the project should remain useful on free-tier Firebase as much as possible. The app should not depend entirely on Firebase Storage just to show parking area photos.

Default Firestore image collection:

```text
/parking_area_images/{imageId}
  imageId
  areaId
  uploadedByAdminId
  thumbnailBase64
  previewBase64
  mimeType
  uploadedAt
```

Parking area documents store only refs:

```text
/parking_areas/{areaId}
  thumbnailRefs: ["img_..."]
  imagePreviewRefs: ["img_..."]
```

Limits enforced by the shared image optimizer:

- Original upload accepted by local pipeline: <= 700KB
- Thumbnail target: <= 30KB
- Preview target: <= 120KB
- Thumbnail max dimension: 160px
- Preview max dimension: 720px
- Output format: compressed JPEG

Performance rules:

- Do not store original heavy images in Firestore.
- Do not place image base64 directly inside parking area documents.
- Do not load every image in realtime parking area streams.
- List screens fetch one thumbnail per area.
- Details screens lazy-load previews only after the user opens an area.
- Use `ImagePayloadCache` to avoid repeated decode/fetch work.
- Use `limit(...)` and `startAfterDocument(...)` when galleries grow.

Repository strategy:

```text
ImageRepository
  FirestoreImageRepository          default Firebase mode
  FirebaseStorageImageRepository    optional future mode
  InMemoryImageRepository           local/demo mode
```

When Firebase is wired, implement `FirestoreImageRepository` first. Only implement `FirebaseStorageImageRepository` if the Firebase project can use Storage billing/config safely.

### 5. Add Flutter Firebase packages

Run these from the repository root. Because this repo uses Dart workspace resolution, the root `pubspec.lock` is the active lockfile.

User app:

```bash
cd apps/park_here_user
flutter pub add firebase_core firebase_auth cloud_firestore
cd ../..
```

Admin app:

```bash
cd apps/park_here_admin
flutter pub add firebase_core firebase_auth cloud_firestore
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

After Firebase config is generated and each app initializes Firebase, replace the local providers with Firebase providers.

```dart
final parkingRepositoryProvider = Provider<ParkingRepository>(
  (ref) => FirebaseParkingRepository(),
);
```

Do the same for booking and auth repositories when their Firebase implementations are ready.
Firestore-backed region, booking, review, issue, and Firestore image repositories are already implemented in `shared`. Auth remains local-first until a Firebase Auth service is added.

For images, keep Firestore mode as the default:

```dart
final imageRepositoryProvider = Provider<ImageRepository>(
  (ref) => FirestoreImageRepository(),
);
```

Switch to Storage only when the project is ready for Blaze/pay-as-you-go:

```dart
final imageRepositoryProvider = Provider<ImageRepository>(
  (ref) => FirebaseStorageImageRepository(),
);
```

### 10. Platform notes

Android:

- `google-services.json` belongs in `android/app/`.
- The user app package is `com.parkhere.park_here_user`.
- The admin app package is `com.parkhere.park_here_admin`.
- If Firebase or a plugin adds Android Gradle plugin changes, run `flutterfire configure` again from that app folder.
- Firestore-only image mode does not need `firebase_storage` or Storage Gradle setup.

Web:

- FlutterFire stores web config in `lib/firebase_options.dart`.
- Do not paste Firebase JS SDK snippets into `web/index.html` when using FlutterFire configuration.
- Add local dev domains in Firebase Auth authorized domains if needed.
- Firestore-only image mode stores optimized payloads as Firestore document fields; watch document size and read counts.

iOS:

- `GoogleService-Info.plist` belongs in `ios/Runner/`.
- The user app bundle id is `com.parkhere.parkHereUser`.
- The admin app bundle id is `com.parkhere.parkHereAdmin`.
- Build and final iOS signing must be done on macOS with Xcode.
- Firestore-only image mode does not require Storage bucket configuration.

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
- Confirm the file path convention, for example `parking_areas/{areaId}/images/{fileName}`.
- If you are using default Firestore-only image mode, this error usually means Storage code was enabled too early. Use `FirestoreImageRepository` instead.

Image document too large:

- Lower preview dimensions or JPEG quality.
- Keep decoded thumbnail <= 30KB and decoded preview <= 120KB.
- Reject original images above the configured upload limit.
- Store additional images as separate `/parking_area_images` documents, not as fields on `/parking_areas`.

Image-heavy screens feel slow:

- Confirm list views fetch thumbnails only.
- Confirm preview queries use `limit`.
- Confirm images are cached with `ImagePayloadCache`.
- Avoid realtime listeners on image payload collections unless there is a real live-edit requirement.
Add `firebase_storage` later only if you switch to `FirebaseStorageImageRepository`.
