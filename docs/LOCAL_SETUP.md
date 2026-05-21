# Local Setup

## Requirements

- Flutter stable
- Dart SDK bundled with Flutter
- Android Studio for Android builds
- Xcode on macOS for iOS builds
- Chrome or Edge for quick web runs
- Firebase CLI
- FlutterFire CLI

## Runtime Data Rule

The apps now use Firebase repositories in normal runtime. They do not load `DemoSeed`, in-memory repositories, or app-bundled fake parking data.

Demo data belongs only in the Firebase seed tool:

```bash
cd demo
python seed_firebase_demo.py
```

The shared `InMemory...Repository` classes remain only for tests and explicit development overrides. If Firebase is not configured, each app should show a setup error instead of silently running fake local data.

## First Run

Generate Firebase config for both apps first, then run:

```bash
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

## Launcher Icons And Display Names

Both apps keep separate launcher icon sources so branding does not cross over:

| App | Display name | Source asset |
| --- | --- | --- |
| User | `Park Here` | `apps/park_here_user/assets/icons/app_icon.png` |
| Admin | `Park Here: Admin` | `apps/park_here_admin/assets/icons/app_icon.png` |

After replacing either icon asset, regenerate platform launchers from that app folder:

```bash
cd apps/park_here_user
flutter pub get
dart run flutter_launcher_icons
```

```bash
cd apps/park_here_admin
flutter pub get
dart run flutter_launcher_icons
```

This updates Android mipmaps/adaptive icons, iOS `AppIcon.appiconset`, web icons, and favicon files. Android labels, iOS `CFBundleDisplayName`, and web manifest/title values are tracked in platform metadata.

## Firebase Project Setup

Use one Firebase project for the MVP unless you need separate staging and production projects.

1. Open the Firebase console.
2. Create a project such as `park-here-dev`.
3. Enable Google Analytics only if you need it.
4. Keep the project id handy for FlutterFire and the demo seed script.

Install and sign in to Firebase CLI:

```bash
npm install -g firebase-tools
firebase login
firebase projects:list
```

Install FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
flutterfire --version
```

If `flutterfire` is not recognized, add Dart pub cache bin to `PATH`.

- Windows: `%LOCALAPPDATA%\Pub\Cache\bin`
- macOS/Linux: `$HOME/.pub-cache/bin`

## Enable Firebase Products

Authentication:

1. Open **Build > Authentication**.
2. Enable **Email/Password** sign-in.
3. User and admin apps both use Firebase Auth, but profiles are stored in separate Firestore collections.
4. The demo seed creates Email/Password Auth users for `@parkhere.demo` accounts. If Email/Password is disabled, seeded logins cannot work.

Cloud Firestore:

1. Open **Build > Firestore Database**.
2. Create a database near your users.
3. Use test mode only while developing locally.
4. Before production, replace rules with role-aware rules matching `docs/FIREBASE_SCHEMA.md`.
5. Deploy composite indexes from the project root before testing realtime app queries. The checked-in index file is derived from the Firestore queries in the shared Firebase repositories:

```bash
firebase login
firebase use park-here-dev
firebase deploy --only firestore:indexes
```

Run these commands from the repository root so Firebase CLI reads the checked-in `firebase.json` and `firestore.indexes.json`.

If Firebase CLI has not been initialized for Firestore yet:

```bash
firebase init firestore
```

Use the root `firestore.indexes.json` file when prompted.

Index creation can take a few minutes after deployment. A Firestore `FAILED_PRECONDITION` message with an index link means the required composite index is missing or still building.

While an index is still building, the apps keep the Firebase Auth session alive and show:

```text
Firebase index is still building. Please wait a few minutes and refresh.
```

Use the refresh button in the app after Firebase Console marks the index as enabled.

Firebase Storage:

Storage is optional. Firebase Storage may require Blaze/pay-as-you-go billing, so Park Here defaults to Firestore-only optimized image records. Do not enable Storage code unless your Firebase project is ready for it.

## Configure Both Flutter Apps

Run FlutterFire separately for each app so Android package ids, iOS bundle ids, and web app ids stay correct.

User app:

```bash
cd apps/park_here_user
flutterfire configure --project=<firebase-project-id> --platforms=android,ios,web --out=lib/firebase_options.dart
cd ../..
```

Admin app:

```bash
cd apps/park_here_admin
flutterfire configure --project=<firebase-project-id> --platforms=android,ios,web --out=lib/firebase_options.dart
cd ../..
```

Generated files belong here:

| App | File | Purpose |
| --- | --- | --- |
| User | `apps/park_here_user/lib/firebase_options.dart` | FlutterFire runtime options |
| User | `apps/park_here_user/android/app/google-services.json` | Android native config |
| User | `apps/park_here_user/ios/Runner/GoogleService-Info.plist` | iOS native config |
| Admin | `apps/park_here_admin/lib/firebase_options.dart` | FlutterFire runtime options |
| Admin | `apps/park_here_admin/android/app/google-services.json` | Android native config |
| Admin | `apps/park_here_admin/ios/Runner/GoogleService-Info.plist` | iOS native config |

These files are ignored in this repo. Regenerate them for your Firebase project and do not commit real project config unless the team deliberately chooses to track non-production Firebase app config.

## Firebase Initialization

Both apps initialize Firebase in `main.dart` before the app starts:

- `apps/park_here_user/lib/main.dart`
- `apps/park_here_admin/lib/main.dart`

They use:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

If `firebase_options.dart` is missing or invalid, the app shows a setup error screen instead of falling back to fake local data.

## Login And Profiles

Both apps require Firebase Auth login/signup.

User app:

- Signs in with Firebase Auth Email/Password.
- Loads `/users/{userId}`.
- Creates `/users/{userId}` on signup.
- If an Auth user exists without a user profile, a minimal user profile is created and can be completed in-app.

Admin app:

- Signs in with Firebase Auth Email/Password.
- Loads `/admins/{adminId}`.
- Creates `/admins/{adminId}` on signup.
- If an Auth user exists without an admin profile, a minimal admin profile is created and can be completed in-app.

Do not hardcode current user/admin ids. Runtime queries use the signed-in Firebase Auth uid.

## Firestore Runtime Flow

Runtime providers now use Firebase implementations:

- `FirebaseParkingRepository`
- `FirebaseBookingRepository`
- `FirebaseRegionRepository`
- `FirebaseReviewRepository`
- `FirebaseIssueRepository`
- `FirebaseNotificationRepository`
- `FirestoreImageRepository`
- `FirebaseAuthService`

Admin region setup:

- After admin sign-in, the app looks for a controlled region owned by the Firebase Auth uid.
- If no region exists, the dashboard is blocked and the admin must create a region with name, address, and at least three OSM map points.
- Parking area creation and editing stay locked to that controlled region. Points outside the region are rejected with a friendly error.
- Demo admins continue to use the seeded SIT Tumkur region if it exists in Firestore.

Realtime listeners are bounded:

- User parking availability: `parking_areas` by `regionId`, open status, and limit.
- User bookings: `bookings` by `userId`.
- User active QR: `active_qr_tickets` by `bookingId`.
- User notifications: `notifications` by `userId`.
- Admin areas: `parking_areas` by `adminId`.
- Admin bookings: `bookings` by `adminId`.
- Admin issues: `issue_reports` by `adminId`.

Slot reservation uses a Firestore transaction in `FirebaseParkingRepository.reserveSlot`. Active QR consumption uses transaction-style repository logic to prevent double use.

## User App Map And Search

The user app uses real OpenStreetMap tiles through `flutter_map`:

- live GPS marker from `GeolocatorUserLocationService`
- pan and zoom through Flutter gestures
- animated focus when a parking area or search result is selected
- parking area polygons from `boundaryPoints`
- gate markers from `gatePoints`
- route polylines from the current `RouteProvider`
- fallback message when tile loading fails

OpenStreetMap does not require a Google Maps API key or Google billing account. For production-scale public traffic, follow the OpenStreetMap tile usage policy, use an OSM-compliant commercial tile provider, or self-host tiles.

Search is routed through `PlaceSearchService`. The default implementation is `LocalSitTumkurPlaceSearchService`, so no API key is required. It searches:

- current location
- SIT Tumkur landmarks
- Firebase-loaded parking areas

If you later replace it with Google Places or OpenStreetMap/Nominatim, keep the same service interface and store API keys outside source control.

## Admin OSM Region And Area Editing

The admin app also uses real OpenStreetMap tiles through `flutter_map` for region and area geometry:

- Region Setup: focused on current GPS or the default fallback, with Add Point and Move Point modes.
- Region tab: edits the saved controlled region boundary.
- Add Parking Area: shows the controlled region so the admin starts area setup in the right place.
- Edit Parking Area: shows the controlled region, parking area polygon, numbered corners, selected point, and gates.

Point movement currently uses select-point then tap-to-move. This is the supported cross-platform behavior for now; draggable markers can be added later behind the same controller validation.

## Road-Aware Routing

The user app uses `OsrmRouteProvider` for road-following navigation polylines. Local development uses the public OSRM demo endpoint:

```text
https://router.project-osrm.org
```

No API key is required. The route provider requests full GeoJSON geometry and alternatives, then the map renders those road points. If OSRM is unavailable, the app falls back to a small SIT Tumkur weighted road graph so the UI does not draw fake direct lines through buildings.

For production, configure a dedicated OSRM/OpenRouteService/GraphHopper endpoint with reliable quota and uptime. Keep provider URLs and API keys outside source control if you move to a keyed service.

## QR Tickets And Notifications

QR images encode only an opaque id such as:

```text
qr_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Sensitive booking/user/vehicle details stay in Firestore under `/active_qr_tickets/{qrId}` and `/bookings/{bookingId}`. Old JSON QR payloads are parsed defensively for migration, but new bookings generate opaque ids only.

The Bookings tab opens a full-screen QR viewer when the active ticket is tapped. It enlarges the QR and attempts to raise screen brightness while open. Brightness control is best-effort and may be ignored by web or desktop platforms.

QR expiry alerts are supported in two layers:

- In-app Updates tab notifications from `/notifications`.
- Best-effort local notifications via `flutter_local_notifications` at 10 minutes, 2 minutes, and expiry.

Android/iOS notification permission behavior depends on OS version. Web support is limited; keep the app open for the in-app countdown and Updates tab.

## Client Caching

Do not add Redis inside the Flutter app. This project has no backend server where Redis would naturally live.

Current cache strategy:

- Firestore offline persistence is enabled in the user app after Firebase initialization.
- Riverpod state keeps the latest parking areas, bookings, QR ticket, reviews, and notifications during the session.
- `ImagePayloadCache` avoids repeatedly decoding/fetching optimized Firestore images.
- Search is debounced and runs against loaded Firebase parking areas plus local SIT landmarks.
- Image records are lazy-loaded by area and limit, not streamed as whole collections.

Redis would be useful only if Park Here later adds a FastAPI/Node/Cloud Run backend for high-volume aggregation, rate-limited external APIs, or server-side route/search caching.

## GPS Permissions

The user app uses live device location for nearby parking and route origin. The admin app uses live GPS to mark parking area corners and gates while the admin physically stands at each point.

Android:

- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`

iOS:

- `NSLocationWhenInUseUsageDescription`

Web:

- The browser prompts for location permission.
- Run from `localhost` or HTTPS.

If permission is denied or the platform cannot provide a location, the user app clearly falls back to the SIT Tumkur center for discovery calculations.

For admin marking, do not save final geometry from fallback coordinates. Wait for a live GPS fix with acceptable accuracy, ideally outdoors.

## Firestore-Only Image Mode

Default image mode stores optimized payloads in Firestore:

```text
/parking_area_images/{imageId}
  thumbnailBase64
  previewBase64
  mimeType
  areaId
  uploadedByAdminId
```

Parking area documents store only references:

```text
/parking_areas/{areaId}
  thumbnailRefs
  imagePreviewRefs
  imageUrls: []
```

Limits:

- Original upload accepted by local pipeline: <= 700KB
- Thumbnail target: <= 30KB
- Preview target: <= 120KB
- Thumbnail max dimension: 160px
- Preview max dimension: 720px

Admin uploads images through the app. The image pipeline compresses, generates a thumbnail and preview, then writes image records to Firestore. User lists fetch lightweight thumbnails; area details lazy-load preview images.

## Seed Firebase Demo Data

The only supported demo data path is the root `/demo` folder.

```bash
cd demo
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
python seed_firebase_demo.py
```

Edit `demo/.env`:

```text
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
FIREBASE_PROJECT_ID=your-project-id
```

The script seeds:

- SIT Tumkur region
- One demo admin
- Demo users
- Firebase Auth Email/Password accounts for the demo admin and users
- Parking areas
- Parking area corner and gate placeholders
- Parking area bounds fields for conflict checks
- Reviews
- Issues
- Bookings and active QR data
- Notifications, one payment, and lightweight metrics documents

The seed does not create image payloads by default. Admins can upload optimized images through Firestore image mode.

The seeded parking coordinates are approximate SIT Tumkur placeholders. Read `demo/SIT_TUMKUR_COORDINATE_NOTES.md`, then use the Admin app GPS marker controls to correct real corners and gates.

Never commit:

- `demo/.env`
- `serviceAccountKey.json`
- Firebase Admin SDK credentials
- private signing keys

See `demo/setup_demo.md` for service account creation and verification steps.

Clean reset and reseed:

```bash
cd demo
python reset_firebase_demo.py --yes
python seed_firebase_demo.py
cd ..
firebase use park-here-dev
firebase deploy --only firestore:indexes
```

To also remove and recreate only demo Auth users:

```bash
cd demo
python reset_firebase_demo.py --yes --delete-auth-demo-users
python seed_firebase_demo.py
```

Preview reset impact without deleting anything:

```bash
cd demo
python reset_firebase_demo.py --dry-run
```

Firestore composite indexes are not ordinary Firestore documents. The reset script does not delete indexes, and the seed script does not create them. Keep index definitions in the root `firestore.indexes.json` file and deploy them from the project root with `firebase deploy --only firestore:indexes`.

Firebase Auth UID is the profile document id for `/users/{uid}` and `/admins/{uid}`. Demo profiles also store `authUid`, `userId` or `adminId`, and `email`.

## Troubleshooting

`DefaultFirebaseOptions` is missing:

- Run `flutterfire configure` in the specific app folder.
- Confirm `lib/firebase_options.dart` exists for that app.

Firebase setup error screen appears:

- Confirm Firebase config files exist.
- Confirm the app was rebuilt after configuration.
- Confirm `Firebase.initializeApp` can read `DefaultFirebaseOptions.currentPlatform`.

Login succeeds but profile looks incomplete:

- The Auth account probably existed before Firestore profile setup.
- Complete profile fields in the app or update `/users/{uid}` or `/admins/{uid}` in Firestore.

Firestore permission denied:

- Confirm Authentication is enabled.
- Confirm the signed-in uid matches `userId`, `adminId`, or ownership fields.
- Review Firestore rules and indexes.

No parking areas appear:

- Run the demo seed script or create `/regions/region_sit_tumkur` and `/parking_areas` documents manually.
- Confirm parking areas are `isOpen: true` for user discovery.
- Confirm admin-owned areas use the signed-in admin uid.

Location does not update:

- Allow location permission in the device/browser.
- On web, run from `localhost` or HTTPS.
- Check Android/iOS permission files after regenerating platform folders.

Image upload fails:

- Confirm Firestore rules allow the admin to write `/parking_area_images`.
- Use smaller source images.
- Keep Firestore image mode enabled unless Storage billing/config is ready.

Admin Android build fails with Kotlin incremental cache root errors:

- On Windows, Kotlin incremental compilation can sometimes mix cache paths from the Pub cache drive/root and the project drive/root. The typical error mentions `Could not close incremental caches`, `this and base files have different roots`, `package_info_plus`, or `image_picker_android`.
- The admin app disables Kotlin incremental compilation in `apps/park_here_admin/android/gradle.properties`:

```properties
kotlin.incremental=false
kotlin.incremental.useClasspathSnapshot=false
```

- Clean the local build state from the project root:

```powershell
cd apps\park_here_admin\android
.\gradlew.bat --stop
cd ..\..\..
Remove-Item -Recurse -Force apps\park_here_admin\build -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force apps\park_here_admin\android\.gradle -ErrorAction SilentlyContinue
cd apps\park_here_admin
flutter clean
flutter pub get
flutter run -d <android-device-id>
```

- If the same root-mismatch error persists, clear the affected package folders from `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev` and run `flutter pub get` again. Do not downgrade packages first; treat this as a stale Kotlin/Pub cache problem unless a real compiler error remains after cleaning.

Firestore asks for an index:

- This usually appears as a `FAILED_PRECONDITION` error.
- If the message says the index is currently building, wait a few minutes and refresh the app.
- Review `docs/FIREBASE_SCHEMA.md` for the query-derived composite indexes and single-field queries that do not need composite entries.
- Prefer deploying the checked-in index config from the project root:

```bash
firebase login
firebase use park-here-dev
firebase deploy --only firestore:indexes
```

Flutter web builds but Edge fails to launch:

- This is usually an environment/browser launch issue, not app code.
- Check available Flutter devices:

```bash
flutter devices
```

- Try Chrome directly:

```bash
flutter run -d chrome
```

- Or run a web server without auto-launching a browser:

```bash
flutter run -d web-server
```

- Flutter will print a local URL such as `http://localhost:xxxxx`. Open that URL manually in Edge, Chrome, or another browser.
- If the browser still cannot load the app, confirm Firebase web config exists for the app you are running and that the local URL is allowed by Firebase Auth authorized domains when needed.
