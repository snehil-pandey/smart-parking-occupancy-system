"""Export Firestore collections to editable JSON files."""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1 import DocumentReference, GeoPoint


DEFAULT_COLLECTIONS = [
    "regions",
    "parking_areas",
    "bookings",
    "active_qr_tickets",
    "users",
    "admins",
    "reviews",
    "issue_reports",
    "notifications",
    "admin_metrics",
    "area_metrics",
    "history_metrics",
    "qr_scan_logs",
]


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


def initialize_firestore(project_id: str | None) -> firestore.Client:
    load_environment()
    service_account_path = (
        os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH")
        or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    )
    resolved_project_id = project_id or os.environ.get("FIREBASE_PROJECT_ID")

    if not service_account_path:
        raise SystemExit(
            "Set FIREBASE_SERVICE_ACCOUNT_PATH or GOOGLE_APPLICATION_CREDENTIALS."
        )
    if not resolved_project_id:
        raise SystemExit("Set FIREBASE_PROJECT_ID or pass --project-id.")

    if not firebase_admin._apps:
        cred = credentials.Certificate(service_account_path)
        firebase_admin.initialize_app(cred, {"projectId": resolved_project_id})
    return firestore.client()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export Firestore data to JSON.")
    parser.add_argument(
        "--collection",
        action="append",
        help="Collection id to export. Can be passed multiple times.",
    )
    parser.add_argument(
        "--output-dir",
        help="Output directory. Defaults to tools/firebase/exports/<timestamp>.",
    )
    parser.add_argument(
        "--project-id",
        help="Firebase project id. Falls back to FIREBASE_PROJECT_ID.",
    )
    return parser.parse_args()


def json_value(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc).isoformat()
    if isinstance(value, GeoPoint):
        return {"latitude": value.latitude, "longitude": value.longitude}
    if isinstance(value, DocumentReference):
        return {"__ref__": value.path}
    if isinstance(value, list):
        return [json_value(item) for item in value]
    if isinstance(value, tuple):
        return [json_value(item) for item in value]
    if isinstance(value, dict):
        return {str(key): json_value(item) for key, item in value.items()}
    return value


def export_collection(collection_ref) -> list[dict[str, Any]]:
    exported: list[dict[str, Any]] = []
    for doc in collection_ref.stream():
        data = doc.to_dict() or {}
        entry: dict[str, Any] = {
            "id": doc.id,
            "path": doc.reference.path,
            "data": json_value(data),
        }
        subcollections = {
            subcollection.id: export_collection(subcollection)
            for subcollection in doc.reference.collections()
        }
        if subcollections:
            entry["subcollections"] = subcollections
        exported.append(entry)
    exported.sort(key=lambda item: item["id"])
    return exported


def output_directory(raw_output_dir: str | None) -> Path:
    if raw_output_dir:
        return Path(raw_output_dir)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return Path(__file__).resolve().parent / "exports" / timestamp


def collection_ids(db: firestore.Client, requested: list[str] | None) -> list[str]:
    if requested:
        return sorted(set(requested))
    existing = {collection.id for collection in db.collections()}
    preferred = [collection for collection in DEFAULT_COLLECTIONS if collection in existing]
    extras = sorted(existing.difference(DEFAULT_COLLECTIONS))
    return preferred + extras


def main() -> None:
    args = parse_args()
    db = initialize_firestore(args.project_id)
    out_dir = output_directory(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    ids = collection_ids(db, args.collection)
    metadata = {
        "exportedAt": datetime.now(timezone.utc).isoformat(),
        "collections": ids,
    }
    (out_dir / "_metadata.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    total_docs = 0
    for collection_id in ids:
        docs = export_collection(db.collection(collection_id))
        total_docs += len(docs)
        target = out_dir / f"{collection_id}.json"
        target.write_text(
            json.dumps(docs, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        print(f"Exported {len(docs)} docs from {collection_id} to {target}")

    print(f"Firestore export complete: {total_docs} top-level docs in {out_dir}")


if __name__ == "__main__":
    main()
