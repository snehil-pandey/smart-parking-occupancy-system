# Deploy Firestore Indexes

Park Here uses Firestore queries that combine `where(...)` filters with `orderBy(...)`, such as:

```text
bookings where userId == currentUser order by createdAt desc
```

Firestore requires composite indexes for these query shapes. The root `firestore.indexes.json` file is derived from the Firebase repository queries in `shared/lib/repositories`. Without these indexes, the app may show a `FAILED_PRECONDITION` error with a message that an index is required.

## Query Patterns Covered

- `parking_areas` by `adminId`, ordered by `updatedAt desc`
- `parking_areas` by `regionId`, ordered by `availableSpaces desc`
- `bookings` by `userId + status`, ordered by `createdAt desc`
- `bookings` by `adminId`, ordered by `createdAt desc`
- `bookings` by `userId`, ordered by `createdAt desc`
- `active_qr_tickets` by `bookingId + status`, ordered by `expiresAt asc`
- `issue_reports` by `adminId`, ordered by `createdAt desc`
- `issue_reports` by `adminId + status`, ordered by `createdAt desc`
- `reviews` by `areaId`, ordered by `createdAt desc`
- `parking_area_images` by `areaId`, ordered by `uploadedAt desc`

## Deploy

From the repository root:

```bash
firebase login
firebase use park-here-dev
firebase deploy --only firestore:indexes
```

Replace `park-here-dev` with your Firebase project alias or project id.

If Firebase CLI has not been initialized for Firestore yet:

```bash
firebase init firestore
```

When prompted for indexes, use the root file:

```text
firestore.indexes.json
```

Then deploy again:

```bash
firebase deploy --only firestore:indexes
```

## Notes

- Run these commands from the project root.
- The Python seed script cannot create Firestore composite indexes.
- Index creation can take a few minutes in Firebase after deployment.
- During that window, the apps show `Firebase index is still building. Please wait a few minutes and refresh.` instead of crashing the signed-in session.
- If a query still fails, open the Firebase error link or compare the query fields with `firestore.indexes.json`.
