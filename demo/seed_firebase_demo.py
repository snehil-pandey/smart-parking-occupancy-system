"""Seed Firestore with idempotent Park Here demo data for SIT Tumkur only.

Coordinates are campus-local approximate placeholders. Use the Admin app GPS
marker mode to physically re-mark parking area corners and gates before any
real deployment.
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import auth, credentials, firestore


REGION_ID = "region_sit_tumkur"
ADMIN_ID = "admin_sit_parking_office"
ADMIN_EMAIL = "admin@parkhere.demo"
DEMO_PASSWORD = "ParkHere@123"
NOW = datetime.now(timezone.utc)
CANONICAL_VEHICLE_TYPES = {"bike", "car", "ev", "van"}

USER_ACCOUNTS = [
    {
        "preferredUid": "user_demo_001",
        "email": "ananya@parkhere.demo",
        "name": "Ananya R",
        "phone": "+91 90000 20001",
        "vehicleNumber": "KA 06 AB 1201",
        "defaultVehicleType": "car",
    },
    {
        "preferredUid": "user_demo_002",
        "email": "karthik@parkhere.demo",
        "name": "Karthik S",
        "phone": "+91 90000 20002",
        "vehicleNumber": "KA 06 HS 4421",
        "defaultVehicleType": "bike",
    },
    {
        "preferredUid": "user_demo_003",
        "email": "meera@parkhere.demo",
        "name": "Meera N",
        "phone": "+91 90000 20003",
        "vehicleNumber": "KA 05 EV 8872",
        "defaultVehicleType": "ev",
    },
    {
        "preferredUid": "user_demo_004",
        "email": "rahul@parkhere.demo",
        "name": "Rahul M",
        "phone": "+91 90000 20004",
        "vehicleNumber": "KA 06 CM 7634",
        "defaultVehicleType": "bike",
    },
    {
        "preferredUid": "user_demo_005",
        "email": "sneha@parkhere.demo",
        "name": "Sneha P",
        "phone": "+91 90000 20005",
        "vehicleNumber": "KA 06 AR 5510",
        "defaultVehicleType": "car",
    },
    {
        "preferredUid": "user_demo_006",
        "email": "vikram@parkhere.demo",
        "name": "Vikram G",
        "phone": "+91 90000 20006",
        "vehicleNumber": "KA 01 VN 2290",
        "defaultVehicleType": "van",
    },
]


def read_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def initialize_firestore() -> firestore.Client:
    read_env_file(Path(__file__).with_name(".env"))
    service_account_path = os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH")
    project_id = os.environ.get("FIREBASE_PROJECT_ID")

    if not service_account_path:
        raise SystemExit("Set FIREBASE_SERVICE_ACCOUNT_PATH in demo/.env or your shell.")
    if not project_id:
        raise SystemExit("Set FIREBASE_PROJECT_ID in demo/.env or your shell.")

    if not firebase_admin._apps:
        cred = credentials.Certificate(service_account_path)
        firebase_admin.initialize_app(cred, {"projectId": project_id})
    return firestore.client()


def gp(lat: float, lng: float) -> dict[str, float]:
    return {"latitude": round(lat, 7), "longitude": round(lng, 7)}


def gate(
    gate_id: str,
    name: str,
    lat: float,
    lng: float,
    gate_type: str = "both",
) -> dict[str, Any]:
    return {
        "gateId": gate_id,
        "name": name,
        "latitude": round(lat, 7),
        "longitude": round(lng, 7),
        "type": gate_type,
        "createdAt": ts(-48),
    }


def ts(hours: int = 0) -> datetime:
    return NOW + timedelta(hours=hours)


def ensure_auth_user(preferred_uid: str, email: str, display_name: str) -> str:
    """Create or refresh a demo Auth user and return the uid Firestore must use."""
    try:
        user = auth.get_user_by_email(email)
        auth.update_user(
            user.uid,
            password=DEMO_PASSWORD,
            display_name=display_name,
            email_verified=True,
            disabled=False,
        )
        print(f"Reused Firebase Auth user: {email} ({user.uid})")
        return user.uid
    except auth.UserNotFoundError:
        pass

    try:
        user = auth.create_user(
            uid=preferred_uid,
            email=email,
            password=DEMO_PASSWORD,
            display_name=display_name,
            email_verified=True,
            disabled=False,
        )
        print(f"Created Firebase Auth user: {email} ({user.uid})")
        return user.uid
    except auth.UidAlreadyExistsError:
        user = auth.get_user(preferred_uid)
        auth.update_user(
            user.uid,
            email=email,
            password=DEMO_PASSWORD,
            display_name=display_name,
            email_verified=True,
            disabled=False,
        )
        print(f"Updated Firebase Auth user by uid: {email} ({user.uid})")
        return user.uid


def seed_region(db: firestore.Client, admin_uid: str) -> None:
    # Approximate campus envelope around public SIT Tumkur center coordinates.
    boundary = [
        gp(13.33025, 77.12265),
        gp(13.33060, 77.12870),
        gp(13.32545, 77.12925),
        gp(13.32505, 77.12305),
    ]
    db.collection("regions").document(REGION_ID).set(
        {
            "regionId": REGION_ID,
            "name": "SIT Tumkur",
            "address": "Siddaganga Institute of Technology, Tumakuru, Karnataka 572103",
            "boundaryPoints": boundary,
            "centerLat": 13.3281211,
            "centerLng": 77.1256930,
            "createdByAdminId": admin_uid,
            "createdAt": ts(-72),
            "updatedAt": ts(),
        },
        merge=True,
    )
    print("Seeded region: SIT Tumkur")


def seed_admin(db: firestore.Client) -> str:
    admin_uid = ensure_auth_user(
        preferred_uid=ADMIN_ID,
        email=ADMIN_EMAIL,
        display_name="SIT Tumkur Parking Office",
    )
    db.collection("admins").document(admin_uid).set(
        {
            "adminId": admin_uid,
            "id": admin_uid,
            "authUid": admin_uid,
            "email": ADMIN_EMAIL,
            "businessName": "SIT Tumkur Parking Office",
            "displayName": "SIT Tumkur Parking Office",
            "ownerName": "Campus Parking Administrator",
            "phone": "+91 90000 10001",
            "upiId": "sitparking@upi",
            "role": "admin",
            "createdAt": ts(-72),
            "updatedAt": ts(),
        },
        merge=True,
    )
    print("Seeded demo admin profile")
    return admin_uid


def parking_areas() -> list[dict[str, Any]]:
    return [
        {
            "areaId": "area_sit_main_gate_parking",
            "name": "Main Gate Parking",
            "description": "Visitor-friendly parking near the public-facing campus entrance.",
            "centerLat": 13.32835,
            "centerLng": 77.12355,
            "boundaryPoints": [
                gp(13.32872, 77.12318),
                gp(13.32874, 77.12388),
                gp(13.32806, 77.12392),
                gp(13.32804, 77.12320),
            ],
            "gatePoints": [
                gate("gate_main_entry", "Main Gate", 13.32831, 77.12316, "both"),
            ],
            "totalSpaces": 52,
            "availableSpaces": 18,
            "pricePerHour": 20.0,
            "supportedVehicleTypes": ["car", "bike", "ev"],
            "ratingAverage": 4.4,
            "ratingCount": 31,
        },
        {
            "areaId": "area_sit_admin_block_parking",
            "name": "Admin Block Parking",
            "description": "Short-stay parking for office, admissions, and staff visits.",
            "centerLat": 13.32888,
            "centerLng": 77.12520,
            "boundaryPoints": [
                gp(13.32918, 77.12486),
                gp(13.32920, 77.12548),
                gp(13.32858, 77.12554),
                gp(13.32854, 77.12488),
            ],
            "gatePoints": [
                gate("gate_admin_staff", "Staff Gate", 13.32878, 77.12488, "both"),
            ],
            "totalSpaces": 34,
            "availableSpaces": 7,
            "pricePerHour": 30.0,
            "supportedVehicleTypes": ["car", "bike"],
            "ratingAverage": 4.2,
            "ratingCount": 17,
        },
        {
            "areaId": "area_sit_library_parking",
            "name": "Library Parking",
            "description": "Quiet student and faculty parking near the library side.",
            "centerLat": 13.32772,
            "centerLng": 77.12586,
            "boundaryPoints": [
                gp(13.32804, 77.12548),
                gp(13.32804, 77.12622),
                gp(13.32738, 77.12624),
                gp(13.32736, 77.12550),
            ],
            "gatePoints": [
                gate("gate_library_student", "Student Gate", 13.32768, 77.12548, "both"),
            ],
            "totalSpaces": 46,
            "availableSpaces": 0,
            "pricePerHour": 10.0,
            "supportedVehicleTypes": ["bike", "car"],
            "ratingAverage": 4.6,
            "ratingCount": 24,
        },
        {
            "areaId": "area_sit_cse_academic_block_parking",
            "name": "CSE/Academic Block Parking",
            "description": "Academic block parking intended for students and faculty during class hours.",
            "centerLat": 13.32705,
            "centerLng": 77.12676,
            "boundaryPoints": [
                gp(13.32740, 77.12638),
                gp(13.32738, 77.12716),
                gp(13.32672, 77.12716),
                gp(13.32670, 77.12640),
            ],
            "gatePoints": [
                gate("gate_cse_entry", "Academic Entry", 13.32703, 77.12638, "entry"),
                gate("gate_cse_exit", "Academic Exit", 13.32676, 77.12710, "exit"),
            ],
            "totalSpaces": 72,
            "availableSpaces": 26,
            "pricePerHour": 15.0,
            "supportedVehicleTypes": ["bike", "car"],
            "ratingAverage": 4.1,
            "ratingCount": 21,
        },
        {
            "areaId": "area_sit_auditorium_parking",
            "name": "Auditorium Parking",
            "description": "Event parking for seminars, college programs, and weekend gatherings.",
            "centerLat": 13.32638,
            "centerLng": 77.12462,
            "boundaryPoints": [
                gp(13.32680, 77.12418),
                gp(13.32678, 77.12508),
                gp(13.32598, 77.12510),
                gp(13.32596, 77.12420),
            ],
            "gatePoints": [
                gate("gate_auditorium_event", "Event Gate", 13.32642, 77.12420, "both"),
            ],
            "totalSpaces": 58,
            "availableSpaces": 11,
            "pricePerHour": 25.0,
            "supportedVehicleTypes": ["car", "bike", "van"],
            "ratingAverage": 4.0,
            "ratingCount": 15,
        },
        {
            "areaId": "area_sit_hostel_side_parking",
            "name": "Hostel Side Parking",
            "description": "Longer-stay student parking near the hostel side of campus.",
            "centerLat": 13.32952,
            "centerLng": 77.12738,
            "boundaryPoints": [
                gp(13.32986, 77.12702),
                gp(13.32986, 77.12778),
                gp(13.32920, 77.12782),
                gp(13.32918, 77.12704),
            ],
            "gatePoints": [
                gate("gate_hostel_side", "Hostel Side Gate", 13.32948, 77.12702, "both"),
            ],
            "totalSpaces": 64,
            "availableSpaces": 42,
            "pricePerHour": 0.0,
            "supportedVehicleTypes": ["bike", "car"],
            "ratingAverage": 4.3,
            "ratingCount": 19,
        },
        {
            "areaId": "area_sit_sports_ground_parking",
            "name": "Sports Ground Parking",
            "description": "Open parking area used during sports events and large campus activities.",
            "centerLat": 13.32582,
            "centerLng": 77.12756,
            "boundaryPoints": [
                gp(13.32622, 77.12706),
                gp(13.32620, 77.12808),
                gp(13.32544, 77.12810),
                gp(13.32542, 77.12708),
            ],
            "gatePoints": [
                gate("gate_sports_entry", "Sports Ground Gate", 13.32584, 77.12706, "both"),
            ],
            "totalSpaces": 80,
            "availableSpaces": 0,
            "pricePerHour": 15.0,
            "supportedVehicleTypes": ["car", "bike", "van"],
            "ratingAverage": 3.9,
            "ratingCount": 12,
            "isOpen": False,
        },
    ]


def seed_parking_areas(db: firestore.Client, admin_uid: str) -> None:
    for area in parking_areas():
        area_id = str(area["areaId"])
        vehicle_types = list(area["supportedVehicleTypes"])
        invalid_types = set(vehicle_types) - CANONICAL_VEHICLE_TYPES
        if invalid_types:
            raise ValueError(f"{area_id} has unsupported vehicle types: {invalid_types}")
        db.collection("parking_areas").document(area_id).set(
            {
                **area,
                "id": area_id,
                "regionId": REGION_ID,
                "adminId": admin_uid,
                "address": "SIT Tumkur Campus, Tumakuru, Karnataka",
                "latitude": area["centerLat"],
                "longitude": area["centerLng"],
                "isOpen": area.get("isOpen", True),
                "openingTime": "06:00",
                "closingTime": "22:00",
                "vehicleTypes": vehicle_types,
                "thumbnailRefs": [],
                "imagePreviewRefs": [],
                "imageUrls": [],
                "createdAt": ts(-48),
                "updatedAt": ts(),
            },
            merge=True,
        )
    print(f"Seeded {len(parking_areas())} SIT Tumkur parking areas")


def seed_users(db: firestore.Client) -> dict[str, str]:
    user_uids: dict[str, str] = {}
    for account in USER_ACCOUNTS:
        preferred_uid = str(account["preferredUid"])
        email = str(account["email"])
        name = str(account["name"])
        uid = ensure_auth_user(
            preferred_uid=preferred_uid,
            email=email,
            display_name=name,
        )
        vehicle_type = str(account["defaultVehicleType"])
        if vehicle_type not in CANONICAL_VEHICLE_TYPES:
            raise ValueError(f"{preferred_uid} has unsupported vehicle type: {vehicle_type}")
        user_uids[preferred_uid] = uid
        db.collection("users").document(uid).set(
            {
                "userId": uid,
                "id": uid,
                "authUid": uid,
                "email": email,
                "name": name,
                "displayName": name,
                "phone": account["phone"],
                "vehicleNumber": account["vehicleNumber"],
                "defaultVehicleType": account["defaultVehicleType"],
                "role": "user",
                "createdAt": ts(-36),
                "updatedAt": ts(),
            },
            merge=True,
        )
    print("Seeded 6 demo users")
    return user_uids


def seed_reviews_and_issues(
    db: firestore.Client,
    user_uids: dict[str, str],
    admin_uid: str,
) -> None:
    reviews = [
        ("rev_sit_001", user_uids["user_demo_001"], "area_sit_main_gate_parking", 5, "Easy to find from the main road."),
        ("rev_sit_002", user_uids["user_demo_002"], "area_sit_cse_academic_block_parking", 4, "Useful during morning classes."),
        ("rev_sit_003", user_uids["user_demo_003"], "area_sit_hostel_side_parking", 5, "Free parking helps students."),
        ("rev_sit_004", user_uids["user_demo_004"], "area_sit_auditorium_parking", 4, "Good during events, but entry needs markings."),
    ]
    for review_id, user_id, area_id, rating, comment in reviews:
        db.collection("reviews").document(review_id).set(
            {
                "reviewId": review_id,
                "userId": user_id,
                "areaId": area_id,
                "rating": rating,
                "comment": comment,
                "createdAt": ts(-12),
                "updatedAt": ts(),
            },
            merge=True,
        )

    issues = [
        ("issue_sit_001", user_uids["user_demo_005"], "area_sit_library_parking", "availability", "Library parking is marked full; please verify the count.", "open"),
        ("issue_sit_002", user_uids["user_demo_006"], "area_sit_auditorium_parking", "access", "Event traffic needs clearer entry and exit gate labels.", "in_progress"),
    ]
    for issue_id, user_id, area_id, issue_type, message, status in issues:
        db.collection("issue_reports").document(issue_id).set(
            {
                "issueId": issue_id,
                "userId": user_id,
                "areaId": area_id,
                "adminId": admin_uid,
                "type": issue_type,
                "message": message,
                "status": status,
                "createdAt": ts(-6),
                "updatedAt": ts(),
            },
            merge=True,
        )
    print("Seeded SIT reviews and issues")


def seed_booking_and_qr(
    db: firestore.Client,
    user_uids: dict[str, str],
    admin_uid: str,
) -> None:
    booking_id = "book_sit_demo_001"
    qr_id = "qr_book_sit_demo_001"
    user_id = user_uids["user_demo_001"]
    db.collection("bookings").document(booking_id).set(
        {
            "bookingId": booking_id,
            "userId": user_id,
            "adminId": admin_uid,
            "parkingLocationId": "area_sit_main_gate_parking",
            "areaId": "area_sit_main_gate_parking",
            "vehicleNumber": "KA 06 AB 1201",
            "startTime": ts(-1),
            "endTime": ts(2),
            "price": 60.0,
            "status": "active",
            "qrId": qr_id,
            "qrPayload": '{"issuer":"park_here","bookingId":"book_sit_demo_001","qrId":"qr_book_sit_demo_001","version":1}',
            "cancellationFine": 0.0,
            "cancelledAt": None,
            "cancellationReason": None,
            "refundAmount": None,
            "createdAt": ts(-1),
            "updatedAt": ts(),
        },
        merge=True,
    )
    db.collection("active_qr_tickets").document(qr_id).set(
        {
            "qrId": qr_id,
            "bookingId": booking_id,
            "userId": user_id,
            "adminId": admin_uid,
            "areaId": "area_sit_main_gate_parking",
            "status": "active",
            "createdAt": ts(-1),
            "expiresAt": ts(2),
        },
        merge=True,
    )
    print("Seeded one active SIT booking and QR ticket")


def main() -> None:
    db = initialize_firestore()
    print("Starting Park Here SIT Tumkur demo seed...")
    admin_uid = seed_admin(db)
    user_uids = seed_users(db)
    seed_region(db, admin_uid)
    seed_parking_areas(db, admin_uid)
    seed_reviews_and_issues(db, user_uids, admin_uid)
    seed_booking_and_qr(db, user_uids, admin_uid)
    print("Demo seed complete. Re-run anytime; fixed document IDs are merged.")


if __name__ == "__main__":
    main()
