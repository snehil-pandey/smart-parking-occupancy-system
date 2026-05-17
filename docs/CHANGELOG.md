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
