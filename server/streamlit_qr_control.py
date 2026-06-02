"""Streamlit QR scan simulator for Park Here gate testing."""

from __future__ import annotations

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
    RESULT_INVALID: "QR, booking, or location did not pass validation.",
    RESULT_ERROR: "Verification failed. Check server logs and Firebase config.",
}


def main() -> None:
    st.set_page_config(page_title="Park Here QR Bridge", page_icon="P", layout="wide")
    st.title("Park Here QR Bridge")
    st.caption("Streamlit simulator for ESP32/Python QR gate verification.")

    try:
        project_id = firebase_project_id()
        st.success(f"Connected to Firebase project: {project_id}")
    except Exception as exc:
        st.error("Unable to connect to Park Here Firebase services.")
        st.caption(str(exc))
        return

    areas = list_parking_areas()
    area_labels = ["Manual locationId"] + [area.label for area in areas]

    with st.form("scan_form"):
        qr_id = st.text_input("QR id", placeholder="qr_live_...")
        selected_label = st.selectbox("Parking area / location", area_labels)
        manual_location = st.text_input("Manual locationId", placeholder="area_sit_main_lot")
        scan_mode = st.radio("Scan mode", ["entry", "exit"], horizontal=True)
        submitted = st.form_submit_button("Simulate Scan", type="primary")

    selected_area_id = ""
    if selected_label != "Manual locationId":
        selected_area_id = areas[area_labels.index(selected_label) - 1].area_id
    location_id = (manual_location or selected_area_id).strip()

    if submitted:
        if not qr_id.strip():
            st.error("Enter a QR id first.")
        elif not location_id:
            st.error("Choose or enter a parking area locationId.")
        else:
            with st.spinner("Verifying QR through Firebase transaction..."):
                result = verify_qr_scan(qr_id=qr_id, location_id=location_id, mode=scan_mode)
            _show_result(result)
            st.subheader("Ticket / booking summary")
            st.json(get_ticket_debug_summary(qr_id), expanded=False)

    st.divider()
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Current scanner context")
        st.write({"locationId": location_id or "(not selected)", "mode": scan_mode})
    with col2:
        st.subheader("Available result commands")
        st.write(list(RESULT_HELP.keys()))

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


if __name__ == "__main__":
    main()
