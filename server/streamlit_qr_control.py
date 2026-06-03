"""Streamlit QR scan simulator and ESP32 config panel for Park Here gates."""

from __future__ import annotations

from io import BytesIO
from urllib.parse import urlparse

import requests
import streamlit as st

from firebase_service import (
    RESULT_ENTRY,
    RESULT_ERROR,
    RESULT_EXIT,
    RESULT_EXPIRED,
    RESULT_INVALID,
    firebase_project_id,
    get_ticket_debug_summary,
    latest_scan_logs,
    list_parking_areas,
    verify_qr_scan,
)


RESULT_HELP = {
    RESULT_ENTRY: "Entry accepted. Booking is now active parking.",
    RESULT_EXIT: "Exit accepted. Booking is now completed.",
    RESULT_EXPIRED: "Parking session is completed or the QR/booking has expired.",
    RESULT_INVALID: "QR, booking, status, or scanner location did not pass validation.",
    RESULT_ERROR: "Verification failed. Check server logs and Firebase config.",
}


def main() -> None:
    st.set_page_config(page_title="Park Here QR Bridge", page_icon="P", layout="wide")
    st.title("Park Here QR Bridge")
    st.caption("Location-wise Streamlit simulator and wireless ESP32 gate configuration.")

    try:
        project_id = firebase_project_id()
        st.success(f"Connected to Firebase project: {project_id}")
    except Exception as exc:
        st.error("Unable to connect to Park Here Firebase services.")
        st.caption(str(exc))
        return

    areas = list_parking_areas()
    selected_area_id = _select_scanner_location(areas)

    scan_tab, esp_tab, logs_tab = st.tabs(["Simulate Scan", "ESP32 Configuration", "Scan Logs"])
    with scan_tab:
        _scan_panel(selected_area_id)
    with esp_tab:
        _esp32_config_panel(selected_area_id)
    with logs_tab:
        _scan_logs_panel()


def _select_scanner_location(areas: list) -> str:
    st.header("Select Scanner Location")
    st.write("This simulates a physical QR scanner installed at one parking area.")
    if not areas:
        manual = st.text_input("No Firebase parking areas found. Enter locationId manually.")
        return manual.strip()

    labels = [area.label for area in areas]
    selected_label = st.selectbox("Parking area", labels)
    selected_area = areas[labels.index(selected_label)]
    st.session_state["selected_area_id"] = selected_area.area_id
    st.info(f"Current scanner locationId: {selected_area.area_id}")
    return selected_area.area_id


def _scan_panel(selected_area_id: str) -> None:
    st.subheader("Simulate QR Scan")
    st.caption(
        "This panel performs location-based QR verification against Firebase. "
        "Ticket status decides whether the scan is entry or exit."
    )

    decoded_qr = ""
    camera_image = st.camera_input("Scan QR using this device camera")
    if camera_image is not None:
        decoded_qr = _decode_qr_from_camera(camera_image)
        if decoded_qr:
            st.success("QR detected from camera image.")
        else:
            st.warning("Camera image captured, but no QR code was detected.")

    qr_id = st.text_input("QR id", value=decoded_qr, placeholder="qr_live_...")
    submitted = st.button("Simulate Scan", type="primary")

    if not submitted:
        st.caption("Scan flow: selected parking area -> qrId -> Firebase verification.")
        return

    if not selected_area_id:
        st.error("Select a scanner parking area before scanning.")
        return
    if not qr_id.strip():
        st.error("Enter a QR id first.")
        return

    with st.spinner("Verifying QR through Firebase transaction..."):
        result = verify_qr_scan(
            qr_id=qr_id,
            location_id=selected_area_id,
            source="streamlit_simulator",
        )
    _show_result(result)
    st.subheader("Ticket / booking summary")
    summary = get_ticket_debug_summary(qr_id)
    _show_phase_summary(summary)
    st.json(summary, expanded=False)


def _esp32_config_panel(selected_area_id: str) -> None:
    st.subheader("ESP32 Gate Configuration")
    st.info("Laptop must be connected to SIT-SmartGate WiFi before using these controls.")

    esp_ip = st.text_input("ESP32 IP address", value="192.168.4.1")
    python_server_ip = st.text_input("Python Server IP", value="192.168.4.2")
    location_id = st.text_input(
        "Parking Location ID",
        value=selected_area_id or "loc_1779943110578",
        help="Loaded from Firebase parking_areas when available; edit manually as a fallback.",
    )
    col1, col2, col3 = st.columns(3)
    update_clicked = col1.button("Update ESP32 Config", type="primary")
    status_clicked = col2.button("Check ESP32 Status")
    reset_clicked = col3.button("Reset ESP32 Config")

    if update_clicked:
        if not esp_ip.strip():
            st.error("Enter the ESP32 IP address.")
            return
        _update_esp32_config(esp_ip, python_server_ip, location_id)

    if status_clicked:
        if not esp_ip.strip():
            st.error("Enter the ESP32 IP address.")
            return
        _get_esp_status(esp_ip)

    if reset_clicked:
        if not esp_ip.strip():
            st.error("Enter the ESP32 IP address.")
            return
        _reset_esp32_config(esp_ip)


def _scan_logs_panel() -> None:
    st.subheader("Latest scan logs")
    try:
        logs = latest_scan_logs(limit=20)
        if logs:
            st.dataframe(logs, use_container_width=True)
        else:
            st.info("No scan logs found yet.")
    except Exception as exc:
        st.warning("Unable to load scan logs.")
        st.caption(str(exc))


def _show_result(result: str) -> None:
    message = RESULT_HELP.get(result, "Unknown verifier response.")
    if result in {RESULT_ENTRY, RESULT_EXIT}:
        st.success(f"{result}: {message}")
    elif result in {RESULT_EXPIRED, RESULT_INVALID}:
        st.error(f"{result}: {message}")
    else:
        st.error(f"{RESULT_ERROR}: {message}")


def _show_phase_summary(summary: dict) -> None:
    ticket_status = summary.get("ticketStatus")
    status = summary.get("bookingStatus")
    entry_at = summary.get("entryScannedAt")
    exit_at = summary.get("exitScannedAt")
    if not summary.get("ticketExists"):
        return

    if ticket_status == "active":
        st.info("Status: active. Next valid scan is ENTRY.")
    elif ticket_status == "entry_verified":
        st.info("Status: entry verified. Next valid scan is EXIT.")
    elif ticket_status == "completed" or status == "completed" or exit_at:
        st.success("Phase: parking session completed.")
    elif ticket_status == "expired" or status == "expired":
        st.warning("Phase: expired.")
    elif ticket_status == "cancelled":
        st.warning("Phase: cancelled.")
    else:
        st.info(f"Status: {ticket_status or 'unknown'}")

    if entry_at:
        st.caption(f"Entry scanned at: {entry_at}")
    if exit_at:
        st.caption(f"Exit scanned at: {exit_at}")


def _esp_base_url(esp_ip: str) -> str:
    value = esp_ip.strip()
    if not value:
        raise ValueError("ESP32 IP is required.")
    parsed = urlparse(value)
    if parsed.scheme:
        return value.rstrip("/")
    return f"http://{value}"


def _update_esp32_config(esp_ip: str, python_server_ip: str, location_id: str) -> None:
    try:
        url = f"{_esp_base_url(esp_ip)}/update_config"
        params = {
            "serverIp": python_server_ip.strip(),
            "locationId": location_id.strip(),
        }
        response = requests.get(url, params=params, timeout=5)

        if response.status_code == 200:
            st.success("Configuration successfully sent to Gate memory!")
        else:
            st.error("Failed to update.")
            st.caption(f"ESP32 returned {response.status_code}: {response.text}")
    except requests.RequestException as exc:
        st.error(
            "Could not reach ESP32. Ensure laptop is connected to SIT-SmartGate Wi-Fi. Error: "
            f"{exc}"
        )


def _get_esp_status(esp_ip: str) -> None:
    try:
        response = requests.get(f"{_esp_base_url(esp_ip)}/status", timeout=8)
        if response.ok:
            try:
                st.json(response.json())
            except ValueError:
                st.code(response.text, language="text")
        else:
            st.error(f"ESP32 returned {response.status_code}: {response.text}")
    except requests.RequestException as exc:
        st.error("Could not reach ESP32.")
        st.caption(str(exc))


def _reset_esp32_config(esp_ip: str) -> None:
    try:
        response = requests.get(f"{_esp_base_url(esp_ip)}/reset_config", timeout=8)
        if response.ok:
            st.success(response.text or "ESP32 config reset.")
        else:
            st.error(f"ESP32 returned {response.status_code}: {response.text}")
    except requests.RequestException as exc:
        st.error("Could not reach ESP32.")
        st.caption(str(exc))


def _decode_qr_from_camera(camera_image: BytesIO) -> str:
    try:
        import cv2
        import numpy as np
    except ImportError:
        st.warning("Install opencv-python-headless to decode camera QR images.")
        return ""

    image_bytes = camera_image.getvalue()
    image_array = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
    if image is None:
        return ""

    detector = cv2.QRCodeDetector()
    decoded_text, _, _ = detector.detectAndDecode(image)
    return decoded_text.strip()


if __name__ == "__main__":
    main()
