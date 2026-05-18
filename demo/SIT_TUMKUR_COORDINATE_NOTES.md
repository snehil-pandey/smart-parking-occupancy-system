# SIT Tumkur Coordinate Notes

The demo seed is focused only on Siddaganga Institute of Technology, Tumakuru.

Public coordinate references place SIT Tumkur around:

- Center latitude: `13.3281211`
- Center longitude: `77.1256930`

The internal parking area boundaries in `seed_firebase_demo.py` are approximate campus-local placeholders. They are not survey-grade boundaries and should not be treated as final operational geometry.

## Seeded Areas

- Main Gate Parking
- Admin Block Parking
- Library Parking
- CSE/Academic Block Parking
- Auditorium Parking
- Hostel Side Parking
- Sports Ground Parking

Each seeded area includes:

- `boundaryPoints`
- `gatePoints`
- `centerLat`
- `centerLng`
- fixed ids
- realistic capacity and price values
- empty image refs by default

## What Must Be Verified Physically

- exact corner points of each parking area
- entry/exit gate locations
- whether the sports ground parking area is open to vehicles
- actual capacity counts
- admin ownership ids after real Firebase Auth setup

## How To Correct Coordinates

1. Sign in to the Admin app.
2. Open **Parking Areas**.
3. Select one SIT Tumkur parking area.
4. Physically stand at the first corner.
5. Tap **Mark Current Position as Corner**.
6. Repeat for every polygon corner in order.
7. Stand at the entry/exit gate.
8. Tap **Mark Current Position as Gate**.
9. Name the gate if needed.
10. Tap **Save Area Geometry**.

If GPS accuracy is poor, wait outdoors until the phone reports a better fix before saving.

## Warning

The seeded geometry exists to make the MVP useful during development and demos. It is not a legal survey, site plan, or safety-certified parking layout.
