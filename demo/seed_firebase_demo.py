"""Seed Firestore with a small, idempotent Park Here SIT Tumkur demo.

The script intentionally writes lightweight placeholder image payloads only.
Do not put real service account JSON in git.
"""

from __future__ import annotations

import base64
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore


REGION_ID = "region_sit_tumkur"
ADMIN_ID = "admin_demo_001"
NOW = datetime.now(timezone.utc)


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

    cred = credentials.Certificate(service_account_path)
    firebase_admin.initialize_app(cred, {"projectId": project_id})
    return firestore.client()


def gp(lat: float, lng: float) -> dict[str, float]:
    return {"latitude": lat, "longitude": lng}


def ts(hours: int = 0) -> datetime:
    return NOW + timedelta(hours=hours)


def tiny_png_base64() -> str:
    # 1x1 transparent PNG, useful as a safe placeholder under Firestore limits.
    return base64.b64encode(
        bytes.fromhex(
            "89504e470d0a1a0a0000000d4948445200000001000000010806000000"
            "1f15c4890000000a49444154789c63600000020001e221bc3300000000"
            "49454e44ae426082"
        )
    ).decode("ascii")


def seed_region(db: firestore.Client) -> None:
    boundary = [
        gp(13.0058, 77.0883),
        gp(13.0058, 77.0996),
        gp(12.9951, 77.1001),
        gp(12.9948, 77.0878),
    ]
    db.collection("regions").document(REGION_ID).set(
        {
            "regionId": REGION_ID,
            "name": "SIT Tumkur",
            "address": "Siddaganga Institute of Technology, Tumakuru, Karnataka",
            "boundaryPoints": boundary,
            "centerLat": 13.0007,
            "centerLng": 77.0941,
            "createdByAdminId": ADMIN_ID,
            "createdAt": ts(-72),
            "updatedAt": ts(),
        },
        merge=True,
    )
    print("Seeded region: SIT Tumkur")


def seed_admin(db: firestore.Client) -> None:
    db.collection("admins").document(ADMIN_ID).set(
        {
            "adminId": ADMIN_ID,
            "businessName": "SIT Parking Office",
            "phone": "+91 90000 10001",
            "upiId": "sitparking@upi",
            "role": "admin",
            "createdAt": ts(-72),
            "updatedAt": ts(),
        },
        merge=True,
    )
    print("Seeded demo admin")


def parking_areas() -> list[dict[str, object]]:
    return [
        {
            "areaId": "area_sit_main_gate",
            "name": "Main Gate Parking",
            "description": "Fast access for visitors and admissions office traffic.",
            "centerLat": 13.0022,
            "centerLng": 77.0918,
            "totalSpaces": 64,
            "availableSpaces": 22,
            "pricePerHour": 25.0,
            "ratingAverage": 4.4,
            "ratingCount": 31,
        },
        {
            "areaId": "area_sit_mechanical_block",
            "name": "Mechanical Block Parking",
            "description": "Large two-wheeler and car zone near workshops.",
            "centerLat": 12.9997,
            "centerLng": 77.0966,
            "totalSpaces": 88,
            "availableSpaces": 37,
            "pricePerHour": 20.0,
            "ratingAverage": 4.1,
            "ratingCount": 18,
        },
        {
            "areaId": "area_sit_library",
            "name": "Library Side EV Parking",
            "description": "Quiet zone with demo EV-friendly parking slots.",
            "centerLat": 13.0011,
            "centerLng": 77.0943,
            "totalSpaces": 32,
            "availableSpaces": 9,
            "pricePerHour": 30.0,
            "ratingAverage": 4.7,
            "ratingCount": 24,
        },
        {
            "areaId": "area_sit_auditorium",
            "name": "Auditorium Event Parking",
            "description": "Best for events, seminars, and weekend campus programs.",
            "centerLat": 12.9978,
            "centerLng": 77.0928,
            "totalSpaces": 52,
            "availableSpaces": 14,
            "pricePerHour": 35.0,
            "ratingAverage": 4.0,
            "ratingCount": 15,
        },
    ]


def seed_parking_areas(db: firestore.Client) -> None:
    for area in parking_areas():
        area_id = str(area["areaId"])
        lat = float(area["centerLat"])
        lng = float(area["centerLng"])
        db.collection("parking_areas").document(area_id).set(
            {
                **area,
                "id": area_id,
                "regionId": REGION_ID,
                "adminId": ADMIN_ID,
                "address": "SIT Tumkur Campus",
                "boundaryPoints": [
                    gp(lat + 0.0004, lng - 0.0005),
                    gp(lat + 0.0004, lng + 0.0005),
                    gp(lat - 0.0004, lng + 0.0005),
                    gp(lat - 0.0004, lng - 0.0005),
                ],
                "latitude": lat,
                "longitude": lng,
                "isOpen": True,
                "openingTime": "06:00",
                "closingTime": "22:00",
                "supportedVehicleTypes": ["twoWheeler", "car"],
                "vehicleTypes": ["twoWheeler", "car"],
                "thumbnailRefs": [f"img_{area_id}_thumb"],
                "imagePreviewRefs": [f"img_{area_id}_preview"],
                "imageUrls": [],
                "createdAt": ts(-48),
                "updatedAt": ts(),
            },
            merge=True,
        )
    print(f"Seeded {len(parking_areas())} parking areas")


def seed_users(db: firestore.Client) -> None:
    for index in range(1, 7):
        user_id = f"user_demo_{index:03d}"
        db.collection("users").document(user_id).set(
            {
                "userId": user_id,
                "name": f"Demo Driver {index}",
                "phone": f"+91 90000 20{index:03d}",
                "vehicleNumber": f"KA 06 DEMO {1000 + index}",
                "defaultVehicleType": "car" if index % 2 else "twoWheeler",
                "role": "user",
                "createdAt": ts(-36),
                "updatedAt": ts(),
            },
            merge=True,
        )
    print("Seeded 6 demo users")


def seed_images(db: firestore.Client) -> None:
    payload = tiny_png_base64()
    for area in parking_areas():
        area_id = str(area["areaId"])
        for kind in ("thumb", "preview"):
            image_id = f"img_{area_id}_{kind}"
            db.collection("parking_area_images").document(image_id).set(
                {
                    "imageId": image_id,
                    "areaId": area_id,
                    "uploadedByAdminId": ADMIN_ID,
                    "thumbnailBase64": payload,
                    "previewBase64": payload,
                    "mimeType": "image/png",
                    "uploadedAt": ts(-24),
                },
                merge=True,
            )
    print("Seeded lightweight placeholder image records")


def seed_reviews_and_issues(db: firestore.Client) -> None:
    reviews = [
        ("rev_001", "user_demo_001", "area_sit_main_gate", 5, "Easy entry and clear markings."),
        ("rev_002", "user_demo_002", "area_sit_library", 5, "Good spot when the library gets crowded."),
        ("rev_003", "user_demo_003", "area_sit_auditorium", 4, "Useful during seminar days."),
        ("rev_004", "user_demo_004", "area_sit_mechanical_block", 4, "Plenty of room near the workshop side."),
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
        ("issue_001", "user_demo_005", "area_sit_main_gate", "availability", "Board shows more slots than visible.", "open"),
        ("issue_002", "user_demo_006", "area_sit_auditorium", "access", "Event traffic needs clearer entry lane.", "in_progress"),
    ]
    for issue_id, user_id, area_id, issue_type, message, status in issues:
        db.collection("issue_reports").document(issue_id).set(
            {
                "issueId": issue_id,
                "userId": user_id,
                "areaId": area_id,
                "adminId": ADMIN_ID,
                "type": issue_type,
                "message": message,
                "status": status,
                "createdAt": ts(-6),
                "updatedAt": ts(),
            },
            merge=True,
        )
    print("Seeded reviews and issues")


def seed_booking_and_qr(db: firestore.Client) -> None:
    booking_id = "book_demo_001"
    qr_id = "qr_book_demo_001"
    db.collection("bookings").document(booking_id).set(
        {
            "bookingId": booking_id,
            "userId": "user_demo_001",
            "adminId": ADMIN_ID,
            "parkingLocationId": "area_sit_main_gate",
            "areaId": "area_sit_main_gate",
            "vehicleNumber": "KA 06 DEMO 1001",
            "startTime": ts(-1),
            "endTime": ts(2),
            "price": 75.0,
            "status": "active",
            "qrId": qr_id,
            "qrPayload": '{"issuer":"park_here","bookingId":"book_demo_001","qrId":"qr_book_demo_001","version":1}',
            "createdAt": ts(-1),
            "updatedAt": ts(),
        },
        merge=True,
    )
    db.collection("active_qr_tickets").document(qr_id).set(
        {
            "qrId": qr_id,
            "bookingId": booking_id,
            "userId": "user_demo_001",
            "adminId": ADMIN_ID,
            "areaId": "area_sit_main_gate",
            "status": "active",
            "createdAt": ts(-1),
            "expiresAt": ts(2),
        },
        merge=True,
    )
    print("Seeded active demo booking and QR ticket")


def main() -> None:
    db = initialize_firestore()
    print("Starting Park Here SIT Tumkur demo seed...")
    seed_region(db)
    seed_admin(db)
    seed_users(db)
    seed_parking_areas(db)
    seed_images(db)
    seed_reviews_and_issues(db)
    seed_booking_and_qr(db)
    print("Demo seed complete. Re-run anytime; fixed document IDs are merged.")


if __name__ == "__main__":
    main()
