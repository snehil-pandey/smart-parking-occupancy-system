# Park Here Firebase Demo Seed

This folder seeds a small SIT Tumkur dataset into Firestore for local testing of the User and Admin apps.

## What the Script Creates

- One region: `region_sit_tumkur`
- One demo admin: `admin_demo_001`
- Six demo users
- Four parking areas inside SIT Tumkur
- Lightweight placeholder image records in `parking_area_images`
- Reviews and issue reports
- One active booking with one active QR ticket

The script uses fixed document IDs and `merge=True`, so repeated runs refresh the same demo records instead of creating duplicates.

## Setup

1. Create or open a Firebase project.
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
- `parking_area_images`
- `reviews`
- `issue_reports`
- `bookings`
- `active_qr_tickets`

## Safety Notes

- The script writes demo data to the Firebase project in `.env`.
- It does not delete existing data.
- It does not create Firebase Auth users; app auth remains local-first unless you wire Firebase Auth providers.
- Placeholder images are tiny base64 PNG records, not real parking photos.
- Keep real credentials in `.env` and `serviceAccountKey.json`; do not commit either file.
