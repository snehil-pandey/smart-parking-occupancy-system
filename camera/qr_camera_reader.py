"""Laptop camera QR reader for Park Here ESP32 gate testing.

The reader decodes QR ids from the local webcam and forwards them to the ESP32
`/scan` endpoint. The ESP32 then calls the Flask verifier, so this path tests
the same buzzer/LED flow as a physical gate scan.
"""

from __future__ import annotations

import argparse
import time

import cv2
import numpy as np
import requests


def start_camera_scanner(esp32_url: str, cooldown_seconds: float = 5.0) -> None:
    cap = cv2.VideoCapture(0)
    detector = cv2.QRCodeDetector()

    print("Park Here QR camera reader active.")
    print(f"Forwarding scans to: {esp32_url}")
    print("Press SPACEBAR to pause/unpause the camera.")
    print("Press Q to quit.")

    last_scanned = ""
    cooldown_until = 0.0
    is_paused = False

    while True:
        if is_paused:
            frame = np.zeros((480, 640, 3), dtype=np.uint8)
            cv2.putText(frame, "CAMERA PAUSED", (170, 240), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
            cv2.putText(frame, "Press SPACEBAR to resume", (145, 280), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 1)
            cv2.imshow("Park Here - Gate QR Reader", frame)
        else:
            ok, frame = cap.read()
            if not ok:
                print("Failed to read from camera.")
                break

            try:
                data, _, _ = detector.detectAndDecode(frame)
            except cv2.error:
                data = ""

            now = time.time()
            if data and (data != last_scanned or now >= cooldown_until):
                print(f"Scanned QR: {data}")
                last_scanned = data
                cooldown_until = now + cooldown_seconds
                _send_to_gate(esp32_url, data)

            cv2.imshow("Park Here - Gate QR Reader", frame)

        key = cv2.waitKey(1) & 0xFF
        if key == ord("q"):
            break
        if key == 32:
            is_paused = not is_paused
            if is_paused:
                cap.release()
                print("Camera paused.")
            else:
                cap = cv2.VideoCapture(0)
                print("Camera resumed.")

    if cap.isOpened():
        cap.release()
    cv2.destroyAllWindows()


def _send_to_gate(esp32_url: str, qr_id: str) -> None:
    try:
        response = requests.get(esp32_url, params={"id": qr_id}, timeout=8)
        print(f"Gate response: {response.text.strip()}")
    except requests.RequestException as exc:
        print(f"Network error: could not reach ESP32 gate: {exc}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Read QR ids from webcam and forward them to an ESP32 gate.")
    parser.add_argument("--esp32-url", default="http://192.168.4.1/scan", help="ESP32 scan endpoint URL.")
    parser.add_argument("--cooldown", type=float, default=5.0, help="Duplicate scan cooldown in seconds.")
    args = parser.parse_args()
    start_camera_scanner(args.esp32_url, args.cooldown)


if __name__ == "__main__":
    main()
