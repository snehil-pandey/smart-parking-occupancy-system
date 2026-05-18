# Deploy Firestore Indexes

Park Here uses Firestore queries that combine `where(...)` filters with `orderBy(...)`, such as:

```text
bookings where userId == currentUser order by createdAt desc
```

Firestore requires composite indexes for these query shapes. Without them, the app may show a `FAILED_PRECONDITION` error with a message that an index is required.

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

- The Python seed script cannot create Firestore composite indexes.
- Index creation can take a few minutes in Firebase after deployment.
- If a query still fails, open the Firebase error link or compare the query fields with `firestore.indexes.json`.
