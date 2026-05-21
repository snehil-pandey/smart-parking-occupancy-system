"""Delete Park Here demo Firestore data and demo Auth users safely."""

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
    "parking_locations",
    "parking_area_images",
    "bookings",
    "active_qr_tickets",
    "issue_reports",
    "reviews",
    "payments",
    "booking_history",
    "notifications",
    "admin_metrics",
    "area_metrics",
    "history_metrics",
    "qr_scan_logs",
    "route_cache",
    "raw_metric_events",
]

DEMO_EMAIL_SUFFIX = "@parkhere.demo"
DEMO_EMAILS = {
    "admin@parkhere.demo",
    "ananya@parkhere.demo",
    "karthik@parkhere.demo",
    "meera@parkhere.demo",
    "rahul@parkhere.demo",
    "sneha@parkhere.demo",
    "vikram@parkhere.demo",
}


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


def list_top_level_collections(db: firestore.Client) -> list[str]:
    return sorted(collection.id for collection in db.collections())


def delete_collection(
    db: firestore.Client,
    collection_name: str,
    batch_size: int = 250,
    dry_run: bool = False,
) -> int:
    if dry_run:
        return sum(1 for _ in db.collection(collection_name).stream())

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


def delete_auth_users(
    *,
    delete_all: bool,
    dry_run: bool = False,
) -> tuple[int, int]:
    deleted = 0
    skipped = 0
    page = auth.list_users()
    while page:
        for user in page.users:
            email = (user.email or "").lower()
            is_demo = email.endswith(DEMO_EMAIL_SUFFIX) or email in DEMO_EMAILS
            if delete_all or is_demo:
                if not dry_run:
                    auth.delete_user(user.uid)
                deleted += 1
                action = "Would delete" if dry_run else "Deleted"
                scope = "Auth user" if delete_all else "demo Auth user"
                print(f"{action} {scope}: {email or '<no-email>'} ({user.uid})")
            else:
                skipped += 1
        page = page.get_next_page()
    return deleted, skipped


def require_phrase(phrase: str, reason: str) -> None:
    print(reason)
    answer = input(f"Type {phrase} to continue: ").strip()
    if answer != phrase:
        raise SystemExit("Reset cancelled.")


def confirm_or_exit(args: argparse.Namespace) -> None:
    if args.dry_run:
        print("Dry run: no Firestore documents or Auth users will be deleted.")
        return
    if args.delete_all_firestore_data:
        require_phrase(
            "DELETE ALL FIRESTORE DATA",
            "DANGER: this deletes every top-level Firestore collection in the configured project.",
        )
    if args.delete_all_auth_users:
        require_phrase(
            "DELETE ALL AUTH USERS",
            "DANGER: this deletes every Firebase Auth user in the configured project. This is irreversible.",
        )
    if args.yes:
        return

    print("This will delete Park Here demo Firestore collections:")
    for collection in COLLECTIONS:
        print(f"- {collection}")
    print(f"It will also delete Firebase Auth demo users ending with {DEMO_EMAIL_SUFFIX}.")
    answer = input("Type DELETE to continue: ").strip()
    if answer != "DELETE":
        raise SystemExit("Reset cancelled.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Reset Park Here demo Firestore data and demo Auth users.",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Skip normal demo reset confirmation. Dangerous full-reset flags still require phrase confirmation.",
    )
    parser.add_argument(
        "--delete-auth-demo-users",
        action="store_true",
        help="Delete Firebase Auth demo users. Kept for compatibility; demo Auth deletion is now part of reset.",
    )
    parser.add_argument(
        "--delete-all-auth-users",
        action="store_true",
        help="DANGER: delete every Firebase Auth user after typing DELETE ALL AUTH USERS.",
    )
    parser.add_argument(
        "--delete-all-firestore-data",
        action="store_true",
        help="DANGER: delete every top-level Firestore collection after typing DELETE ALL FIRESTORE DATA.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Count matching Firestore docs/Auth users without deleting anything.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    confirm_or_exit(args)
    db = initialize_firestore()
    mode = "Scanning" if args.dry_run else "Resetting"
    print(f"{mode} Park Here Firebase data...")
    collections = list_top_level_collections(db) if args.delete_all_firestore_data else COLLECTIONS
    total_docs = 0
    for collection in collections:
        count = delete_collection(db, collection, dry_run=args.dry_run)
        total_docs += count
        action = "Would delete" if args.dry_run else "Deleted"
        print(f"{action} {count} docs from {collection}")

    auth_deleted, auth_skipped = delete_auth_users(
        delete_all=args.delete_all_auth_users,
        dry_run=args.dry_run,
    )
    action = "Would delete" if args.dry_run else "Deleted"
    auth_label = "Firebase Auth users" if args.delete_all_auth_users else "demo Firebase Auth users"
    print(f"{action} {auth_deleted} {auth_label}")
    print(f"Skipped {auth_skipped} real/non-demo Firebase Auth users")
    print(f"Firestore document total: {total_docs}")
    print("Firestore indexes are configuration, not data.")
    print("They are managed by firestore.indexes.json and Firebase CLI, not this reset script.")
    print("After reset/seed, run from the project root:")
    print("  firebase use park-here-dev")
    print("  firebase deploy --only firestore:indexes")
    print("Firebase reset complete." if not args.dry_run else "Firebase reset dry run complete.")


if __name__ == "__main__":
    main()
