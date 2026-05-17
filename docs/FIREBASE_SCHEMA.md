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
| `imageUrls` | array | Firebase Storage or CDN URLs |
| `isOpen` | boolean | Admin-controlled open/closed state |
| `openingTime` | string | Local time, e.g. `06:00` |
| `closingTime` | string | Local time, e.g. `23:00` |
| `createdAt` | timestamp/string | Creation time |
| `updatedAt` | timestamp/string | Last update time |

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
- Admins can manage locations where `parking_locations.adminId == request.auth.uid`.
- Admins can read bookings for their own locations.
- QR verification hardware should use a constrained service account or callable API, not a wide-open client key.

