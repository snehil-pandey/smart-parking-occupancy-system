"""Streamlit QR scan simulator and ESP32 config panel for Park Here gates."""

from __future__ import annotations

from urllib.parse import urlparse

import requests
import streamlit as st

from firebase_service import (
    RESULT_BEFORE_TIME,
    RESULT_ENTRY,
    RESULT_ERROR,
    RESULT_EXIT,
    RESULT_EXPIRED,
    RESULT_INVALID,
    RESULT_USED,
    firebase_project_id,
    get_ticket_debug_summary,
    latest_scan_logs,
    list_parking_areas,
    verify_qr_scan,
)


RESULT_HELP = {
    RESULT_ENTRY: "Entry accepted. Booking is now active parking.",
    RESULT_EXIT: "Exit accepted. Booking is now completed.",
    RESULT_BEFORE_TIME: "QR is valid, but the booking unlock window has not started.",
    RESULT_USED: "QR was already used or the entry phase is no longer pending.",
    RESULT_EXPIRED: "QR or booking has expired.",
    RESULT_INVALID: "QR, booking, status, or scanner location did not pass validation.",
    RESULT_ERROR: "Verification failed. Check server logs and Firebase config.",
}


def main() -> None:
    st.set_page_config(page_title="Park Here QR Bridge", page_icon="P", layout="wide")
    st.title("Park Here QR Bridge")
    st.caption("Location-wise Streamlit simulator and ESP32 gate configuration.")

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
    with st.form("scan_form"):
        qr_id = st.text_input("QR id", placeholder="qr_live_...")
        scan_mode = st.radio("Scan mode", ["entry", "exit"], horizontal=True)
        submitted = st.form_submit_button("Simulate Scan", type="primary")

    if not submitted:
        st.caption("Scan flow: selected parking area -> qrId input -> Simulate Scan.")
        return

    if not selected_area_id:
        st.error("Select a scanner parking area before scanning.")
        return
    if not qr_id.strip():
        st.error("Enter a QR id first.")
        return

    with st.spinner("Verifying QR through Firebase transaction..."):
        result = verify_qr_scan(qr_id=qr_id, location_id=selected_area_id, mode=scan_mode)
    _show_result(result)
    st.subheader("Ticket / booking summary")
    st.json(get_ticket_debug_summary(qr_id), expanded=False)


def _esp32_config_panel(selected_area_id: str) -> None:
    st.subheader("ESP32 Configuration")
    st.write("Use this to update a gate device after it is reachable on the same network.")

    with st.form("esp_config_form"):
        esp_ip = st.text_input("ESP32 IP address", placeholder="192.168.1.44")
        wifi_ssid = st.text_input("WiFi SSID")
        wifi_password = st.text_input("WiFi Password", type="password")
        python_server_ip = st.text_input("Python Server IP", placeholder="192.168.1.10")
        location_id = st.text_input(
            "Parking Area / Location ID",
            value=selected_area_id,
            placeholder="area_sit_main_lot",
        )
        col1, col2, col3 = st.columns(3)
        update_clicked = col1.form_submit_button("Update ESP32 Config", type="primary")
        status_clicked = col2.form_submit_button("Check ESP32 Status")
        reset_clicked = col3.form_submit_button("Reset ESP32 Config")

    if update_clicked:
        if not esp_ip.strip():
            st.error("Enter the ESP32 IP address.")
            return
        payload = {
            "ssid": wifi_ssid,
            "password": wifi_password,
            "serverIp": python_server_ip,
            "locationId": location_id,
        }
        _post_esp_json(esp_ip, "/config", payload)

    if status_clicked:
        if not esp_ip.strip():
            st.error("Enter the ESP32 IP address.")
            return
        _get_esp_status(esp_ip)

    if reset_clicked:
        if not esp_ip.strip():
            st.error("Enter the ESP32 IP address.")
            return
        _post_esp_json(esp_ip, "/reset-config", {})


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
    elif result == RESULT_BEFORE_TIME:
        st.warning(f"{result}: {message}")
    elif result in {RESULT_USED, RESULT_EXPIRED, RESULT_INVALID}:
        st.error(f"{result}: {message}")
    else:
        st.error(f"{RESULT_ERROR}: {message}")


def _esp_base_url(esp_ip: str) -> str:
    value = esp_ip.strip()
    if not value:
        raise ValueError("ESP32 IP is required.")
    parsed = urlparse(value)
    if parsed.scheme:
        return value.rstrip("/")
    return f"http://{value}"


def _post_esp_json(esp_ip: str, path: str, payload: dict[str, str]) -> None:
    try:
        response = requests.post(f"{_esp_base_url(esp_ip)}{path}", json=payload, timeout=8)
        if response.ok:
            st.success(response.text or "ESP32 command accepted.")
        else:
            st.error(f"ESP32 returned {response.status_code}: {response.text}")
    except requests.RequestException as exc:
        st.error("Could not reach ESP32.")
        st.caption(str(exc))


def _get_esp_status(esp_ip: str) -> None:
    try:
        response = requests.get(f"{_esp_base_url(esp_ip)}/status", timeout=8)
        if response.ok:
            st.code(response.text, language="text")
        else:
            st.error(f"ESP32 returned {response.status_code}: {response.text}")
    except requests.RequestException as exc:
        st.error("Could not reach ESP32.")
        st.caption(str(exc))


if __name__ == "__main__":
    main()
