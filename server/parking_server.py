"""Park Here ESP32 QR verification bridge.

The ESP32 expects plain text responses, so this server deliberately returns
short command strings instead of JSON.
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from flask import Flask, Response, request
import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1 import transactional
from google.cloud.firestore_v1.base_transaction import Transaction


RESULT_ENTRY = "ENTRY"
RESULT_EXIT = "EXIT"
RESULT_BEFORE_TIME = "BEFORE_TIME"
RESULT_INVALID = "INVALID"
RESULT_USED = "USED"
RESULT_EXPIRED = "EXPIRED"
RESULT_ERROR = "ERROR"

ENTRY_UNLOCK_WINDOW = timedelta(minutes=5)

app = Flask(__name__)


def _load_firestore_client() -> firestore.Client:
    load_dotenv()
    project_id = os.getenv("FIREBASE_PROJECT_ID") or None
    service_account_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH")

    if firebase_admin._apps:
        return firestore.client()

    if service_account_path:
        account_path = Path(service_account_path).expanduser()
        if not account_path.is_absolute():
            account_path = Path.cwd() / account_path
        credential = credentials.Certificate(str(account_path))
        firebase_admin.initialize_app(credential, {"projectId": project_id})
    else:
        firebase_admin.initialize_app(options={"projectId": project_id})
    return firestore.client()


db = _load_firestore_client()


@app.get("/health")
def health() -> Response:
    return _text("OK")


@app.get("/verify")
def verify() -> Response:
    qr_id = (request.args.get("id") or "").strip()
    location_id = (request.args.get("locationId") or "").strip()
    mode = (request.args.get("mode") or "entry").strip().lower()

    if not qr_id or qr_id.startswith("{") or qr_id.startswith("["):
        return _text(RESULT_INVALID)

    try:
        result = _verify_transaction(qr_id, location_id, mode)
        return _text(result)
    except Exception as exc:  # Keep ESP32 output stable; log details locally.
        app.logger.exception("QR verification failed for %s: %s", qr_id, exc)
        return _text(RESULT_ERROR)


@transactional
def _verify_transaction(
    transaction: Transaction,
    qr_id: str,
    location_id: str,
    mode: str,
) -> str:
    ticket_ref = db.collection("active_qr_tickets").document(qr_id)
    ticket_snapshot = ticket_ref.get(transaction=transaction)
    if not ticket_snapshot.exists:
        _log_scan(transaction, qr_id=qr_id, result=RESULT_INVALID, location_id=location_id)
        return RESULT_INVALID

    ticket = ticket_snapshot.to_dict() or {}
    booking_id = ticket.get("bookingId")
    if not booking_id:
        _log_scan(transaction, qr_id=qr_id, result=RESULT_INVALID, location_id=location_id)
        return RESULT_INVALID

    booking_ref = db.collection("bookings").document(str(booking_id))
    booking_snapshot = booking_ref.get(transaction=transaction)
    if not booking_snapshot.exists:
        _log_scan(
            transaction,
            qr_id=qr_id,
            booking_id=str(booking_id),
            area_id=ticket.get("areaId"),
            result=RESULT_INVALID,
            location_id=location_id,
            message="Booking document missing.",
        )
        return RESULT_INVALID

    booking = booking_snapshot.to_dict() or {}
    area_id = str(ticket.get("areaId") or booking.get("areaId") or booking.get("parkingLocationId") or "")
    if location_id and area_id and location_id != area_id:
        _log_scan(
            transaction,
            qr_id=qr_id,
            booking_id=str(booking_id),
            area_id=area_id,
            result=RESULT_INVALID,
            location_id=location_id,
            message="Scanned at wrong parking area.",
        )
        return RESULT_INVALID

    ticket_status = str(ticket.get("status") or "")
    booking_status = str(booking.get("status") or "")
    scan_phase = str(ticket.get("scanPhase") or "entry_pending")
    scanned_once = bool(ticket.get("scannedOnce"))
    now = datetime.now(timezone.utc)
    start_at = _field_time(ticket, booking, "bookingStartAt", "startTime")
    end_at = _field_time(ticket, booking, "bookingEndAt", "endTime", "expiresAt")
    expires_at = _field_time(ticket, booking, "expiresAt", "bookingEndAt", "endTime")

    if ticket_status in {"cancelled", "canceled"} or booking_status == "cancelled":
        _log_scan(transaction, qr_id=qr_id, booking_id=str(booking_id), area_id=area_id, result=RESULT_INVALID, location_id=location_id)
        return RESULT_INVALID

    if mode == "exit":
        return _handle_exit(
            transaction=transaction,
            ticket_ref=ticket_ref,
            booking_ref=booking_ref,
            qr_id=qr_id,
            booking_id=str(booking_id),
            area_id=area_id,
            location_id=location_id,
            booking_status=booking_status,
            scan_phase=scan_phase,
        )

    if ticket_status == "used" or scanned_once or scan_phase in {"entered", "exit_pending", "exited"}:
        _log_scan(transaction, qr_id=qr_id, booking_id=str(booking_id), area_id=area_id, result=RESULT_USED, location_id=location_id)
        return RESULT_USED

    if ticket_status == "expired" or booking_status == "expired" or now > expires_at or now > end_at:
        transaction.update(ticket_ref, {"status": "expired", "updatedAt": firestore.SERVER_TIMESTAMP})
        _log_scan(transaction, qr_id=qr_id, booking_id=str(booking_id), area_id=area_id, result=RESULT_EXPIRED, location_id=location_id)
        return RESULT_EXPIRED

    if now < start_at - ENTRY_UNLOCK_WINDOW:
        _log_scan(transaction, qr_id=qr_id, booking_id=str(booking_id), area_id=area_id, result=RESULT_BEFORE_TIME, location_id=location_id)
        return RESULT_BEFORE_TIME

    if ticket_status != "active" or booking_status not in {"confirmed", "active"}:
        _log_scan(transaction, qr_id=qr_id, booking_id=str(booking_id), area_id=area_id, result=RESULT_INVALID, location_id=location_id)
        return RESULT_INVALID

    transaction.update(
        ticket_ref,
        {
            "status": "used",
            "scannedOnce": True,
            "entryScannedAt": firestore.SERVER_TIMESTAMP,
            "scanPhase": "entered",
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
    )
    transaction.update(
        booking_ref,
        {
            "status": "active_parking",
            "entryVerified": True,
            "entryScannedAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
    )
    _log_scan(transaction, qr_id=qr_id, booking_id=str(booking_id), area_id=area_id, result=RESULT_ENTRY, location_id=location_id)
    return RESULT_ENTRY


def _handle_exit(
    *,
    transaction: Transaction,
    ticket_ref: Any,
    booking_ref: Any,
    qr_id: str,
    booking_id: str,
    area_id: str,
    location_id: str,
    booking_status: str,
    scan_phase: str,
) -> str:
    if booking_status == "completed" or scan_phase == "exited":
        _log_scan(transaction, qr_id=qr_id, booking_id=booking_id, area_id=area_id, result=RESULT_USED, location_id=location_id)
        return RESULT_USED
    if booking_status != "active_parking" or scan_phase not in {"entered", "exit_pending"}:
        _log_scan(transaction, qr_id=qr_id, booking_id=booking_id, area_id=area_id, result=RESULT_INVALID, location_id=location_id)
        return RESULT_INVALID

    transaction.update(
        booking_ref,
        {
            "status": "completed",
            "exitScannedAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
    )
    transaction.update(
        ticket_ref,
        {
            "scanPhase": "exited",
            "exitScannedAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
    )
    _log_scan(transaction, qr_id=qr_id, booking_id=booking_id, area_id=area_id, result=RESULT_EXIT, location_id=location_id)
    return RESULT_EXIT


def _field_time(ticket: dict[str, Any], booking: dict[str, Any], *names: str) -> datetime:
    for name in names:
        value = ticket.get(name)
        if value is None:
            value = booking.get(name)
        if value is not None:
            return _to_utc(value)
    return datetime.now(timezone.utc)


def _to_utc(value: Any) -> datetime:
    if hasattr(value, "to_datetime"):
        value = value.to_datetime()
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)
    if isinstance(value, str):
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    raise ValueError(f"Unsupported timestamp value: {value!r}")


def _log_scan(
    transaction: Transaction,
    *,
    qr_id: str,
    result: str,
    booking_id: str | None = None,
    area_id: str | None = None,
    location_id: str = "",
    message: str = "",
) -> None:
    log_ref = db.collection("qr_scan_logs").document(str(uuid.uuid4()))
    transaction.set(
        log_ref,
        {
            "qrId": qr_id,
            "bookingId": booking_id,
            "areaId": area_id,
            "result": result,
            "scannedAt": firestore.SERVER_TIMESTAMP,
            "source": "esp32_python_server",
            "locationId": location_id,
            "message": message,
        },
    )


def _text(value: str) -> Response:
    return Response(value, mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")))
