"""Fully wipe Park Here Firebase runtime data.

This script deletes runtime data only. It does not delete Firebase project
configuration such as apps, API keys, Firestore rules, or composite indexes.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
from typing import Iterable

import firebase_admin
from firebase_admin import auth, credentials, firestore, storage
from google.cloud.firestore_v1 import DocumentReference


CONFIRMATION_PHRASE = "DELETE EVERYTHING"
DEFAULT_BATCH_SIZE = 250


def read_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        clean_key = key.strip()
        clean_value = value.strip()
        if clean_key in {
            "FIREBASE_SERVICE_ACCOUNT_PATH",
            "GOOGLE_APPLICATION_CREDENTIALS",
        }:
            candidate = Path(clean_value)
            if not candidate.is_absolute():
                clean_value = str((path.parent / candidate).resolve())
        os.environ.setdefault(clean_key, clean_value)


def load_environment() -> None:
    script_dir = Path(__file__).resolve().parent
    read_env_file(script_dir / ".env")
    read_env_file(Path.cwd() / ".env")
    read_env_file(Path.cwd() / "demo" / ".env")


def initialize_firebase(project_id: str | None) -> firestore.Client:
    load_environment()
    service_account_path = (
        os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH")
        or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    )
    resolved_project_id = project_id or os.environ.get("FIREBASE_PROJECT_ID")
    storage_bucket = os.environ.get("FIREBASE_STORAGE_BUCKET")

    if not service_account_path:
        raise SystemExit(
            "Set FIREBASE_SERVICE_ACCOUNT_PATH or GOOGLE_APPLICATION_CREDENTIALS."
        )
    if not resolved_project_id:
        raise SystemExit("Set FIREBASE_PROJECT_ID or pass --project-id.")

    options: dict[str, str] = {"projectId": resolved_project_id}
    if storage_bucket:
        options["storageBucket"] = storage_bucket

    if not firebase_admin._apps:
        cred = credentials.Certificate(service_account_path)
        firebase_admin.initialize_app(cred, options)
    return firestore.client()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="DANGER: delete all Firestore data and Auth users.",
    )
    parser.add_argument("--yes", action="store_true", help="Run without a y/n prompt.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Count what would be deleted without deleting anything.",
    )
    parser.add_argument(
        "--delete-storage",
        action="store_true",
        help="Also delete all files in the configured Firebase Storage bucket.",
    )
    parser.add_argument(
        "--project-id",
        help="Firebase project id. Falls back to FIREBASE_PROJECT_ID.",
    )
    return parser.parse_args()


def require_confirmation(*, dry_run: bool, yes: bool) -> None:
    if dry_run:
        print("Dry run only. No Firestore docs, Auth users, or Storage files deleted.")
        return

    print("DANGER: this deletes ALL Firestore documents and ALL Auth users.")
    print("It does not delete Firebase project config, rules, indexes, apps, or API keys.")
    answer = input(f"Type {CONFIRMATION_PHRASE} to continue: ").strip()
    if answer != CONFIRMATION_PHRASE:
        raise SystemExit("Full reset cancelled.")

    if yes:
        return

    second = input("Continue with full reset? Type yes: ").strip().lower()
    if second != "yes":
        raise SystemExit("Full reset cancelled.")


def batched(iterable: list[str], size: int) -> Iterable[list[str]]:
    for index in range(0, len(iterable), size):
        yield iterable[index : index + size]


def delete_document_recursive(
    doc_ref: DocumentReference,
    *,
    dry_run: bool,
) -> int:
    deleted = 0
    for subcollection in doc_ref.collections():
        deleted += delete_collection_recursive(subcollection, dry_run=dry_run)
    if not dry_run:
        doc_ref.delete()
    return deleted + 1


def delete_collection_recursive(
    collection_ref,
    *,
    dry_run: bool,
    batch_size: int = DEFAULT_BATCH_SIZE,
) -> int:
    deleted = 0
    while True:
        docs = list(collection_ref.limit(batch_size).stream())
        if not docs:
            return deleted
        for doc in docs:
            deleted += delete_document_recursive(doc.reference, dry_run=dry_run)
        if dry_run:
            return deleted


def delete_all_firestore(db: firestore.Client, *, dry_run: bool) -> dict[str, int]:
    counts: dict[str, int] = {}
    for collection in sorted(db.collections(), key=lambda item: item.id):
        count = delete_collection_recursive(collection, dry_run=dry_run)
        counts[collection.id] = count
        action = "Would delete" if dry_run else "Deleted"
        print(f"{action} {count} Firestore docs from {collection.id}")
    return counts


def delete_all_auth_users(*, dry_run: bool) -> int:
    uids: list[str] = []
    page = auth.list_users()
    while page:
        uids.extend(user.uid for user in page.users)
        page = page.get_next_page()

    if dry_run:
        print(f"Would delete {len(uids)} Firebase Auth users")
        return len(uids)

    deleted = 0
    for chunk in batched(uids, 1000):
        result = auth.delete_users(chunk)
        deleted += result.success_count
        if result.failure_count:
            print(f"Warning: failed to delete {result.failure_count} Auth users.")
    print(f"Deleted {deleted} Firebase Auth users")
    return deleted


def delete_storage_files(*, dry_run: bool) -> int:
    bucket = storage.bucket()
    blobs = list(bucket.list_blobs())
    if dry_run:
        print(f"Would delete {len(blobs)} Firebase Storage files")
        return len(blobs)

    deleted = 0
    for blob in blobs:
        blob.delete()
        deleted += 1
    print(f"Deleted {deleted} Firebase Storage files")
    return deleted


def main() -> None:
    args = parse_args()
    require_confirmation(dry_run=args.dry_run, yes=args.yes)
    db = initialize_firebase(args.project_id)

    print("Starting full Firebase runtime reset...")
    firestore_counts = delete_all_firestore(db, dry_run=args.dry_run)
    auth_count = delete_all_auth_users(dry_run=args.dry_run)
    storage_count = 0
    if args.delete_storage:
        storage_count = delete_storage_files(dry_run=args.dry_run)

    print("")
    print("Reset summary")
    print("-------------")
    for collection, count in firestore_counts.items():
        print(f"{collection}: {count} docs")
    print(f"Auth users: {auth_count}")
    print(f"Storage files: {storage_count}")
    print("")
    print("Firebase project configuration was not deleted.")
    print("Firestore rules and indexes are managed by Firebase CLI config files.")


if __name__ == "__main__":
    main()
