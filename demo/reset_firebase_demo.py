"""Delete Park Here demo Firestore data, with optional demo Auth user cleanup."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

import firebase_admin
from firebase_admin import auth, credentials, firestore


COLLECTIONS = [
    "users",
    "admins",
    "regions",
    "parking_areas",
    "parking_area_images",
    "bookings",
    "active_qr_tickets",
    "issue_reports",
    "reviews",
    "payments",
    "booking_history",
]

DEMO_EMAIL_SUFFIX = "@parkhere.demo"


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


def delete_collection(
    db: firestore.Client,
    collection_name: str,
    batch_size: int = 250,
) -> int:
    deleted = 0
    collection = db.collection(collection_name)
    while True:
        docs = list(collection.limit(batch_size).stream())
        if not docs:
            return deleted
        batch = db.batch()
        for doc in docs:
            batch.delete(doc.reference)
        batch.commit()
        deleted += len(docs)


def delete_demo_auth_users() -> int:
    deleted = 0
    page = auth.list_users()
    while page:
        for user in page.users:
            email = (user.email or "").lower()
            if email.endswith(DEMO_EMAIL_SUFFIX):
                auth.delete_user(user.uid)
                deleted += 1
                print(f"Deleted demo Auth user: {email} ({user.uid})")
        page = page.get_next_page()
    return deleted


def confirm_or_exit(args: argparse.Namespace) -> None:
    if args.yes:
        return
    print("This will delete Park Here demo Firestore collections:")
    for collection in COLLECTIONS:
        print(f"- {collection}")
    if args.delete_auth_demo_users:
        print(f"It will also delete Firebase Auth users ending with {DEMO_EMAIL_SUFFIX}.")
    answer = input("Type DELETE to continue: ").strip()
    if answer != "DELETE":
        raise SystemExit("Reset cancelled.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Reset Park Here demo Firestore data.",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Skip interactive confirmation.",
    )
    parser.add_argument(
        "--delete-auth-demo-users",
        action="store_true",
        help="Also delete Firebase Auth users whose email ends with @parkhere.demo.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    confirm_or_exit(args)
    db = initialize_firestore()
    print("Resetting Park Here demo Firestore data...")
    for collection in COLLECTIONS:
        count = delete_collection(db, collection)
        print(f"Deleted {count} docs from {collection}")
    if args.delete_auth_demo_users:
        count = delete_demo_auth_users()
        print(f"Deleted {count} demo Firebase Auth users")
    print("Firebase demo reset complete.")


if __name__ == "__main__":
    main()
