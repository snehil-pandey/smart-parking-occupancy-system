# Firebase Schema

The apps use Firebase-backed repositories in normal runtime. In-memory repositories are kept only for tests and explicit development overrides. Seed/demo records should be loaded through `/demo/seed_firebase_demo.py`, not from app-bundled runtime data.

Runtime rule: neither Flutter app should load `DemoSeed`, hardcoded parking areas, random users, or local in-memory repositories in normal app execution. Empty Firebase collections must show empty states and prompt the admin to add data or run the demo seed script.

## `/users/{userId}`

| Field | Type | Notes |
| --- | --- | --- |
| `userId` / `id` | string | Must match Firebase Auth uid |
| `authUid` | string | Firebase Auth uid; same value as `userId` in seeded profiles |
| `email` | string | Firebase Auth email used for login |
| `name` | string | Driver display name |
| `displayName` | string/null | Optional Auth/profile display name |
| `phone` | string | Driver contact number |
| `vehicleNumber` | string | Default vehicle registration |
| `defaultVehicleType` | string | `car`, `bike`, `van`, or `ev` |
| `role` | string | Always `user` |

Canonical vehicle type values:

- `bike`
- `car`
- `ev`
- `van`

Legacy values accepted defensively by the app parser:

- `twoWheeler` -> `bike`
- `motorcycle` -> `bike`
- `scooter` -> `bike`
- `fourWheeler` -> `car`

Unknown values fall back to `car` and print a debug warning instead of crashing.

## `/admins/{adminId}`

| Field | Type | Notes |
| --- | --- | --- |
| `adminId` / `id` | string | Must match Firebase Auth uid |
| `authUid` | string | Firebase Auth uid; same value as `adminId` in seeded profiles |
| `email` | string | Firebase Auth email used for login |
| `businessName` | string | Parking owner/business name |
| `displayName` | string/null | Optional Auth/profile display name |
| `ownerName` | string | Owner contact person |
| `phone` | string | Admin phone |
| `upiId` | string/null | Optional payment identifier |
| `role` | string | Always `admin` |

## `/regions/{regionId}`

| Field | Type | Notes |
| --- | --- | --- |
| `regionId` | string | Region id; demo id remains `region_sit_tumkur` |
| `adminId` | string | Owning admin uid for newly created controlled regions |
| `name` | string | Admin-controlled region name; seeded demo uses `SIT Tumkur` |
| `address` | string | Region address |
| `boundaryPoints` | array | Polygon points: `{latitude, longitude}` |
| `centerLat` | number | Map center latitude |
| `centerLng` | number | Map center longitude |
| `createdByAdminId` | string | Admin who created/owns the region setup |
| `createdAt` | timestamp/string | Creation time |
| `updatedAt` | timestamp/string | Last update time |

## `/parking_areas/{areaId}`

`/parking_locations` is the legacy model name in parts of the local code. Firestore should use `/parking_areas` for the region-aware model. Keep `parkingLocationId` on bookings as a compatibility field, but treat it as the booked `areaId`.

User-facing parking discovery, search, route destinations, bookings, QR tickets, reviews, and issue reports must use `/parking_areas` documents only. `/regions` documents describe admin-controlled boundaries and must not be copied into `/parking_areas` as fake bookable places. The user app rejects region-like area documents where `areaId` is missing/empty, equals `regionId`, starts with `region_`, has no `adminId`, or has invalid capacity values.

| Field | Type | Notes |
| --- | --- | --- |
| `areaId` | string | Parking area id |
| `regionId` | string | Usually `region_sit_tumkur` in the MVP |
| `adminId` | string | Owner id |
| `name` | string | Parking area name |
| `description` | string | Short user-facing detail |
| `address` | string | Human readable address |
| `boundaryPoints` | array | Parking area polygon corner points: `{latitude, longitude}` |
| `gatePoints` | array | Entry/exit markers for the area |
| `centerLat` / `latitude` | number | Map coordinate |
| `centerLng` / `longitude` | number | Map coordinate |
| `totalSpaces` | number | Total capacity |
| `availableSpaces` | number | Live bookable capacity |
| `pricePerHour` | number | Hourly price in INR, valid range `0..100` |
| `vehicleTypes` / `supportedVehicleTypes` | array | Supported vehicle types |
| `thumbnailRefs` | array | Image ids from `/parking_area_images` for list thumbnails |
| `imagePreviewRefs` | array | Image ids from `/parking_area_images` for detail previews |
| `imageUrls` | array | Optional future Storage URLs; keep empty in Firestore-only image mode |
| `isOpen` | boolean | Admin-controlled open/closed state |
| `openingTime` | string | Local time, e.g. `06:00` |
| `closingTime` | string | Local time, e.g. `23:00` |
| `ratingAverage` | number | Denormalized review average |
| `ratingCount` | number | Denormalized review count |
| `createdAt` | timestamp/string | Creation time |
| `updatedAt` | timestamp/string | Last update time |

Gate point shape:

| Field | Type | Notes |
| --- | --- | --- |
| `gateId` | string | Stable gate id inside the parking area |
| `name` | string | Example: `Main Gate`, `Exit Gate`, `Staff Gate`, `Student Gate` |
| `latitude` | number | GPS latitude |
| `longitude` | number | GPS longitude |
| `type` | string | `entry`, `exit`, or `both` |
| `createdAt` | timestamp/string | When the gate marker was created |

Admin geometry editing rules:

- `boundaryPoints` must contain at least three points before saving final area geometry.
- New admins must save one controlled region before creating parking areas.
- Regions are admin containers only. Users may see parking areas inside regions, but cannot select, route to, or book a region document.
- `gatePoints` are optional but recommended because user routing targets the nearest valid gate before falling back to area center.
- Gate `type` must be `entry`, `exit`, or `both`.
- Admin editor drafts are local until Save; Save updates the `/parking_areas/{areaId}` document and Firestore streams refresh the UI.
- Admin map editing uses OSM tiles with Add Point/Add Corner/Add Gate and Move Point/Move Corner/Move Gate modes.
- Current point movement is tap-to-select/tap-to-move. True draggable markers can be added later without changing the Firestore schema.
- `totalSpaces` must be `>= 0`.
- `availableSpaces` must be between `0` and `totalSpaces`.
- `pricePerHour` must be between `0` and `100`.
- Parking area corners, center, and gates must be inside the owning admin's controlled region.

## `/parking_area_images/{imageId}`

Default image mode uses Firestore only. Each document stores small optimized payloads, never the original uploaded image.

| Field | Type | Notes |
| --- | --- | --- |
| `imageId` | string | Image document id |
| `areaId` | string | Linked parking area/location id |
| `uploadedByAdminId` | string | Admin who uploaded the image |
| `thumbnailBase64` | string | JPEG thumbnail, target <= 30KB decoded |
| `previewBase64` | string | JPEG preview, target <= 120KB decoded |
| `mimeType` | string | Usually `image/jpeg` |
| `uploadedAt` | timestamp/string | Upload time |

Do not store raw/original images in Firestore. Do not embed base64 payloads directly inside `/parking_areas`; use refs only. Firestore documents have hard size limits, and large image documents also create expensive reads and slow UI rebuilds.

Recommended query pattern:

- List view: query `/parking_area_images` by `areaId`, `limit(1)`, thumbnail only in the UI layer.
- Details page: query by `areaId`, `limit(6)`, then show medium previews in a carousel.
- Admin management: query by `areaId`, `limit(12)`, with pagination for larger galleries.

## `/bookings/{bookingId}`

| Field | Type | Notes |
| --- | --- | --- |
| `userId` | string | Driver id |
| `adminId` | string | Parking owner id |
| `parkingLocationId` | string | Booked area id, kept for compatibility |
| `areaId` | string | Booked parking area id |
| `qrId` | string/null | Active QR ticket id while booking is active |
| `qrUsedAt` | timestamp/string/null | Legacy field; new phase-based entry/exit scans use `entryScannedAt` and `exitScannedAt` |
| `entryVerified` | boolean | `true` after scanner entry verification |
| `entryScannedAt` | timestamp/string/null | Entry scan timestamp |
| `exitScannedAt` | timestamp/string/null | Exit scan timestamp when the session is completed by a gate |
| `vehicleNumber` | string | Vehicle allowed through gate |
| `startTime` | timestamp/string | Booking start |
| `bookingStartAt` | timestamp/string | Canonical reserved start time used by scanner/ESP32 verification |
| `endTime` | timestamp/string | Booking end |
| `bookingEndAt` | timestamp/string | Canonical reserved end time used by scanner/ESP32 verification |
| `price` | number | Calculated booking amount |
| `status` | string | `pending`, `confirmed`, `active`, `active_parking`, `completed`, `cancelled`, `expired` |
| `qrPayload` | string | Opaque QR id only, same value as `qrId` for new bookings |
| `cancellationFine` | number | `10` when area `pricePerHour > 10`, otherwise `0` |
| `cancelledAt` | timestamp/string/null | Set when user cancels |
| `cancellationReason` | string/null | Optional user-entered reason |
| `refundAmount` | number/null | Future payment/refund helper value |
| `createdAt` | timestamp/string | Creation time |
| `updatedAt` | timestamp/string | Last update time |

## `/active_qr_tickets/{qrId}`

Active QR documents are operational records for the current booking lifecycle. Do not delete the booking record when a QR reaches a final state.

| Field | Type | Notes |
| --- | --- | --- |
| `qrId` | string | QR ticket id |
| `bookingId` | string | Linked booking |
| `userId` | string | Driver id |
| `adminId` | string | Parking owner id |
| `areaId` | string | Parking area id |
| `status` | string | `active`, `entry_verified`, `completed`, `expired`, or `cancelled` |
| `createdAt` | timestamp/string | Ticket creation time |
| `expiresAt` | timestamp/string | End of QR validity window, normally `bookingEndAt` |
| `bookingStartAt` | timestamp/string | Reserved start time copied from the booking |
| `bookingEndAt` | timestamp/string | Reserved end time copied from the booking |
| `entryScannedAt` | timestamp/string/null | Entry scan timestamp |
| `exitScannedAt` | timestamp/string/null | Exit scan timestamp when the session is completed |
| `completedAt` | timestamp/string/null | Optional final completion timestamp |
| `expiredAt` | timestamp/string/null | Optional final expiry timestamp |

QR privacy rule: QR images should encode only the opaque `qrId`, for example `qr_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`. They must not encode `userId`, `adminId`, `areaId`, vehicle number, booking JSON, or timestamps. Those fields are resolved from Firestore by the standalone scanner, ESP32 flow, or a future gate/API.

User QR rules:

- The user app allows only one active parking booking at a time. `confirmed` and `active_parking` are active user sessions.
- Entry QR is visible immediately when the booking is `confirmed` and the linked ticket is `active`.
- After scanner verification writes `bookings.status = active_parking`, `entryVerified = true`, `entryScannedAt`, and `active_qr_tickets.status = entry_verified`, the user app shows the same QR for exit until the ticket status becomes `completed`, `cancelled`, or `expired`.
- After exit, the verifier writes `bookings.status = completed`, `bookings.exitScannedAt`, `active_qr_tickets.status = completed`, and optional `completedAt`.
- If time passes `bookingEndAt` before exit, the verifier/backend should mark the booking and active QR ticket `expired`; the user app hides the active QR and keeps the booking in history.
- New QR ids are generated only for new bookings. Completed, expired, or cancelled QR ids must never be reactivated.

## `/notifications/{notificationId}`

User-facing notification records for in-app Updates tab. Local device notifications are scheduled best-effort from active QR state; Firestore notification records remain the cross-platform source.

| Field | Type | Notes |
| --- | --- | --- |
| `notificationId` | string | Notification id |
| `userId` | string | Recipient user id |
| `type` | string | `qrExpiringSoon`, `qrExpired`, `bookingConfirmed`, `bookingCancelled`, `issueResponse`, `parkingStatus` |
| `title` | string | Short title |
| `message` | string | User-facing message |
| `relatedBookingId` | string/null | Optional booking link |
| `relatedAreaId` | string/null | Optional parking area link |
| `read` | boolean | Whether the user has read it |
| `createdAt` | timestamp/string | Creation time |

## `/reviews/{reviewId}`

| Field | Type | Notes |
| --- | --- | --- |
| `reviewId` | string | Review id |
| `userId` | string | Reviewer id |
| `areaId` | string | Parking area id |
| `rating` | number | 1 to 5 |
| `comment` | string | Optional review text |
| `createdAt` | timestamp/string | Creation time |
| `updatedAt` | timestamp/string | Last update time |

## `/issue_reports/{issueId}`

| Field | Type | Notes |
| --- | --- | --- |
| `issueId` | string | Issue id |
| `userId` | string | Reporter id |
| `areaId` | string | Parking area id |
| `adminId` | string | Parking area owner id |
| `type` | string | `availability`, `pricing`, `access`, `safety`, or custom |
| `message` | string | User message |
| `status` | string | `open`, `in_progress`, `resolved`, `rejected` |
| `createdAt` | timestamp/string | Creation time |
| `updatedAt` | timestamp/string | Last update time |

## `/payments/{paymentId}`

| Field | Type | Notes |
| --- | --- | --- |
| `bookingId` | string | Linked booking |
| `userId` | string | Driver id |
| `adminId` | string | Parking owner id |
| `amount` | number | Payment amount |
| `status` | string | `pending`, `paid`, `failed`, `refunded` |
| `createdAt` | timestamp/string | Creation time |

## Routing Data

Road routes are not persisted in Firestore. The user app requests road geometry through `OsrmRouteProvider`, caches recent route responses in local memory, and falls back to a small SIT Tumkur road graph if the routing service is unavailable. Parking gate metadata is stored on `/parking_areas/{areaId}.gatePoints`; route cache entries and polylines should not be written to Firestore unless a future backend adds server-side routing analytics.

## Security Direction

- Users can read parking areas in supported regions and their own bookings.
- Users can read thumbnails/previews for visible parking areas.
- Admins can manage areas where `parking_areas.adminId == request.auth.uid`.
- Admins can create/update/delete image documents where `uploadedByAdminId == request.auth.uid`.
- Admins can read bookings for their own areas.
- Users can create reviews and issue reports for areas they can read.
- Active QR tickets should be readable only by the owning user, area admin, or verification API.
- QR verification hardware should use a constrained service account or callable API, not a wide-open client key.

## Firestore Query Index Audit

The root `firestore.indexes.json` is generated from the Firestore query shapes in the shared Firebase repositories. Deploy it from the project root before testing Firebase realtime queries:

```bash
firebase login
firebase use park-here-dev
firebase deploy --only firestore:indexes
```

If Firebase CLI has not been initialized for Firestore yet:

```bash
firebase init firestore
```

Use the checked-in `firestore.indexes.json` file. The Python seed script cannot create composite indexes.

Composite indexes required by current app code:

| Repository | Collection | Query pattern | Matching index |
| --- | --- | --- | --- |
| `FirebaseParkingRepository.getByAdmin/watchByAdmin` | `parking_areas` | `where(adminId == uid).orderBy(updatedAt DESC)` | `adminId ASC`, `updatedAt DESC` |
| `FirebaseBookingRepository.getForAdmin/watchForAdmin` | `bookings` | `where(adminId == uid).orderBy(createdAt DESC)` | `adminId ASC`, `createdAt DESC` |
| `FirebaseIssueRepository.getForAdmin/watchForAdmin` | `issue_reports` | `where(adminId == uid).orderBy(createdAt DESC)` | `adminId ASC`, `createdAt DESC` |
| `FirebaseIssueRepository.getForAdmin/watchForAdmin` with status | `issue_reports` | `where(adminId == uid).where(status == status).orderBy(createdAt DESC)` | `adminId ASC`, `status ASC`, `createdAt DESC` |

Queries that do not require composite indexes:

| Repository | Collection | Query pattern | Why no composite index |
| --- | --- | --- | --- |
| `FirebaseParkingRepository.findById/reserveSlot/releaseSlot/updateAvailability/upsert` | `parking_areas` | direct document reads/writes by id | Document lookup |
| `FirebaseParkingRepository.getOpenAreas/watchOpenAreas/watchNearby` | `parking_areas` | `where(isOpen == true)` then local sort by availability/update time | Single-field equality query; user app sees all open admin-created areas without a demo region filter |
| `FirebaseParkingRepository.getByRegion/watchByRegion` | `parking_areas` | `where(regionId == regionId)` then local sort by availability/update time | Single-field equality query |
| `FirebaseRegionRepository.getMainRegion/watchMainRegion/upsertRegion` | `regions` | direct document read/write by id | Document lookup |
| `FirebaseRegionRepository.getControlledRegion/watchControlledRegion` | `regions` | `where(adminId == uid)` or legacy `where(createdByAdminId == uid)` | Single-field index |
| `FirebaseAuthService` | `users`, `admins` | direct document reads/writes by uid | Document lookup |
| `FirebaseBookingRepository.createBooking/cancelBooking/createActiveQrTicket/consumeQrTicket/updateStatus` | `bookings`, `active_qr_tickets`, `parking_areas` | direct document reads/writes and transactions | Document lookup |
| `FirebaseBookingRepository.activeForUser/getForUser/watchForUser` | `bookings` | `where(userId == uid)` then local status/date sort | Single-field equality query |
| `FirebaseBookingRepository.getActiveQrForBooking/watchActiveQrForBooking/_findActiveQrForBooking` | `active_qr_tickets` | `where(bookingId == bookingId)` then local status/expiry filter | Single-field equality query |
| `FirebaseReviewRepository.getForArea/watchForArea` | `reviews` | `where(areaId == areaId)` then local date sort | Single-field equality query |
| `FirestoreImageRepository.getPreviewsForArea/getThumbnailsForArea` | `parking_area_images` | `where(areaId == areaId)` then local date sort/pagination | Single-field equality query |
| `FirebaseNotificationRepository.watchForUser` | `notifications` | `where(userId == uid)` then local date sort | Single-field equality query |
| `FirebaseReviewRepository.upsertReview` | `reviews`, `parking_areas` | direct document reads/writes in a transaction | Document lookup |
| `FirebaseIssueRepository.createIssue/updateIssueStatus` | `issue_reports` | direct document writes by id | Document lookup |
| `FirebaseNotificationRepository.upsert/markRead` | `notifications` | direct document writes by id | Document lookup |
| `FirestoreImageRepository.findById/removeImage/replaceImage/uploadOptimizedAreaImage` | `parking_area_images`, `parking_areas` | direct document reads/writes and transactions | Document lookup |

There are no runtime metrics collection queries in the current app code. If weekly/monthly metrics are added later, add their exact `where` and `orderBy` combinations here and regenerate `firestore.indexes.json`.

`FAILED_PRECONDITION` errors usually mean a query needs a composite index that is still missing or still building. Compare the failing query fields with this table and redeploy `firestore.indexes.json` if repository queries change. During index build time, the apps keep the signed-in session alive and ask the user/admin to wait a few minutes and refresh.

## Optional Firebase Storage Migration

If Firebase Storage is enabled later, keep `/parking_area_images` as metadata and replace base64 payload fields with storage paths or signed/public download URLs:

- `thumbnailStoragePath`
- `previewStoragePath`
- `thumbnailUrl`
- `previewUrl`

The app should continue using `ImageRepository`, swapping `FirestoreImageRepository` for `FirebaseStorageImageRepository` without changing the UI flow.

## Runtime Notes

- User and admin identity comes from Firebase Auth uid.
- Sign-up writes the matching `/users/{uid}` or `/admins/{uid}` profile.
- Sign-in creates a minimal profile if Auth exists but the role-specific Firestore profile is missing.
- The Firebase demo seed creates/reuses Auth users first, then writes profiles under the actual Auth UID.
- The Firebase Auth UID is the primary profile document id for both users and admins.
- User discovery streams open `/parking_areas` from Firebase, not a seeded region or demo admin id, then sorts distance, availability, rating, and price in memory so newly created admin areas appear without waiting on composite indexes.
- Admin region setup reads `/regions` by `adminId` or legacy `createdByAdminId`; empty Firebase shows mandatory Region Setup instead of fake local data.
- Admin area management reads by `adminId` and filters to the controlled region so closed areas remain manageable.
- Images are not stored on parking area documents; parking areas store image ids only.
- Active QR tickets are operational records. Booking history remains in `/bookings`.
- Cancellation never deletes booking history. It marks `/bookings/{bookingId}.status = cancelled`, stores fine metadata, expires the active QR if present, and releases the reserved slot once.
