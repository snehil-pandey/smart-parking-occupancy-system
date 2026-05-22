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

### chore(firebase): generate Firestore indexes from app queries
- Regenerated `firestore.indexes.json` from the actual Firebase repository query shapes.
- Added root Firebase config/rules files created by Firebase init so index deployment works from the repository root.
- Documented query-derived indexes, project-root deployment, and index build timing.

### fix(firebase): handle Firestore index build errors gracefully
- Converted realtime stream index-build failures into visible user/admin state errors instead of unhandled stream exceptions.
- Added refresh affordances so signed-in sessions can retry after Firestore finishes building composite indexes.
- Documented the index build delay and retry behavior.

### feat(user-ui): restructure user app navigation
- Split the user app into Home, Bookings, Explore, Updates, and Profile tabs while keeping the existing Firebase-backed controller and repositories.
- Added a dedicated parking area detail screen for images, pricing, availability, route options, reviews, reports, and booking.

### feat(search): add realtime place and parking search
- Added `PlaceSearchService` with a local SIT Tumkur search provider.
- Search now combines SIT landmarks, current-location intent, and Firebase-loaded parking areas.

### feat(map): improve interactive parking map experience
- Replaced the static map feel with pan/zoom map interactions, current-location marker, parking polygons, gate markers, route polylines, and animated focus to selected places.

### perf(user): optimize user discovery flow
- Added debounced search, lazy image usage in cards/details, tab separation, and filtered views to reduce all-in-one screen rebuild pressure.

### feat(map): replace placeholder map with OpenStreetMap layers
- Swapped the user Home map surface to `flutter_map` OpenStreetMap tiles.
- Parking area polygons, gate markers, current GPS, route polylines, and selected-area focus now render as overlays on real map tiles.

### feat(explore): show nearby available parking areas
- Explore now prioritizes bookable nearby parking sorted by live GPS distance.
- Added recently used, free, cheapest, and top-rated sections from realtime Firebase state.

### feat(qr): use opaque QR identifiers only
- New QR payload generation renders only `qr_live_...` ids and keeps full booking/user/area mapping in Firestore.
- Legacy JSON QR parsing remains migration-safe.

### feat(bookings): add enlarged QR ticket viewer
- Active booking QR cards now open a scanner-friendly full-screen QR viewer with countdown and best-effort screen brightness boost.

### feat(notifications): add QR expiry alerts
- Added notification model/repository, user Updates feed, booking confirmed/cancelled notifications, and QR expiry alerts.
- Local notifications are scheduled best-effort at 10 minutes, 2 minutes, and expiry where platform support allows.

### perf(cache): add Firebase-first client caching strategy
- Enabled Firestore offline persistence in the user app and documented Riverpod session cache, image payload cache, lazy image reads, and why Redis is not used in a Flutter-only Firebase app.

### chore(app): apply launcher icons and display names
- Added separate user/admin launcher icon assets and `flutter_launcher_icons` config.
- Generated Android, iOS, and web launcher icons for both apps.
- Updated Android labels, iOS display names, web manifests, page titles, and local setup icon regeneration notes.

### fix(android): enable desugaring for local notifications
- Enabled Android core library desugaring in the user app for `flutter_local_notifications`.
- Added the `desugar_jdk_libs` dependency and aligned Android/Kotlin JVM targets to Java 8 for the affected app.

### fix(user): improve realtime map updates filters and booking confirmation
- Replaced Home full reload actions with bounded realtime listener retry so map/search/filter state is preserved.
- Made quick filters toggle back to the unfiltered view when the active chip is tapped again.
- Added booking in-progress protection and a confirmation bottom sheet with ticket details after successful booking.

### fix(routing): replace straight-line paths with road-aware routing
- Added OSRM road-network routing with GeoJSON route parsing, alternative route support, in-memory route caching, and SIT Tumkur road-graph fallback.
- Updated user route selection to target nearest valid parking gates instead of parking area centers.
- Updated map route rendering to highlight selected road geometry and fit the camera to the active route.

### fix(android): stabilize Kotlin build cache on Windows
- Disabled Kotlin incremental compilation for the admin Android app to avoid Windows cross-root incremental cache failures involving Pub cache plugins.
- Documented the Gradle daemon stop, build folder cleanup, `flutter clean`, and `flutter pub get` recovery flow.

### refactor(admin-ui): separate admin app into focused sections
- Split the admin screen internals into feature sections for auth, dashboard, region, parking areas, bookings, issues, and shared widgets while preserving the existing Firebase-backed controller.

### feat(admin-ui): add responsive admin navigation shell
- Added a mobile bottom navigation and tablet/web navigation rail for Dashboard, Region, Areas, Bookings, Issues, and Profile.
- Dashboard now shows focused operational summaries and quick actions; bookings and issues are separated into their own workflows.

### feat(admin-theme): apply Namma Yatri inspired admin styling
- Updated admin theme tokens toward warm yellow, black text, off-white surfaces, rounded cards, simple chips, and operational button styling.

### docs(admin): document admin app navigation structure
- Documented the admin navigation shell, feature sections, responsive layout, visual direction, and current admin geometry preview limitation.

### feat(admin-ui): add issues filters to admin section
- Added area and status filters to the dedicated Issues section so administrators can triage received reports without leaving the focused tab.

### docs: add root README pointer
- Added a root `README.md` that points to the canonical documentation under `docs/README.md`.

### fix(admin-ui): repair layouts and add proper map geometry editing
- Fixed narrow-screen dashboard stat card overflow and made parking area controls more responsive.
- Added admin geometry modes for corner and gate editing, including select-on-map point creation, tap-to-select/tap-to-move adjustment, delete selected point, undo, clear, and Firebase save state.
- Added gate list editing for name/type updates and gate removal.
- Removed the hardcoded default polygon from runtime parking area creation so new areas start empty and must be marked by the admin or seeded through Firebase.
- Added controller validation for area spaces, price range, SIT Tumkur region ownership, and minimum polygon corners before saving geometry.

### feat(admin-region): add controlled region setup and OSM map editing
- Added per-admin controlled region loading from Firestore and mandatory Region Setup for admins without a region.
- Added shared geometry utilities for point-in-polygon, polygon containment, gate containment, polygon centers, and bounds.
- Replaced active admin geometry editing surfaces with real OpenStreetMap tile maps for region and parking area polygons.
- Added Add/Move point modes for region corners and Add/Move corner/gate modes for parking areas using select-point then tap-to-move behavior.
- Enforced that parking area corners, centers, and gates stay inside the signed-in admin's controlled region.
- Added admin area detail editing and updated tests for controlled-region setup and outside-region rejection.

### chore(firebase): align Firestore indexes with app queries
- Audited Firebase repository query patterns against `firestore.indexes.json`.
- Confirmed current composite indexes match app query shapes for parking areas, bookings, QR tickets, issues, reviews, Firestore images, and notifications.
- Documented single-field/direct-document queries, including admin-controlled region lookups, so they are not mistaken for missing composite indexes.
- Added the exact project-root index deployment command using `firebase use park-here-dev` and `firebase deploy --only firestore:indexes`.

### feat(admin): prevent parking area polygon conflicts
- Added shared polygon intersection, containment, boundary-touch, and conflict validation utilities for parking areas.
- Added repository-level parking area conflict checks before Firestore upserts so UI bypasses cannot save overlapping geometry.
- Updated the Admin area editor to render existing same-region parking areas, show other admins' areas as muted name-only reference zones, highlight conflicting zones, and disable Save while a conflict exists.
- Added optional parking area bounds fields (`minLat`, `maxLat`, `minLng`, `maxLng`) for faster conflict pre-checks and future spatial filtering.

### fix(demo): reset and seed Firebase data consistently
- Expanded the demo reset script to clear all supported Park Here demo collections, support `--dry-run`, and optionally delete only Auth users ending with `@parkhere.demo`.
- Updated the seed script to recreate Auth users, matching Firestore profiles, SIT Tumkur region/areas, bounds fields, bookings, opaque active QR tickets, reviews, issues, notifications, payment, and lightweight metrics documents.
- Documented that Firestore indexes are managed through `firestore.indexes.json` and Firebase CLI deployment, not through the Admin SDK reset/seed scripts.

### fix(firebase): reset demo auth data and stabilize indexes
- Made demo Auth user deletion part of the reset flow while still skipping real/non-demo users by default.
- Added dangerous full-reset flags for disposable Firebase projects with explicit confirmation phrases for all Auth users and all Firestore collections.
- Simplified user-facing parking, booking, and notification queries to sort small result sets in memory instead of requiring startup composite indexes.
- Trimmed `firestore.indexes.json` to only the composite indexes still required by app queries and updated index deployment docs.

### fix(admin): show existing zones and prevent region conflicts
- Added realtime global region and parking-area reference streams for admin map editors, showing only public zone names and polygons.
- Prevented new/edited regions from overlapping, touching, containing, or being contained by existing regions before Firestore writes.
- Expanded parking-area conflict checks to all existing Firebase parking areas, not only areas in the current admin region.
- Simplified admin area, booking, and issue streams to single-field Firestore filters with local sorting and trimmed obsolete composite indexes.

### fix(admin-auth): stabilize onboarding and session restore
- Persisted admin `regionId` and `onboardingCompleted` on profile records after controlled-region setup.
- Restored cached admin sessions through Firebase Auth, admin profile, and assigned region before showing dashboard or setup screens.
- Added a legacy repair path so existing admins with region documents are marked onboarded instead of being sent through setup again.
- Added a branded admin restore loading state to avoid login or region-setup flicker during startup.
