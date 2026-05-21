# Deploy Firestore Indexes

Park Here keeps user startup queries simple and sorts small campus-scale result sets in memory where practical. Some admin and detail queries still combine `where(...)` filters with `orderBy(...)`, such as:

```text
bookings where adminId == currentAdmin order by createdAt desc
```

Firestore requires composite indexes for these query shapes. The root `firestore.indexes.json` file is derived from the Firebase repository queries in `shared/lib/repositories`. Without these indexes, the app may show a `FAILED_PRECONDITION` error with a message that an index is required.

## Query Patterns Covered

- `parking_areas` by `adminId`, ordered by `updatedAt desc`
- `bookings` by `adminId`, ordered by `createdAt desc`
- `active_qr_tickets` by `bookingId + status`, ordered by `expiresAt asc`
- `issue_reports` by `adminId`, ordered by `createdAt desc`
- `issue_reports` by `adminId + status`, ordered by `createdAt desc`
- `reviews` by `areaId`, ordered by `createdAt desc`
- `parking_area_images` by `areaId`, ordered by `uploadedAt desc`

Queries intentionally kept out of composite indexes:

- `parking_areas` by `regionId`; the app sorts availability in memory.
- `bookings` by `userId`; the app sorts user booking history in memory.
- `notifications` by `userId`; the app sorts Updates in memory.

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
- The Python seed/reset scripts cannot create, delete, or rebuild Firestore composite indexes.
- Indexes are managed by the root `firestore.indexes.json` file and Firebase CLI deployment.
- To remove old unused indexes, remove them from `firestore.indexes.json` and deploy the file from the project root. If the Firebase CLI does not remove an obsolete index for your project, delete that obsolete entry manually in Firebase Console > Firestore > Indexes.
- Index creation can take a few minutes in Firebase after deployment.
- During that window, the apps show `Parking data is preparing. Try again shortly.` instead of a raw Firebase index URL.
- If a query still fails, open the Firebase error link or compare the query fields with `firestore.indexes.json`.
