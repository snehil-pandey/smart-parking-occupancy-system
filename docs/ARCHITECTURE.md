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

