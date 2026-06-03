"""Plain-text Flask endpoint for ESP32 Park Here QR verification."""

from __future__ import annotations

import os

from flask import Flask, Response, request

from firebase_service import RESULT_ERROR, RESULT_INVALID, verify_qr_scan


app = Flask(__name__)


@app.get("/health")
def health() -> Response:
    return _text("OK")


@app.get("/verify")
def verify() -> Response:
    qr_id = (request.args.get("id") or "").strip()
    location_id = (request.args.get("locationId") or "").strip()
    camera_type = (
        request.args.get("cameraType")
        or request.args.get("mode")
        or "entry"
    ).strip().lower()

    if not qr_id:
        return _text(RESULT_INVALID)

    try:
        return _text(
            verify_qr_scan(
                qr_id=qr_id,
                location_id=location_id,
                camera_type=camera_type,
                source="esp32_python_server",
            )
        )
    except Exception as exc:
        app.logger.exception("QR verification failed: %s", exc)
        return _text(RESULT_ERROR)


def _text(value: str) -> Response:
    return Response(value, mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")))
