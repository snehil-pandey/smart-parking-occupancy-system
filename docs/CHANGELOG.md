# Changelog

## 0.1.0

### chore: initialize monorepo structure
- Created Flutter app shells for Park Here user and location administrator apps.
- Added shared package, documentation folder, scripts folder, root analysis options, and environment example.

### docs: add project research and architecture plan
- Added research notes covering the parking occupancy problem, two-app split, Firebase choice, map-first UI, routing options, and MVP limitations.
- Added architecture diagrams for app flow, backend flow, and QR verification.

### feat(shared): add shared models and routing abstractions
- Added typed models for users, admins, parking locations, bookings, and payments.
- Added repository interfaces with local in-memory implementations.
- Added route provider contract, Dijkstra fallback engine, QR payload service, demo seed data, and shared themes.

### feat(user): build Park Here user app MVP
- Replaced the starter app with a Riverpod-driven map-first parking discovery flow.
- Added local profile editing, nearby parking suggestions, Dijkstra route comparison, duration selection, booking creation, and in-app QR ticket rendering.

### feat(admin): build location administrator MVP
- Replaced the starter app with a Riverpod dashboard for parking owners.
- Added owner profile editing, parking location registration, availability/price controls, booking list, booking completion, and income placeholders.

### feat(firebase): add Firebase repositories and schema docs
- Added Firebase collection path constants and repository placeholders behind existing interfaces.
- Documented the Firestore collections, fields, and security direction.

### feat(qr): add booking QR generation flow
- Added QR payload parsing support to the shared service.
- Documented the future hardware/API verification flow and production signing direction.

### docs: add setup, changelog, and future scope
- Expanded README with story, features, run commands, Firebase setup, maps setup, and screenshot placeholders.
- Added routing engine, local setup, future scope docs, and a Firestore-shaped demo seed script.

### test: validate local build and fix issues
- Resolved Riverpod ProviderScope usage in widget tests.
- Fixed admin stats card responsiveness found during widget testing.
- Validated dependency resolution, analysis, widget tests, and web builds for both apps.

### docs: add Firebase local setup guide
- Expanded local setup documentation with Firebase project creation, CLI installation, FlutterFire configuration, platform file locations, product enablement, security notes, and troubleshooting.

### feat(images): add Firestore-first hybrid image architecture
- Added Firestore-first image model, repository abstraction, local image repository, optimizer, and cache.
- Updated admin and user image flows to use optimized thumbnail/preview payloads instead of raw URLs.
- Documented Firebase Storage as an optional future repository rather than a required dependency.

### feat(schema): add region and parking area models
- Added SIT Tumkur region, parking area boundary, review, issue report, and active QR ticket models.
- Extended parking and booking models with region/area aliases, ratings, QR ids, and QR use timestamps.

### feat(admin): add region and parking area management
- Added Region Management, Parking Areas, Area Boundary Editor, Issues Received, and image management flows for SIT Tumkur.
- Preserved existing admin dashboard, availability, booking, and income flows.

### feat(user): show parking areas with ratings and reporting
- Updated the user app to show parking areas only, with ratings, recent comments, optimized images, and report/rate actions.
- Added issue reporting and review submission through shared repositories.

### feat(qr): add active QR ticket lifecycle
- Added active QR ticket creation, lookup, consumption, and consume-once test coverage.
- QR payloads now include `qrId`; consuming a QR preserves booking history and marks the active ticket inactive.

### feat(firebase): optimize realtime listeners and transactions
- Added bounded booking/QR stream contracts for realtime screens.
- Added atomic local slot reservation API mirroring the future Firestore transaction path.

### feat(demo): add Firebase demo seed script for SIT Tumkur
- Added `/demo` with Firebase Admin SDK seed script, requirements, `.env.example`, and setup guide.
- Seed includes SIT Tumkur region, demo admin/users, parking areas, images, reviews, issues, booking, and active QR ticket.

### docs: update architecture, setup, schema, and QR docs
- Documented region-to-area flow, active QR lifecycle, realtime listener strategy, issue reports, indexes, and Firebase demo setup.

### feat(firebase): implement Firestore repositories
- Replaced placeholder Firestore repository bodies for regions, parking areas, bookings, reviews, issues, and Firestore image mode.
- Added Firestore timestamp/string mapper support so repositories can read both app-written and Admin SDK seeded demo documents.
- Added tests for Firestore date mapping and ignored generated Flutter plugin metadata.

### docs: refresh Firebase repository setup notes
- Updated README, architecture, and local setup docs at that milestone to reflect that Firestore repositories existed while local mode was still the default.

### fix(firebase): wire runtime apps to Firebase repositories
- Initialized Firebase in both apps and switched runtime providers to Firebase Auth, Firestore repositories, and Firestore image mode.
- Added setup error handling when Firebase config is missing instead of falling back to fake app data.

### feat(auth): add Firebase login and profile loading
- Added Firebase Auth email/password signup and login for user and admin apps.
- Runtime sessions now load `/users/{uid}` and `/admins/{uid}` profiles and create role-specific profiles when needed.

### feat(location): add realtime GPS based parking discovery
- Added user GPS permission handling and live location updates for nearby distance and route origin.
- Added clear SIT Tumkur fallback messaging when location permission or service access is unavailable.

### refactor(demo): isolate demo data from app runtime
- Removed runtime app dependencies on `DemoSeed` and in-memory repositories.
- Added a straight-line route provider for Firebase runtime fallback routing.
- Reworked admin image upload/replace flows to use selected image bytes and Firestore image records.

### docs(firebase): update setup and runtime data flow
- Updated setup, architecture, and schema docs for Firebase-only runtime data, Auth profiles, GPS permissions, Firestore image mode, and demo seeding.

### fix(demo): replace random seed data with SIT Tumkur parking areas
- Replaced loose demo coordinates with fixed SIT Tumkur-focused region, parking areas, capacities, prices, reviews, issues, booking, and QR records.
- Added coordinate notes explaining that internal campus boundaries are approximate and must be corrected physically.

### feat(admin): add GPS based corner and gate marking
- Added parking gate point model support and Firestore mapping.
- Added Admin app GPS controls for marking current position as area corners or named entry/exit gates, with undo, clear, accuracy status, and save.

### feat(user): disable booking for full parking areas
- User app now shows full/closed parking areas in disabled grey states, keeps details viewable, and disables booking actions.
- Free parking now renders as `Free`.

### feat(booking): add cancellation fine and slot release flow
- Added cancellation metadata to bookings.
- Cancelling an active booking records a Rs. 10 fine only when hourly price is above Rs. 10, expires the active QR, and releases the slot once.

### feat(pricing): enforce parking price range
- Added shared and repository-level validation for parking hourly price range Rs. 0 to Rs. 100.

### docs(demo): document SIT Tumkur coordinate verification
- Updated demo setup, Firebase schema, local setup, and architecture docs for gate points, cancellation, price limits, GPS marking, and SIT coordinate caveats.

### docs(setup): add Flutter web browser launch troubleshooting
- Added Edge/browser launch troubleshooting with `flutter devices`, `flutter run -d chrome`, and `flutter run -d web-server` guidance.

### feat(auth): add email-based demo users and admin
- Added deterministic demo emails, `authUid`, and display names to seeded Firestore user/admin profiles.

### feat(demo): seed Firebase Auth accounts safely
- Demo seed now creates or reuses Firebase Auth Email/Password users through Firebase Admin SDK and maps Firestore profiles to the actual Auth UID.

### docs(auth): add demo login credential setup
- Documented demo credentials, Auth seeding behavior, password reset behavior, and Email/Password provider requirements.

### feat(demo): add Firebase demo reset script
- Added `demo/reset_firebase_demo.py` to delete Park Here demo Firestore collections safely, with optional `@parkhere.demo` Auth user deletion.

### fix(firebase): align seeded profiles with app auth schema
- Added canonical vehicle type checks to the demo seed and kept Firebase Auth UID as the user/admin profile document id.

### fix(models): make vehicle type parsing backward compatible
- Added safe vehicle type parsing for legacy `twoWheeler`, `fourWheeler`, `motorcycle`, and `scooter` values with fallback instead of crashing.

### docs(firebase): document reset and clean seed workflow
- Documented reset/reseed commands, canonical vehicle enum values, and Firebase Auth UID profile mapping.

### docs(firebase): add Firestore composite index deployment guide
- Added root `firestore.indexes.json` with composite indexes for bookings, parking areas, issues, reviews, and active QR tickets.
- Documented `firebase deploy --only firestore:indexes` workflow and the Firestore `FAILED_PRECONDITION` missing-index error.
