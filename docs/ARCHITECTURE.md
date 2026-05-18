# Architecture

Park Here uses a clean, feature-first monorepo with two Flutter apps and a shared Dart package for models, repositories, services, routing, image handling, QR payloads, and theme tokens.

Normal runtime is Firebase-backed. Local in-memory repositories remain only for tests and explicit dev overrides; they are not the production app data source.

```mermaid
flowchart LR
  UserApp["Park Here User App"] --> Shared["shared package"]
  AdminApp["Location Administrator App"] --> Shared
  UserApp --> FirebaseInit["Firebase.initializeApp"]
  AdminApp --> FirebaseInit
  Shared --> Contracts["Repository Interfaces"]
  Contracts --> FirebaseRepos["Firebase Repository Implementations"]
  Contracts -. tests only .-> LocalRepos["In-memory test repositories"]
  FirebaseRepos --> Firestore["Cloud Firestore"]
  FirebaseRepos --> Auth["Firebase Auth"]
  Shared --> Routing["RouteProvider + StraightLine/Dijkstra fallback"]
  Shared --> Images["ImageRepository + Firestore image mode"]
  Shared --> QR["QR Payload + Active Ticket Services"]
```

## User App Flow

```mermaid
flowchart TD
  Start["Open Park Here"] --> Init["Initialize Firebase"]
  Init --> Auth["Firebase Auth login/signup"]
  Auth --> Profile["Load or create /users/{uid}"]
  Profile --> GPS["Request GPS permission"]
  GPS --> Home["Map-first home"]
  Home --> Areas["Stream parking areas with live full/closed state"]
  Areas --> Details["Area details, thumbnails, reviews"]
  Details --> Route["Compare route options from GPS origin"]
  Route --> Book["Reserve slot with Firestore transaction"]
  Book --> QR["Create booking and active QR ticket"]
  QR --> Status["Stream active booking/QR status"]
  Status --> History["Booking history remains in /bookings"]
```

## User App Navigation

The user app now separates the mobility flow into five tabs instead of placing every feature on one screen:

```mermaid
flowchart LR
  Shell["UserHomeScreen shell"] --> Home["Home: map, search, filters, discovery sheet"]
  Shell --> Bookings["Bookings: active QR, cancellation, history"]
  Shell --> Explore["Explore: top rated, cheapest, free parking"]
  Shell --> Updates["Updates: QR, booking, Firebase/index messages"]
  Shell --> Profile["Profile: driver and vehicle settings"]
  Home --> Map["InteractiveParkingMap"]
  Home --> Search["PlaceSearchService"]
  Home --> Details["ParkingAreaDetailScreen"]
  Details --> Booking["Existing booking repository flow"]
```

The tabs reuse `UserAppController` and the existing Firebase repositories. The refactor is display/navigation separation only; Firebase remains the source of truth for parking areas, bookings, QR tickets, reviews, issues, and image records.

## Map And Search Flow

```mermaid
flowchart TD
  GPS["User GPS stream"] --> MapState["Map current-location marker"]
  Areas["parking_areas stream"] --> MapState
  Areas --> Polygons["Parking area polygons and markers"]
  Gates["gatePoints"] --> GateMarkers["Entry/exit gate markers"]
  SearchBox["Search bar"] --> SearchService["PlaceSearchService"]
  SearchService --> LocalPlaces["SIT Tumkur local place index"]
  SearchService --> AreaSearch["Loaded Firebase parking areas"]
  AreaSearch --> Focus["Focus map camera / select area"]
  LocalPlaces --> Focus
  Focus --> Routes["RouteProvider fallback route options"]
```

`PlaceSearchService` is an abstraction so Google Places, Nominatim, or another provider can be added later without putting API logic in widgets. Current runtime uses `LocalSitTumkurPlaceSearchService`, which is free/local-friendly and searches SIT Tumkur landmarks plus Firebase-loaded parking areas.

## Admin App Flow

```mermaid
flowchart TD
  Start["Open Admin App"] --> Init["Initialize Firebase"]
  Init --> Auth["Firebase Auth login/signup"]
  Auth --> Profile["Load or create /admins/{uid}"]
  Profile --> Region["Load SIT Tumkur region"]
  Region --> Areas["Stream admin parking areas"]
  Areas --> Editor["Edit boundary, gates, slots, price, images"]
  Profile --> Bookings["Stream admin bookings"]
  Profile --> Issues["Stream Issues Received"]
  Bookings --> Complete["Complete booking or consume QR"]
```

## Region To Parking Area Flow

SIT Tumkur is the current main region. Admins manage that region boundary, then publish bookable parking areas inside it. Users only see parking areas; the region is not a selectable parking object.

```mermaid
flowchart TD
  Region["/regions/region_sit_tumkur"] --> Boundary["Admin edits region polygon"]
  Boundary --> Area["Admin creates parking area polygon"]
  Area --> Gates["Admin marks entry/exit gates by GPS"]
  Gates --> Publish["Publish area with slots, price, vehicle types, images"]
  Publish --> UserMap["User map/list shows parking areas only"]
  UserMap --> Booking["User books area"]
  Booking --> ActiveQR["/active_qr_tickets/{qrId}"]
  Booking --> History["Permanent /bookings/{bookingId}"]
```

## Realtime Firebase Listener Flow

```mermaid
flowchart TD
  UserHome["User Home"] --> UserAreas["parking_areas: regionId + limit"]
  UserHome --> UserBookings["bookings: userId + limit"]
  UserBookings --> UserQR["active_qr_tickets: bookingId + active"]
  UserHome --> Reviews["reviews: areaId + limit"]
  AdminHome["Admin Dashboard"] --> AdminAreas["parking_areas: adminId + limit"]
  AdminHome --> AdminBookings["bookings: adminId + limit"]
  AdminHome --> AdminIssues["issue_reports: adminId + limit"]
  UserAreas --> Riverpod["Riverpod state"]
  AdminAreas --> Riverpod
  UserQR --> Riverpod
```

Bounded listeners are used only where live updates matter. Image payloads are lazy-loaded, not streamed as entire collections.

## Booking And QR Flow

```mermaid
sequenceDiagram
  participant User
  participant App as Park Here
  participant Firestore
  participant Gate as Future Gate/API

  User->>App: Selects area and duration
  App->>Firestore: Transaction decrements availableSpaces
  App->>Firestore: Creates /bookings/{bookingId}
  App->>Firestore: Creates /active_qr_tickets/{qrId}
  App-->>User: Shows QR payload
  Gate->>Firestore: Looks up active QR
  Firestore-->>Gate: Active ticket + booking
  Gate->>Firestore: Consumes QR once
  Firestore->>Firestore: Marks ticket used and booking completed
```

```mermaid
stateDiagram-v2
  [*] --> Active: booking created
  Active --> Used: consumeQrTicket
  Active --> Expired: expiresAt passes
  Used --> [*]
  Expired --> [*]
```

Booking history is never deleted. Active QR records are operational and may be marked `used` or expired.

Cancellation uses the booking repository transaction path. It marks the booking cancelled, records a `Rs. 10` fine only when the parking area's hourly price is above `Rs. 10`, expires the active QR, and releases the slot once.

## Admin GPS Marking Flow

```mermaid
flowchart TD
  Admin["Admin stands at real point"] --> Mode["Choose Corner or Gate"]
  Mode --> GPS["Read current GPS + accuracy"]
  GPS --> Draft["Add to draft boundaryPoints/gatePoints"]
  Draft --> Review["Map shows numbered corners and gate markers"]
  Review --> Save["Save Area Geometry"]
  Save --> Firestore["/parking_areas/{areaId}"]
```

Poor GPS accuracy is shown in the Admin app. The seeded SIT Tumkur coordinates are approximate and should be corrected using this flow before real operation.

## Firestore-Only Image Flow

Firebase Storage may require billing, so the default image path is Firestore-only and optimized.

```mermaid
flowchart LR
  Admin["Admin selects image"] --> Compress["Compress original"]
  Compress --> Thumb["Generate <=30KB thumbnail"]
  Compress --> Preview["Generate <=120KB preview"]
  Thumb --> ImageDoc["/parking_area_images"]
  Preview --> ImageDoc
  ImageDoc --> Refs["thumbnailRefs/imagePreviewRefs on area"]
  Refs --> UserList["User list lazy thumbnail"]
  Refs --> Details["Details carousel lazy previews"]
  Details --> Cache["ImagePayloadCache"]
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

Default runtime uses `FirestoreImageRepository`. `FirebaseStorageImageRepository` is a future optional swap behind the same interface.

## Issue Report Flow

```mermaid
flowchart LR
  User["User opens area details"] --> Report["Submit issue"]
  Report --> Firestore["/issue_reports with adminId + areaId"]
  Firestore --> Admin["Issues Received"]
  Admin --> Status["open / in_progress / resolved / rejected"]
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
