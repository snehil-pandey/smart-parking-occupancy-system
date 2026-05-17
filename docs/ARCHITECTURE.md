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
  Dashboard --> Register["Register parking area"]
  Dashboard --> Availability["Manage availability and price"]
  Dashboard --> Bookings["View active/recent bookings"]
  Bookings --> Complete["Mark booking completed"]
```

## Region To Parking Area Flow

SIT Tumkur is the current demo region. Admins manage that boundary and then publish bookable parking areas inside it. Users only see parking areas, never the region as a selectable parking object.

```mermaid
flowchart TD
  Region["Region: SIT Tumkur"] --> Boundary["Admin edits region polygon"]
  Boundary --> Area["Admin draws parking area boundary"]
  Area --> Publish["Publish area with slots, price, images"]
  Publish --> UserMap["User map/list shows parking areas only"]
  UserMap --> Booking["User books area"]
  Booking --> QR["Active QR ticket"]
  Booking --> History["Permanent booking history"]
```

## Issue Report Flow

```mermaid
flowchart LR
  User["User opens area details"] --> Report["Report issue"]
  Report --> Firestore["/issue_reports filtered by adminId"]
  Firestore --> Admin["Issues Received screen"]
  Admin --> Status["open / in_progress / resolved / rejected"]
  Status --> UserContext["Future user/admin notifications"]
```

## Firebase Backend Flow

```mermaid
flowchart LR
  Auth["Firebase Auth"] --> Profiles["/users and /admins"]
  Profiles --> Regions["/regions"]
  Regions --> Areas["/parking_areas"]
  Areas --> Images["/parking_area_images"]
  Areas --> Reviews["/reviews"]
  Areas --> Issues["/issue_reports"]
  Areas --> Bookings["/bookings"]
  Bookings --> ActiveQR["/active_qr_tickets"]
  Bookings --> Payments["/payments"]
  Storage["Optional Firebase Storage"] -. future .-> Images
  Bookings --> AdminDash["Admin dashboard aggregates"]
  Bookings --> UserHistory["User history"]
```

## Realtime Listener Flow

```mermaid
flowchart TD
  UserHome["User map home"] --> AreaQuery["parking_areas by regionId + isOpen, limited"]
  UserHome --> ActiveBooking["bookings by userId + active"]
  ActiveBooking --> ActiveQR["active_qr_tickets by bookingId"]
  AdminDash["Admin dashboard"] --> AdminAreas["parking_areas by adminId/regionId"]
  AdminDash --> AdminBookings["bookings by adminId/status"]
  AdminDash --> AdminIssues["issue_reports by adminId/status"]
  AreaQuery --> Cache["Local Riverpod/ImagePayloadCache state"]
  AdminAreas --> Cache
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
- Store image payloads in `/parking_area_images`, not in `/parking_areas`.
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

Active QR tickets are short-lived records. Booking history is permanent.

```mermaid
stateDiagram-v2
  [*] --> Active: booking created
  Active --> Used: gate verifies or admin completes
  Active --> Expired: time window passes
  Used --> [*]
  Expired --> [*]
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
/demo
```
