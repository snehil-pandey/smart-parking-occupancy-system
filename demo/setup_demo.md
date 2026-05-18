# Park Here Firebase Demo Seed

This folder seeds a SIT Tumkur-focused dataset into Firestore for local testing of the User and Admin apps.

## What the Script Creates

- One region: `region_sit_tumkur`
- One demo admin: `admin_sit_parking_office`
- Six demo users
- Matching Firebase Auth Email/Password accounts
- Seven parking areas inside/near SIT Tumkur
- Approximate `boundaryPoints` for each parking area
- Approximate `gatePoints` for entry/exit markers
- Empty image refs by default
- Reviews and issue reports
- One active booking with one active QR ticket

The script uses deterministic emails and preferred UIDs. It checks Firebase Auth first and reuses an existing user for the email when present. Firestore profile documents are written under the actual Firebase Auth UID so app login maps correctly.

## Setup

1. Open the Firebase project.
2. Enable Firebase Authentication.
3. Enable the **Email/Password** sign-in provider.
4. Enable Cloud Firestore in Native mode.
5. Open Firebase Console > Project settings > Service accounts.
6. Generate a new private key.
7. Save it locally as `demo/serviceAccountKey.json`.
8. Never commit `serviceAccountKey.json`.
9. Copy `.env.example` to `.env`.
10. Update `.env`:

```bash
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
FIREBASE_PROJECT_ID=your-project-id
```

## Install Dependencies

From the repository root:

```bash
cd demo
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

On macOS/Linux, activate with:

```bash
source .venv/bin/activate
```

## Run

From `demo`:

```bash
python seed_firebase_demo.py
```

## Firestore Indexes

The Python seed script cannot create Firestore composite indexes. Deploy the query-derived indexes from the project root before testing realtime queries in the Flutter apps:

```bash
firebase login
firebase use park-here-dev
firebase deploy --only firestore:indexes
```

If Firebase CLI has not been initialized for Firestore yet:

```bash
firebase init firestore
```

Use the root `firestore.indexes.json` file. Missing or still-building indexes usually appear as a Firestore `FAILED_PRECONDITION` error, often for queries such as `bookings where userId == ... order by createdAt desc`. Index builds can take a few minutes after deployment.

## Reset And Reseed

When old Firestore demo data contains stale enum values such as `twoWheeler`, reset the demo collections before reseeding.

Delete Firestore demo data only:

```bash
python reset_firebase_demo.py --yes
```

Delete Firestore demo data and demo Firebase Auth users whose emails end with `@parkhere.demo`:

```bash
python reset_firebase_demo.py --yes --delete-auth-demo-users
```

Then seed a clean dataset:

```bash
python seed_firebase_demo.py
```

The reset script deletes only Park Here demo collections. It does not delete unrelated Firebase Auth users unless `--delete-auth-demo-users` is passed, and even then it only deletes users with `@parkhere.demo` emails.

## Demo Login Credentials

These accounts are for development only. The seed script creates or refreshes them through Firebase Admin SDK Auth and resets their password to the demo password on each run.

Shared demo password:

```text
ParkHere@123
```

Admin app:

| Role | Email | Password |
| --- | --- | --- |
| Admin | `admin@parkhere.demo` | `ParkHere@123` |

User app:

| Driver | Email | Password |
| --- | --- | --- |
| Ananya R | `ananya@parkhere.demo` | `ParkHere@123` |
| Karthik S | `karthik@parkhere.demo` | `ParkHere@123` |
| Meera N | `meera@parkhere.demo` | `ParkHere@123` |
| Rahul M | `rahul@parkhere.demo` | `ParkHere@123` |
| Sneha P | `sneha@parkhere.demo` | `ParkHere@123` |
| Vikram G | `vikram@parkhere.demo` | `ParkHere@123` |

## Auth And Firestore Mapping

For each demo account:

1. The script checks Firebase Auth by email.
2. If the Auth user exists, it reuses that UID and refreshes display name, password, verified status, and disabled status.
3. If the Auth user is missing, it creates one with a preferred deterministic UID.
4. It writes `/users/{authUid}` or `/admins/{authUid}` with `userId`/`adminId`, `authUid`, `email`, and role fields.
5. Parking areas, reviews, issues, bookings, and active QR records use those same Auth UIDs.

This keeps Firebase Auth login aligned with profile loading in the Flutter apps.

Canonical vehicle values are `bike`, `car`, `ev`, and `van`. The seed script rejects unsupported values before writing Firestore data.

## Reset Demo Users

To reset demo passwords and profile links, rerun:

```bash
python seed_firebase_demo.py
```

To fully reset the accounts, delete the `@parkhere.demo` users from Firebase Console > Authentication, then rerun the seed script. Firestore demo documents use fixed ids where possible and `merge=True`, so repeated runs are safe.

## Verify

In Firebase Console > Firestore, confirm these collections exist:

- `regions`
- `admins`
- `users`
- `parking_areas`
- `reviews`
- `issue_reports`
- `bookings`
- `active_qr_tickets`

## Safety Notes

- The script writes demo data to the Firebase project in `.env`.
- It does not delete existing data.
- It creates or updates Firebase Auth users for `@parkhere.demo` demo emails.
- Demo passwords are not production secrets. Do not reuse them outside local/demo Firebase projects.
- Parking images are intentionally empty by default. Upload real optimized images through the Admin app.
- Keep real credentials in `.env` and `serviceAccountKey.json`; do not commit either file.

## Coordinate Verification

The seed uses approximate coordinates around public SIT Tumkur center coordinates. Internal parking boundaries and gates must be verified physically.

Use the Admin app:

1. Open **Parking Areas**.
2. Select a parking area.
3. Stand at each real corner and tap **Mark Current Position as Corner**.
4. Stand at each entry/exit point and tap **Mark Current Position as Gate**.
5. Check GPS accuracy.
6. Tap **Save Area Geometry**.

Read `SIT_TUMKUR_COORDINATE_NOTES.md` before treating any seeded geometry as operational.
