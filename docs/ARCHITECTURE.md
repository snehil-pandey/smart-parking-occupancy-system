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
  UserApp --> OSM["flutter_map + OpenStreetMap tiles"]
  Shared --> Routing["RoutingService + OSRM + SIT road-graph fallback"]
  Shared --> Images["ImageRepository + Firestore image mode"]
  Shared --> QR["QR Payload + Active Ticket Services"]
  Shared --> Notifications["NotificationRepository"]
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
  Shell --> Explore["Explore: nearby available, recently used, free, cheapest, top rated"]
  Shell --> Updates["Updates: QR expiry, booking, issue, Firebase/index messages"]
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
  OSM["OpenStreetMap tile layer"] --> MapState["flutter_map camera"]
  GPS["User GPS stream"] --> MapState["Map current-location marker"]
  Areas["parking_areas stream"] --> MapState
  Areas --> Polygons["Parking area polygon layer and markers"]
  Gates["gatePoints"] --> GateMarkers["Entry/exit gate markers"]
  SearchBox["Search bar"] --> SearchService["PlaceSearchService"]
  SearchService --> LocalPlaces["SIT Tumkur local place index"]
  SearchService --> AreaSearch["Loaded Firebase parking areas"]
  AreaSearch --> Focus["Focus map camera / select area"]
  LocalPlaces --> Focus
  Focus --> GateRouting["Nearest valid parking gate"]
  GateRouting --> Routes["OSRM RoutingService road route options"]
  Routes --> Cache["RouteCache"]
  Routes --> Fallback["SIT road-graph fallback"]
```

The user map uses `flutter_map` with public OpenStreetMap tiles for local development, then overlays Firebase parking polygons, gate markers, current GPS, and route polylines. OpenStreetMap does not require Google Maps billing or an API key, but production traffic should use an OSM-compliant tile provider or self-hosted tiles.

Routes now come from `OsrmRouteProvider` first, not straight-line geometry. The provider requests OSRM road-network routes with full GeoJSON geometry, caches recent responses in memory, and falls back to a small SIT Tumkur weighted road graph only when the road-routing API is unavailable. `ParkingGateSelector` routes to the nearest valid entry/both gate before falling back to a parking area center.

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

## Admin App Navigation

The admin app is now separated into focused operational sections instead of one dense dashboard. The shell uses bottom navigation on mobile and a `NavigationRail` on tablet/web widths. Section selection lives in `AdminAppState.section`, so Firestore stream updates do not reset the selected tab.

```mermaid
flowchart LR
  Shell["AdminNavigationShell"] --> Dashboard["Dashboard: income, bookings, slots, issues, quick actions"]
  Shell --> Region["Region: SIT Tumkur metadata and boundary preview"]
  Shell --> Areas["Parking Areas: list, availability, geometry, images"]
  Shell --> Bookings["Bookings: active, completed, cancelled"]
  Shell --> Issues["Issues: filters and status updates"]
  Shell --> Profile["Profile / Settings: business info, Firebase status, logout"]
  Dashboard --> Controller["AdminAppController"]
  Areas --> Controller
  Bookings --> Controller
  Issues --> Controller
  Controller --> Firebase["Firebase Auth + Firestore streams"]
```

Visual direction is practical and Namma-Yatri-inspired: warm yellow accents, black text, off-white app background, green for available/open states, grey for inactive/closed states, and simple cards/chips. The admin app remains operational rather than decorative.

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
  UserHome --> Notifications["notifications: userId + limit"]
  AdminHome["Admin Dashboard"] --> AdminAreas["parking_areas: adminId + limit"]
  AdminHome --> AdminBookings["bookings: adminId + limit"]
  AdminHome --> AdminIssues["issue_reports: adminId + limit"]
  UserAreas --> Riverpod["Riverpod state"]
  AdminAreas --> Riverpod
  UserQR --> Riverpod
  Notifications --> Riverpod
```

Bounded listeners are used only where live updates matter. Image payloads are lazy-loaded, not streamed as entire collections.

The user Home screen treats Firestore streams as the live data path after login. Parking area snapshots replace only the lightweight area list, keep the selected area by id when it still exists, and preserve search text, filter chips, current tab, and bottom-sheet context. The retry control restarts bounded listeners without calling the global app load path, so an index/network retry does not wipe the map or navigation state.

Booking creation updates Firestore first, then writes an optimistic local booking/active QR state for immediate confirmation. The regular bookings, active QR, and parking area listeners remain the source of truth and reconcile the UI as soon as Firestore emits the next snapshots.

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
  App->>Firestore: Creates /active_qr_tickets/{opaqueQrId}
  App-->>User: Shows QR with opaque id only
  Gate->>Firestore: Looks up active QR by opaque id
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

QR codes are privacy-preserving: rendered QR data is only `qr_live_...`. User id, vehicle number, booking id, admin id, and area id are looked up through Firebase by the future gate/API, not exposed inside the QR image.

## Notification Flow

```mermaid
flowchart TD
  ActiveQR["Active QR stream"] --> Countdown["In-app countdown"]
  ActiveQR --> Local["Best-effort local notifications"]
  ActiveQR --> FirestoreNotif["/notifications/{notificationId}"]
  FirestoreNotif --> UpdatesTab["User Updates tab"]
  BookingCancel["Booking cancelled/completed"] --> CancelLocal["Cancel scheduled local alerts"]
```

The app schedules QR expiry alerts at 10 minutes, 2 minutes, and expiry where platform APIs allow it. Web may ignore local notifications or screen brightness changes, so the Updates tab and QR countdown remain the reliable in-app path.

## Client Cache Strategy

Park Here is Flutter + Firebase only, so Redis is not embedded in the app. Client-side caching is used instead:

- Firestore offline persistence for user runtime reads where the platform supports it.
- Riverpod `UserAppState` as the current session cache for parking areas, bookings, QR, reviews, and notifications.
- `ImagePayloadCache` for optimized Firestore image payloads.
- Last known GPS position from `GeolocatorUserLocationService` while the app session is alive.
- Lazy thumbnail/preview fetching instead of streaming image blobs.

Redis would only make sense later behind a FastAPI/Node/Cloud Run backend that aggregates high-volume analytics or external routing/search results.

Cancellation uses the booking repository transaction path. It marks the booking cancelled, records a `Rs. 10` fine only when the parking area's hourly price is above `Rs. 10`, expires the active QR, and releases the slot once.

## Admin GPS Marking Flow

```mermaid
flowchart TD
  Admin["Admin opens Parking Areas"] --> Mode["Choose Corner or Gate mode"]
  Mode --> Tap["Select On Map: tap preview to add point"]
  Mode --> GPS["GPS: stand at point and mark current position"]
  Tap --> Draft["Update draft boundaryPoints/gatePoints immediately"]
  GPS --> Draft
  Draft --> Select["Tap corner/gate pin to select"]
  Select --> Move["Tap another map position to move selected point"]
  Select --> EditGate["Edit gate name/type or delete point"]
  Move --> Review["Preview numbered corners and distinct gate markers"]
  EditGate --> Review
  Review --> Save["Save Area Geometry"]
  Save --> Firestore["/parking_areas/{areaId}"]
```

Poor GPS accuracy is shown in the Admin app. The seeded SIT Tumkur coordinates are approximate and should be corrected using this flow before real operation.

The admin geometry surface is currently a lightweight preview of saved polygons, numbered corner points, and gate points. It is not wired to the real `flutter_map` OpenStreetMap tile stack yet. The user app uses real OSM tiles; admin can safely keep editing Firebase geometry through GPS controls and select-on-map mode until an OSM editor is added.

Because the admin preview does not use draggable map markers yet, point adjustment uses an explicit fallback interaction: tap an existing corner or gate to select it, then tap the desired position to move it. This is intentionally documented as tap-to-select/tap-to-move rather than true dragging.

Before saving geometry, the controller validates that the selected area belongs to `region_sit_tumkur`, has at least three polygon corners, uses a price within `0..100`, and has `availableSpaces` between `0` and `totalSpaces`. Draft edits remain local until Save writes the updated area document to Firebase, after which the Firestore stream refreshes the selected area.

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
