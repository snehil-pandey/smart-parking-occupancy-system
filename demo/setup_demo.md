# Park Here Firebase Demo Seed

This folder seeds a SIT Tumkur-focused dataset into Firestore for local testing of the User and Admin apps.

## What the Script Creates

- One region: `region_sit_tumkur`
- One demo admin: `admin_sit_parking_office`
- Six demo users
- Seven parking areas inside/near SIT Tumkur
- Approximate `boundaryPoints` for each parking area
- Approximate `gatePoints` for entry/exit markers
- Empty image refs by default
- Reviews and issue reports
- One active booking with one active QR ticket

The script uses fixed document IDs and `merge=True`, so repeated runs refresh the same demo records instead of creating duplicates.

## Setup

1. Open the Firebase project.
2. Enable Cloud Firestore in Native mode.
3. Open Firebase Console > Project settings > Service accounts.
4. Generate a new private key.
5. Save it locally as `demo/serviceAccountKey.json`.
6. Never commit `serviceAccountKey.json`.
7. Copy `.env.example` to `.env`.
8. Update `.env`:

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
- It does not create Firebase Auth users; create matching Auth users manually or sign up through the apps.
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
