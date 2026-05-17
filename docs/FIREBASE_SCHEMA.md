# Firebase Schema

The apps run locally by default, but the models are shaped to move into Firestore without UI rewrites.

## `/users/{userId}`

| Field | Type | Notes |
| --- | --- | --- |
| `name` | string | Driver display name |
| `phone` | string | Driver contact number |
| `vehicleNumber` | string | Default vehicle registration |
| `defaultVehicleType` | string | `car`, `bike`, `van`, or `ev` |
| `role` | string | Always `user` |

## `/admins/{adminId}`

| Field | Type | Notes |
| --- | --- | --- |
| `businessName` | string | Parking owner/business name |
| `ownerName` | string | Owner contact person |
| `phone` | string | Admin phone |
| `upiId` | string/null | Optional payment identifier |
| `role` | string | Always `admin` |

## `/parking_locations/{locationId}`

| Field | Type | Notes |
| --- | --- | --- |
| `adminId` | string | Owner id |
| `name` | string | Parking location name |
| `address` | string | Human readable address |
| `latitude` | number | Map coordinate |
| `longitude` | number | Map coordinate |
| `totalSpaces` | number | Total capacity |
| `availableSpaces` | number | Live bookable capacity |
| `pricePerHour` | number | Hourly price in INR |
| `vehicleTypes` | array | Supported vehicle types |
| `thumbnailRefs` | array | Image ids from `/parking_area_images` for list thumbnails |
| `imagePreviewRefs` | array | Image ids from `/parking_area_images` for detail previews |
| `isOpen` | boolean | Admin-controlled open/closed state |
| `openingTime` | string | Local time, e.g. `06:00` |
| `closingTime` | string | Local time, e.g. `23:00` |
| `createdAt` | timestamp/string | Creation time |
| `updatedAt` | timestamp/string | Last update time |

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

Do not store raw/original images in Firestore. Do not embed base64 payloads directly inside `/parking_locations`; use refs only. Firestore documents have hard size limits, and large image documents also create expensive reads and slow UI rebuilds.

Recommended query pattern:

- List view: query `/parking_area_images` by `areaId`, `limit(1)`, thumbnail only in the UI layer.
- Details page: query by `areaId`, `limit(6)`, then show medium previews in a carousel.
- Admin management: query by `areaId`, `limit(12)`, with pagination for larger galleries.

## `/bookings/{bookingId}`

| Field | Type | Notes |
| --- | --- | --- |
| `userId` | string | Driver id |
| `adminId` | string | Parking owner id |
| `parkingLocationId` | string | Booked location |
| `vehicleNumber` | string | Vehicle allowed through gate |
| `startTime` | timestamp/string | Booking start |
| `endTime` | timestamp/string | Booking end |
| `price` | number | Calculated booking amount |
| `status` | string | `pending`, `active`, `completed`, `cancelled` |
| `qrPayload` | string | Signed/checkable JSON payload |
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

- Users can read open parking locations and their own bookings.
- Users can read thumbnails/previews for open parking areas.
- Admins can manage locations where `parking_locations.adminId == request.auth.uid`.
- Admins can create/update/delete image documents where `uploadedByAdminId == request.auth.uid`.
- Admins can read bookings for their own locations.
- QR verification hardware should use a constrained service account or callable API, not a wide-open client key.

## Optional Firebase Storage Migration

If Firebase Storage is enabled later, keep `/parking_area_images` as metadata and replace base64 payload fields with storage paths or signed/public download URLs:

- `thumbnailStoragePath`
- `previewStoragePath`
- `thumbnailUrl`
- `previewUrl`

The app should continue using `ImageRepository`, swapping `FirestoreImageRepository` for `FirebaseStorageImageRepository` without changing the UI flow.
