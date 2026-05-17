# Park Here

Park Here is a Firebase-backed production-style MVP for parking occupancy with two Flutter apps:

- **Park Here**: driver app for finding, comparing, booking, and navigating to parking.
- **Park Here: Location Administrator**: owner app for registering parking locations, managing spaces, viewing bookings, and tracking income.

## Story

A driver should not need to circle the same road three times hoping for a space. A parking owner should not need a notebook to know whether the next vehicle can enter. Park Here connects those two moments: the driver gets a map-first booking flow, and the owner gets a clear operational dashboard.

## Features

Driver app:

- Firebase Auth profile
- Map-first nearby parking discovery
- Parking areas only, with available slots, price, ratings, images, and route comparison
- Dijkstra fallback route provider
- Duration-based booking
- QR ticket generation with active QR lifecycle data
- Reviews, comments, and issue reporting

Admin app:

- Firebase Auth owner profile
- SIT Tumkur region and parking area management
- Region and parking area boundary editing
- Availability, price, and open/closed controls
- Booking list and completion action
- Issues Received workflow
- Today income and future weekly/monthly analytics placeholder
- Firestore-first optimized image upload flow, with Firebase Storage left optional

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
/demo
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

The current build uses Firebase repositories at runtime. If Firebase configuration is missing, the apps show a setup error instead of loading in-app demo data.

To connect Firebase:

1. Create a Firebase project.
2. Enable Firebase Auth and Cloud Firestore.
3. Install FlutterFire CLI.
4. Run `flutterfire configure` in each app folder.
5. Confirm `firebase_core`, `firebase_auth`, `cloud_firestore`, and `geolocator` are resolved.
6. Seed Firestore with `demo/seed_firebase_demo.py` or create real data manually.
7. Use the schema in [FIREBASE_SCHEMA.md](FIREBASE_SCHEMA.md).

Default image mode is Firestore-only and stores compressed thumbnails/previews in `/parking_area_images`. Firebase Storage remains optional for teams that can use Blaze/pay-as-you-go.

## Maps Setup

The MVP uses live GPS for route origin and a local map-style canvas with route providers so it runs free and offline-friendly. For production maps, add a provider behind `RouteProvider`:

- Google Maps + Directions API
- OpenStreetMap tiles with OSRM/OpenRouteService
- Self-hosted OSRM/Valhalla for scale

## Screenshots

Screenshots should be added after running the apps on target devices:

- `docs/screenshots/user-home.png`
- `docs/screenshots/user-qr-ticket.png`
- `docs/screenshots/admin-dashboard.png`
- `docs/screenshots/admin-location-form.png`
