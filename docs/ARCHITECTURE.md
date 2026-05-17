# Architecture

Park Here uses a clean, feature-first shape with a shared Dart package for domain models, repository contracts, fallback services, routing, QR payload generation, and theme tokens.

```mermaid
flowchart LR
  UserApp["Park Here User App"] --> Shared["shared package"]
  AdminApp["Location Administrator App"] --> Shared
  Shared --> Repos["Repository Interfaces"]
  Repos --> Local["Local Demo Repositories"]
  Repos -. future .-> Firebase["Firebase Auth / Firestore / Storage"]
  Shared --> Routing["RouteProvider + Dijkstra Engine"]
  Shared --> QR["QR Payload Service"]
  Shared --> Images["ImageRepository + ImageOptimizer"]
```

## User App Flow

```mermaid
flowchart TD
  Start["Open Park Here"] --> Auth["Local/Firebase-ready auth"]
  Auth --> Home["Map-first home"]
  Home --> Discover["Nearby parking suggestions"]
  Discover --> Details["Location details"]
  Details --> Route["Compare shortest and alternate routes"]
  Route --> Book["Select duration and book"]
  Book --> Ticket["QR ticket + active booking"]
  Ticket --> History["Booking history"]
```

## Admin App Flow

```mermaid
flowchart TD
  Start["Open Admin App"] --> Auth["Owner sign in"]
  Auth --> Dashboard["Stats dashboard"]
  Dashboard --> Register["Register parking location"]
  Dashboard --> Availability["Manage availability and price"]
  Dashboard --> Bookings["View active/recent bookings"]
  Bookings --> Complete["Mark booking completed"]
```

## Firebase Backend Flow

```mermaid
flowchart LR
  Auth["Firebase Auth"] --> Profiles["/users and /admins"]
  Profiles --> Locations["/parking_locations"]
  Locations --> Bookings["/bookings"]
  Bookings --> Payments["/payments"]
  Storage["Firebase Storage"] --> Locations
  Bookings --> AdminDash["Admin dashboard aggregates"]
  Bookings --> UserHistory["User history"]
```

## Hybrid Image Flow

Firebase Storage can require a pay-as-you-go billing setup, so Park Here does not make Storage mandatory. The default image path stores only compressed, Firestore-safe image payloads in a separate collection. Parking area documents keep lightweight references, not large base64 blobs.

```mermaid
flowchart LR
  Admin["Admin Upload"] --> Compress["Compression"]
  Compress --> Thumb["Thumbnail Generation"]
  Thumb --> Images["Firestore Image Collection"]
  Images --> Lazy["Lazy User Fetch"]
  Lazy --> Cache["Local Image Cache"]
```

The repository boundary stays extensible:

```mermaid
classDiagram
  class ImageRepository {
    getThumbnailsForArea()
    getPreviewsForArea()
    uploadOptimizedAreaImage()
    replaceImage()
    removeImage()
  }
  class FirestoreImageRepository
  class FirebaseStorageImageRepository
  class InMemoryImageRepository
  ImageRepository <|.. FirestoreImageRepository
  ImageRepository <|.. FirebaseStorageImageRepository
  ImageRepository <|.. InMemoryImageRepository
```

Default mode:

- `InMemoryImageRepository` locally
- `FirestoreImageRepository` when Firebase is enabled
- `FirebaseStorageImageRepository` only when Storage billing/config is acceptable

Image performance rules:

- Generate thumbnail and preview versions before upload.
- Store image payloads in `/parking_area_images`, not in `/parking_locations`.
- Keep thumbnails under 30KB and previews under 120KB.
- Load one thumbnail per parking area in list views.
- Lazy-load preview images only when the user opens area details.
- Cache fetched image records locally.
- Use query limits and pagination for large image sets.

## QR Verification Flow

```mermaid
sequenceDiagram
  participant User
  participant App as Park Here App
  participant Firestore
  participant Gate as Future Gate Scanner

  User->>App: Books parking slot
  App->>Firestore: Creates booking with qrPayload
  App->>User: Shows QR ticket
  Gate->>Firestore: Looks up bookingId from QR
  Firestore-->>Gate: Booking status and expected fields
  Gate->>Gate: Validates checksum/signature and time window
  Gate-->>User: Allows entry or rejects
```

## Folder Strategy

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
