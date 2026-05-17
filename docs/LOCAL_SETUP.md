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

After Firebase config is generated, replace the Riverpod providers:

```dart
final parkingRepositoryProvider = Provider<ParkingRepository>(
  (ref) => FirebaseParkingRepository(),
);
```

Then implement the Firebase repository methods with `FirebaseFirestore.instance`.

