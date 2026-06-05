"""Clean legacy Park Here active QR ticket fields without deleting bookings."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore


ACTIVE_QR_COLLECTION = "active_qr_tickets"
FINAL_STATUSES = {"completed", "expired", "cancelled", "used"}
LEGACY_FIELDS = ("scan" + "Phase", "scanned" + "Once")


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


def cleanup_active_qr_tickets(
    db: firestore.Client,
    *,
    dry_run: bool,
    delete_final: bool,
) -> tuple[int, int]:
    cleaned_docs = 0
    deleted_docs = 0
    batch = db.batch()
    pending_writes = 0

    for snapshot in db.collection(ACTIVE_QR_COLLECTION).stream():
        data = snapshot.to_dict() or {}
        status = str(data.get("status") or "").strip().lower()
        legacy_updates = {
            field: firestore.DELETE_FIELD
            for field in LEGACY_FIELDS
            if field in data
        }

        if delete_final and status in FINAL_STATUSES:
            deleted_docs += 1
            print(f"Delete inactive live QR doc: {snapshot.id} (status={status})")
            if not dry_run:
                batch.delete(snapshot.reference)
                pending_writes += 1
        elif legacy_updates:
            cleaned_docs += 1
            fields = ", ".join(legacy_updates)
            print(f"Remove legacy fields from {snapshot.id}: {fields}")
            if not dry_run:
                batch.update(snapshot.reference, legacy_updates)
                pending_writes += 1

        if pending_writes >= 400:
            batch.commit()
            batch = db.batch()
            pending_writes = 0

    if pending_writes:
        batch.commit()

    return cleaned_docs, deleted_docs


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Remove legacy fields from active QR tickets and delete final-state "
            "live QR docs. Booking history is never deleted."
        )
    )
    parser.add_argument("--dry-run", action="store_true", help="Print changes only.")
    parser.add_argument("--yes", action="store_true", help="Run without prompt.")
    parser.add_argument(
        "--keep-final",
        action="store_true",
        help="Do not delete completed/expired/cancelled active QR docs.",
    )
    return parser.parse_args()


def confirm_or_exit(args: argparse.Namespace) -> None:
    if args.dry_run or args.yes:
        return
    answer = input(
        "This will update active_qr_tickets only and never delete bookings. Continue? [y/N] "
    )
    if answer.strip().lower() != "y":
        raise SystemExit("Aborted.")


def main() -> None:
    args = parse_args()
    confirm_or_exit(args)
    db = initialize_firestore()
    cleaned, deleted = cleanup_active_qr_tickets(
        db,
        dry_run=args.dry_run,
        delete_final=not args.keep_final,
    )
    mode = "DRY RUN" if args.dry_run else "DONE"
    print(f"{mode}: legacy-field docs cleaned={cleaned}, inactive QR docs deleted={deleted}")
    print("Bookings collection was not modified.")


if __name__ == "__main__":
    main()
