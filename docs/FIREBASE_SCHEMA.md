# Firebase Schema

The apps use Firebase-backed repositories in normal runtime. In-memory repositories are kept only for tests and explicit development overrides. Seed/demo records should be loaded through `/demo/seed_firebase_demo.py`, not from app-bundled runtime data.

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
| `regionId` | string | Fixed demo id: `region_sit_tumkur` |
| `name` | string | `SIT Tumkur` for the MVP |
| `address` | string | Region address |
| `boundaryPoints` | array | Polygon points: `{latitude, longitude}` |
| `centerLat` | number | Map center latitude |
| `centerLng` | number | Map center longitude |
| `createdByAdminId` | string | Admin who created/owns the region setup |
| `createdAt` | timestamp/string | Creation time |
| `updatedAt` | timestamp/string | Last update time |

## `/parking_areas/{areaId}`

`/parking_locations` is the legacy model name in parts of the local code. Firestore should use `/parking_areas` for the region-aware model. Keep `parkingLocationId` on bookings as a compatibility field, but treat it as the booked `areaId`.

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
| `qrUsedAt` | timestamp/string/null | Set when the QR is consumed |
| `vehicleNumber` | string | Vehicle allowed through gate |
| `startTime` | timestamp/string | Booking start |
| `endTime` | timestamp/string | Booking end |
| `price` | number | Calculated booking amount |
| `status` | string | `pending`, `active`, `completed`, `cancelled`, `expired` |
| `qrPayload` | string | Signed/checkable JSON payload |
| `cancellationFine` | number | `10` when area `pricePerHour > 10`, otherwise `0` |
| `cancelledAt` | timestamp/string/null | Set when user cancels |
| `cancellationReason` | string/null | Optional user-entered reason |
| `refundAmount` | number/null | Future payment/refund helper value |
| `createdAt` | timestamp/string | Creation time |
| `updatedAt` | timestamp/string | Last update time |

## `/active_qr_tickets/{qrId}`

Active QR documents are short-lived operational records. Do not delete the booking record when a QR is used.

| Field | Type | Notes |
| --- | --- | --- |
| `qrId` | string | QR ticket id |
| `bookingId` | string | Linked booking |
| `userId` | string | Driver id |
| `adminId` | string | Parking owner id |
| `areaId` | string | Parking area id |
| `status` | string | `active`, `used`, or `expired` |
| `createdAt` | timestamp/string | Ticket creation time |
| `expiresAt` | timestamp/string | End of QR validity window |

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

## Security Direction

- Users can read parking areas in supported regions and their own bookings.
- Users can read thumbnails/previews for visible parking areas.
- Admins can manage areas where `parking_areas.adminId == request.auth.uid`.
- Admins can create/update/delete image documents where `uploadedByAdminId == request.auth.uid`.
- Admins can read bookings for their own areas.
- Users can create reviews and issue reports for areas they can read.
- Active QR tickets should be readable only by the owning user, area admin, or verification API.
- QR verification hardware should use a constrained service account or callable API, not a wide-open client key.

## Recommended Composite Indexes

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

Indexes derived from current app code:

| Collection | Fields | Screen/Use |
| --- | --- | --- |
| `parking_areas` | `adminId ASC`, `updatedAt DESC` | Admin parking area list and realtime updates |
| `parking_areas` | `regionId ASC`, `availableSpaces DESC` | User region discovery and realtime availability |
| `bookings` | `userId ASC`, `status ASC`, `createdAt DESC` | User active booking lookup |
| `bookings` | `adminId ASC`, `createdAt DESC` | Admin booking history |
| `bookings` | `userId ASC`, `createdAt DESC` | User booking history |
| `active_qr_tickets` | `bookingId ASC`, `status ASC`, `expiresAt ASC` | Active QR lookup and QR status stream |
| `issue_reports` | `adminId ASC`, `createdAt DESC` | Issues Received |
| `issue_reports` | `adminId ASC`, `status ASC`, `createdAt DESC` | Filtered Issues Received |
| `reviews` | `areaId ASC`, `createdAt DESC` | Area detail comments |
| `parking_area_images` | `areaId ASC`, `uploadedAt DESC` | Lazy thumbnail/preview pagination |

`FAILED_PRECONDITION` errors usually mean a query needs a composite index that is still missing or still building. Compare the failing query fields with this table and redeploy `firestore.indexes.json` if repository queries change.

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
- User discovery reads parking areas by region and displays full/closed areas as disabled.
- Admin area management reads by `adminId` so closed areas remain manageable.
- Images are not stored on parking area documents; parking areas store image ids only.
- Active QR tickets are operational records. Booking history remains in `/bookings`.
- Cancellation never deletes booking history. It marks `/bookings/{bookingId}.status = cancelled`, stores fine metadata, expires the active QR if present, and releases the reserved slot once.
