"""Shared Firebase QR verification logic for Park Here gate bridges."""

from __future__ import annotations

import os
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, TYPE_CHECKING

from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1 import transactional

if TYPE_CHECKING:
    from google.cloud.firestore_v1.transaction import Transaction


RESULT_ENTRY = "ENTRY"
RESULT_EXIT = "EXIT"
RESULT_BEFORE_TIME = "BEFORE_TIME"
RESULT_INVALID = "INVALID"
RESULT_USED = "USED"
RESULT_EXPIRED = "EXPIRED"
RESULT_ERROR = "ERROR"

VALID_RESULTS = {
    RESULT_ENTRY,
    RESULT_EXIT,
    RESULT_BEFORE_TIME,
    RESULT_INVALID,
    RESULT_USED,
    RESULT_EXPIRED,
    RESULT_ERROR,
}

LOG_SOURCE = "esp32_python_server"
CAMERA_ENTRY = "entry"
CAMERA_EXIT = "exit"
VALID_CAMERA_TYPES = {CAMERA_ENTRY, CAMERA_EXIT}

_db: firestore.Client | None = None


@dataclass(frozen=True)
class ParkingAreaOption:
    area_id: str
    name: str
    region_id: str

    @property
    def label(self) -> str:
        region = f" ({self.region_id})" if self.region_id else ""
        return f"{self.name} - {self.area_id}{region}"


def get_firestore_client() -> firestore.Client:
    """Initialize Firebase Admin SDK once and return a Firestore client."""

    global _db
    if _db is not None:
        return _db

    load_dotenv()
    project_id = os.getenv("FIREBASE_PROJECT_ID") or None
    service_account_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH")

    if firebase_admin._apps:
        _db = firestore.client()
        return _db

    if service_account_path:
        account_path = Path(service_account_path).expanduser()
        if not account_path.is_absolute():
            account_path = Path.cwd() / account_path
        credential = credentials.Certificate(str(account_path))
        firebase_admin.initialize_app(credential, {"projectId": project_id})
    else:
        firebase_admin.initialize_app(options={"projectId": project_id})

    _db = firestore.client()
    return _db


def firebase_project_id() -> str:
    """Return the configured Firebase project id without exposing secrets."""

    get_firestore_client()
    app = firebase_admin.get_app()
    return str(app.options.get("projectId") or os.getenv("FIREBASE_PROJECT_ID") or "unknown")


def verify_qr_scan(
    qr_id: str,
    location_id: str = "",
    camera_type: str = CAMERA_ENTRY,
    source: str = LOG_SOURCE,
) -> str:
    """Verify a QR scan and atomically update Firestore.

    The returned value is intentionally a plain command string so ESP32 clients
    can consume it directly.
    """

    qr_id = (qr_id or "").strip()
    location_id = (location_id or "").strip()
    camera_type = _normalize_camera_type(camera_type)
    source = (source or LOG_SOURCE).strip()

    if not _is_valid_qr_id(qr_id) or camera_type not in VALID_CAMERA_TYPES:
        return RESULT_INVALID

    try:
        return _verify_transaction(qr_id, location_id, camera_type, source)
    except Exception:
        return RESULT_ERROR


@transactional
def _verify_transaction(
    transaction: Transaction,
    qr_id: str,
    location_id: str,
    camera_type: str,
    source: str,
) -> str:
    db = get_firestore_client()
    ticket_ref = db.collection("active_qr_tickets").document(qr_id)
    ticket_snapshot = ticket_ref.get(transaction=transaction)
    if not ticket_snapshot.exists:
        _log_scan(transaction, qr_id=qr_id, result=RESULT_INVALID, location_id=location_id, source=source)
        return RESULT_INVALID

    ticket = ticket_snapshot.to_dict() or {}
    booking_id = ticket.get("bookingId")
    if not booking_id:
        _log_scan(transaction, qr_id=qr_id, result=RESULT_INVALID, location_id=location_id, source=source)
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
            source=source,
            message="Booking document missing.",
        )
        return RESULT_INVALID

    booking = booking_snapshot.to_dict() or {}
    ticket_area_id = str(ticket.get("areaId") or "")
    booking_area_id = str(booking.get("areaId") or booking.get("parkingLocationId") or "")
    area_id = ticket_area_id or booking_area_id
    if location_id and (
        not area_id
        or (ticket_area_id and ticket_area_id != location_id)
        or (booking_area_id and booking_area_id != location_id)
    ):
        _log_scan(
            transaction,
            qr_id=qr_id,
            booking_id=str(booking_id),
            area_id=area_id,
            result=RESULT_INVALID,
            location_id=location_id,
            source=source,
            message="Scanned at wrong parking area.",
        )
        return RESULT_INVALID

    ticket_status = str(ticket.get("status") or "")
    booking_status = str(booking.get("status") or "")
    scan_phase = str(ticket.get("scanPhase") or "entry_pending")

    if ticket_status in {"cancelled", "canceled"} or booking_status == "cancelled":
        _log_scan(
            transaction,
            qr_id=qr_id,
            booking_id=str(booking_id),
            area_id=area_id,
            result=RESULT_INVALID,
            location_id=location_id,
            source=source,
            scan_phase=scan_phase,
        )
        return RESULT_INVALID

    if ticket_status == "expired" or booking_status == "expired":
        _log_scan(
            transaction,
            qr_id=qr_id,
            booking_id=str(booking_id),
            user_id=str(ticket.get("userId") or booking.get("userId") or ""),
            area_id=area_id,
            result=RESULT_EXPIRED,
            location_id=location_id,
            source=source,
            scan_phase=scan_phase,
        )
        return RESULT_EXPIRED

    if ticket_status in {"used", "completed"} or booking_status == "completed" or scan_phase == "exited":
        _log_scan(
            transaction,
            qr_id=qr_id,
            booking_id=str(booking_id),
            user_id=str(ticket.get("userId") or booking.get("userId") or ""),
            area_id=area_id,
            result=RESULT_USED,
            location_id=location_id,
            source=source,
            scan_phase=scan_phase,
            message="Ticket is already closed.",
        )
        return RESULT_USED

    if camera_type == CAMERA_ENTRY:
        return _handle_entry_camera(
            transaction=transaction,
            ticket_ref=ticket_ref,
            booking_ref=booking_ref,
            qr_id=qr_id,
            booking_id=str(booking_id),
            area_id=area_id,
            location_id=location_id,
            ticket_status=ticket_status,
            scan_phase=scan_phase,
            source=source,
            user_id=str(ticket.get("userId") or booking.get("userId") or ""),
        )

    return _handle_exit_camera(
        transaction=transaction,
        ticket_ref=ticket_ref,
        booking_ref=booking_ref,
        qr_id=qr_id,
        booking_id=str(booking_id),
        area_id=area_id,
        location_id=location_id,
        ticket_status=ticket_status,
        scan_phase=scan_phase,
        source=source,
        user_id=str(ticket.get("userId") or booking.get("userId") or ""),
    )


def _handle_entry_camera(
    *,
    transaction: Transaction,
    ticket_ref: Any,
    booking_ref: Any,
    qr_id: str,
    booking_id: str,
    area_id: str,
    location_id: str,
    ticket_status: str,
    scan_phase: str,
    source: str,
    user_id: str,
) -> str:
    if ticket_status not in {"", "active"} or scan_phase != "entry_pending":
        _log_scan(
            transaction,
            qr_id=qr_id,
            booking_id=booking_id,
            user_id=user_id,
            area_id=area_id,
            result=RESULT_USED,
            location_id=location_id,
            source=source,
            scan_phase=scan_phase,
            camera_type=CAMERA_ENTRY,
            message="Entry camera cannot process current scan phase.",
        )
        return RESULT_USED

    transaction.update(ticket_ref, {
        "scannedOnce": True,
        "entryScannedAt": firestore.SERVER_TIMESTAMP,
        "scanPhase": "entered",
        "updatedAt": firestore.SERVER_TIMESTAMP,
    })
    transaction.update(booking_ref, {
        "status": "active_parking",
        "entryVerified": True,
        "entryScannedAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    })
    _log_scan(
        transaction,
        qr_id=qr_id,
        booking_id=booking_id,
        user_id=user_id,
        area_id=area_id,
        result=RESULT_ENTRY,
        location_id=location_id,
        source=source,
        scan_phase="entered",
        camera_type=CAMERA_ENTRY,
    )
    return RESULT_ENTRY


def _handle_exit_camera(
    *,
    transaction: Transaction,
    ticket_ref: Any,
    booking_ref: Any,
    qr_id: str,
    booking_id: str,
    area_id: str,
    location_id: str,
    ticket_status: str,
    scan_phase: str,
    source: str,
    user_id: str,
) -> str:
    if ticket_status not in {"", "active"} or scan_phase not in {"entered", "exit_pending"}:
        _log_scan(
            transaction,
            qr_id=qr_id,
            booking_id=booking_id,
            user_id=user_id,
            area_id=area_id,
            result=RESULT_BEFORE_TIME if scan_phase == "entry_pending" else RESULT_USED,
            location_id=location_id,
            source=source,
            scan_phase=scan_phase,
            camera_type=CAMERA_EXIT,
            message="Exit camera cannot process current scan phase.",
        )
        return RESULT_BEFORE_TIME if scan_phase == "entry_pending" else RESULT_USED

    transaction.update(booking_ref, {
        "status": "completed",
        "exitScannedAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    })
    transaction.update(ticket_ref, {
        "scanPhase": "exited",
        "status": "used",
        "exitScannedAt": firestore.SERVER_TIMESTAMP,
        "completedAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    })
    if area_id:
        area_ref = get_firestore_client().collection("parking_areas").document(area_id)
        transaction.update(area_ref, {
            "availableSpaces": firestore.Increment(1),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        })
    _log_scan(
        transaction,
        qr_id=qr_id,
        booking_id=booking_id,
        user_id=user_id,
        area_id=area_id,
        result=RESULT_EXIT,
        location_id=location_id,
        source=source,
        scan_phase="exited",
        camera_type=CAMERA_EXIT,
    )
    return RESULT_EXIT


def get_ticket_debug_summary(qr_id: str) -> dict[str, Any]:
    """Return a safe ticket/booking summary for Streamlit debugging."""

    qr_id = (qr_id or "").strip()
    if not _is_valid_qr_id(qr_id):
        return {"validQrId": False}

    db = get_firestore_client()
    ticket_snapshot = db.collection("active_qr_tickets").document(qr_id).get()
    if not ticket_snapshot.exists:
        return {"validQrId": True, "ticketExists": False}

    ticket = ticket_snapshot.to_dict() or {}
    booking_id = str(ticket.get("bookingId") or "")
    booking: dict[str, Any] = {}
    if booking_id:
        booking_snapshot = db.collection("bookings").document(booking_id).get()
        if booking_snapshot.exists:
            booking = booking_snapshot.to_dict() or {}

    return {
        "validQrId": True,
        "ticketExists": True,
        "qrId": qr_id,
        "ticketStatus": ticket.get("status"),
        "scanPhase": ticket.get("scanPhase"),
        "scannedOnce": ticket.get("scannedOnce"),
        "areaId": ticket.get("areaId") or booking.get("areaId") or booking.get("parkingLocationId"),
        "bookingId": booking_id or None,
        "bookingExists": bool(booking),
        "bookingStatus": booking.get("status"),
        "bookingStartAt": _display_time(ticket.get("bookingStartAt") or booking.get("bookingStartAt") or booking.get("startTime")),
        "bookingEndAt": _display_time(ticket.get("bookingEndAt") or booking.get("bookingEndAt") or booking.get("endTime")),
        "entryScannedAt": _display_time(ticket.get("entryScannedAt") or booking.get("entryScannedAt")),
        "exitScannedAt": _display_time(ticket.get("exitScannedAt") or booking.get("exitScannedAt")),
    }


def list_parking_areas(limit: int = 100) -> list[ParkingAreaOption]:
    db = get_firestore_client()
    options: list[ParkingAreaOption] = []
    for snapshot in db.collection("parking_areas").limit(limit).stream():
        data = snapshot.to_dict() or {}
        area_id = str(data.get("areaId") or snapshot.id)
        name = str(data.get("name") or area_id)
        region_id = str(data.get("regionId") or "")
        options.append(ParkingAreaOption(area_id=area_id, name=name, region_id=region_id))
    return sorted(options, key=lambda item: item.label.lower())


def latest_scan_logs(limit: int = 20) -> list[dict[str, Any]]:
    db = get_firestore_client()
    snapshots = db.collection("qr_scan_logs").limit(limit).stream()
    logs: list[dict[str, Any]] = []
    for snapshot in snapshots:
        data = snapshot.to_dict() or {}
        logs.append(
            {
                "result": data.get("result"),
                "qrId": data.get("qrId"),
                "bookingId": data.get("bookingId"),
                "areaId": data.get("areaId"),
                "locationId": data.get("locationId"),
                "cameraType": data.get("cameraType"),
                "source": data.get("source"),
                "scannedAt": _display_time(data.get("scannedAt")),
                "message": data.get("message"),
            }
        )
    return logs


def _is_valid_qr_id(qr_id: str) -> bool:
    if not qr_id or qr_id.startswith("{") or qr_id.startswith("[") or "://" in qr_id:
        return False
    if len(qr_id) < 8 or len(qr_id) > 96:
        return False
    return all(ch.isalnum() or ch in {"_", "-"} for ch in qr_id)


def _normalize_camera_type(camera_type: str) -> str:
    value = (camera_type or CAMERA_ENTRY).strip().lower()
    if value in {"entry", "entry_camera", "entry camera"}:
        return CAMERA_ENTRY
    if value in {"exit", "exit_camera", "exit camera"}:
        return CAMERA_EXIT
    return value


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


def _display_time(value: Any) -> str | None:
    if value is None:
        return None
    try:
        return _to_utc(value).isoformat()
    except Exception:
        return str(value)


def _log_scan(
    transaction: Transaction,
    *,
    qr_id: str,
    result: str,
    booking_id: str | None = None,
    user_id: str | None = None,
    area_id: str | None = None,
    location_id: str = "",
    source: str = LOG_SOURCE,
    scan_phase: str = "",
    camera_type: str = "",
    message: str = "",
) -> None:
    db = get_firestore_client()
    log_ref = db.collection("qr_scan_logs").document(str(uuid.uuid4()))
    transaction.set(
        log_ref,
        {
            "qrId": qr_id,
            "bookingId": booking_id,
            "userId": user_id,
            "areaId": area_id,
            "result": result,
            "scanPhase": scan_phase,
            "scannedAt": firestore.SERVER_TIMESTAMP,
            "source": source,
            "locationId": location_id,
            "cameraType": camera_type,
            "message": message,
        },
    )
