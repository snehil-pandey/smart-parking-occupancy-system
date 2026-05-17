# Park Here

Park Here is a local-first production-style MVP for parking occupancy with two Flutter apps:

- **Park Here**: driver app for finding, comparing, booking, and navigating to parking.
- **Park Here: Location Administrator**: owner app for registering parking locations, managing spaces, viewing bookings, and tracking income.

## Story

A driver should not need to circle the same road three times hoping for a space. A parking owner should not need a notebook to know whether the next vehicle can enter. Park Here connects those two moments: the driver gets a map-first booking flow, and the owner gets a clear operational dashboard.

## Features

Driver app:

- Local/Firebase-ready auth profile
- Map-first nearby parking discovery
- Available slots, price, vehicle support, and route comparison
- Dijkstra fallback route provider
- Duration-based booking
- QR ticket generation
- Active booking and history-ready model

Admin app:

- Local/Firebase-ready owner profile
- Parking location registration
- Availability, price, and open/closed controls
- Booking list and completion action
- Today income and future weekly/monthly analytics placeholder
- Image URL support ready for Firebase Storage

## Project Structure

```text
/apps
  /park_here_user
  /park_here_admin
/shared
  /lib/models
  /lib/services
  /lib/repositories
  /lib/routing
  /lib/utils
  /lib/theme
/docs
/scripts
```

## Run User App

```bash
cd apps/park_here_user
flutter pub get
flutter run -d chrome
```

Use another device id for Android/iOS:

```bash
flutter devices
flutter run -d <device-id>
```

## Run Admin App

```bash
cd apps/park_here_admin
flutter pub get
flutter run -d chrome
```

## Firebase Setup

The current build runs locally without Firebase config. To connect Firebase:

1. Create a Firebase project.
2. Enable Firebase Auth, Cloud Firestore, and Firebase Storage.
3. Install FlutterFire CLI.
4. Run `flutterfire configure` in each app folder.
5. Add `firebase_core`, `firebase_auth`, `cloud_firestore`, and `firebase_storage`.
6. Replace local repository providers with Firebase repository implementations.
7. Use the schema in [FIREBASE_SCHEMA.md](FIREBASE_SCHEMA.md).

## Maps Setup

The MVP uses a local map-style canvas and Dijkstra route provider so it runs free and offline-friendly. For production maps, add a provider behind `RouteProvider`:

- Google Maps + Directions API
- OpenStreetMap tiles with OSRM/OpenRouteService
- Self-hosted OSRM/Valhalla for scale

## Screenshots

Screenshots should be added after running the apps on target devices:

- `docs/screenshots/user-home.png`
- `docs/screenshots/user-qr-ticket.png`
- `docs/screenshots/admin-dashboard.png`
- `docs/screenshots/admin-location-form.png`

