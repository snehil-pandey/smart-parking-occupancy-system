# Firebase Runtime Tools

These utilities operate on the Firebase project used by Park Here. They are for disposable development/staging projects only unless a production backup and approval process exists.

## Credentials

Install dependencies:

```bash
pip install firebase-admin
```

Provide Firebase Admin SDK credentials through environment variables:

```bash
set FIREBASE_SERVICE_ACCOUNT_PATH=..\..\demo\serviceAccountKey.json
set FIREBASE_PROJECT_ID=park-here-dev
```

The scripts also read `.env` from this folder, the repository root, or `demo/.env` when present.

Never commit service account keys, `.env` files, private signing keys, or Firebase Admin credentials.

## Full Reset

`reset_everything.py` deletes runtime data only:

- all Firestore top-level collections and nested subcollections
- all Firebase Auth users
- optionally all Firebase Storage files

It does not delete Firebase project configuration:

- Firebase project
- Firebase apps
- API keys
- Firestore rules
- Firestore indexes

Dry run:

```bash
python tools/firebase/reset_everything.py --dry-run --project-id park-here-dev
```

Real reset:

```bash
python tools/firebase/reset_everything.py --yes --project-id park-here-dev
```

The real reset still requires typing:

```text
DELETE EVERYTHING
```

Delete Storage files too:

```bash
python tools/firebase/reset_everything.py --yes --delete-storage --project-id park-here-dev
```

## Firestore Export

Export every current top-level Firestore collection:

```bash
python tools/firebase/export_firestore_data.py --project-id park-here-dev
```

Output is written to:

```text
tools/firebase/exports/<timestamp>/
```

Export a single collection:

```bash
python tools/firebase/export_firestore_data.py --collection parking_areas
```

Choose an output folder:

```bash
python tools/firebase/export_firestore_data.py --output-dir tools/firebase/exports/manual_snapshot
```

Export files preserve document ids and paths:

```json
[
  {
    "id": "area_001",
    "path": "parking_areas/area_001",
    "data": {}
  }
]
```

Firestore timestamps are converted to ISO strings. Geo points and document references are converted into JSON-safe objects for manual editing or future reseeding.

## Indexes

Firestore indexes are configuration, not runtime data. These scripts do not delete, create, or rebuild composite indexes.

Deploy indexes from the repository root when query definitions change:

```bash
firebase use park-here-dev
firebase deploy --only firestore:indexes
```
