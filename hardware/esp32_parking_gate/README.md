# ESP32 Park Here Gate

This sketch lets an ESP32 act as a simple Park Here QR gate bridge. It does not control a servo or camera yet. It accepts a scanned/passed `qrId`, calls the Python verification server, and plays buzzer patterns.

## First-Time Setup

1. Upload `park_here_gate.ino` to the ESP32.
2. Open the Serial Monitor at `115200`.
3. On first boot, or when saved WiFi fails, the ESP32 starts setup mode:

```text
SSID: ParkHere-Gate-Setup
Password: parkhere123
Setup page: http://192.168.4.1
```

4. Connect a phone/laptop to `ParkHere-Gate-Setup`.
5. Open `http://192.168.4.1`.
6. Enter:
   - WiFi SSID
   - WiFi password
   - Python server IP or URL
   - parking area `locationId`
7. Tap **Save and restart**.

The ESP32 stores this configuration in Preferences/NVS. No WiFi SSID or password needs to be hardcoded in the sketch.

## Python Server Field

The setup page accepts either a raw IP address or a full URL.

```text
192.168.1.10
http://192.168.1.10:5000
```

If only an IP address is entered, the ESP32 converts it to:

```text
http://<ip>:5000
```

## Normal Gate Mode

On boot, the ESP32:

1. Reads saved WiFi/server/location config from NVS.
2. Tries to connect to saved WiFi.
3. Starts the QR gate HTTP server if WiFi connects.
4. Falls back to setup AP mode if credentials are missing or connection fails.

## Endpoints

The ESP32 exposes:

```text
GET /scan?id=<qrId>
GET /scan?id=<qrId>&locationId=<parkingAreaId>
GET /scan?id=<qrId>&locationId=<parkingAreaId>&mode=exit
GET /status
GET /reset-config
```

If `locationId` is omitted from `/scan`, the ESP32 uses the saved default parking area/location id.

The ESP32 forwards verification to:

```text
GET <PYTHON_SERVER_BASE_URL>/verify?id=<qrId>&locationId=<parkingAreaId>
```

Exit checks forward:

```text
GET <PYTHON_SERVER_BASE_URL>/verify?id=<qrId>&locationId=<parkingAreaId>&mode=exit
```

## Status

Open:

```text
http://<esp32-ip>/status
```

It returns plain text showing:

- setup/gate mode
- WiFi connection state
- connected SSID
- ESP32 local IP
- Python server URL
- default `locationId`

## Reset / Change WiFi

To change WiFi, Python server IP, or `locationId`, open:

```text
http://<esp32-ip>/reset-config
```

The endpoint clears saved Preferences/NVS values and restarts the device. After restart, connect again to:

```text
ParkHere-Gate-Setup
```

Then open:

```text
http://192.168.4.1
```

## Beep Patterns

| Python result | Meaning | Buzzer |
| --- | --- | --- |
| `ENTRY` | Entry verified | One short beep |
| `EXIT` | Parking completed | Two short beeps |
| `BEFORE_TIME` | QR scanned too early | One long beep |
| `INVALID` / `USED` / `EXPIRED` / `ERROR` | Denied | Long error beep |

## Notes

- The QR payload must be only the opaque `qrId`.
- Firebase truth lives on the Python server, not on the ESP32.
- There is no camera requirement in this sketch. A serial QR reader, test client, or future hardware reader can call `/scan?id=<qrId>`.
- During development, use `server/streamlit_qr_control.py` to simulate scans before testing ESP32 hardware.
- The same QR cannot open entry twice. Normal repeat scans return `USED`.
- Exit is intentionally explicit through `mode=exit` so an accidental second entry scan cannot complete the booking.
- The current hardware path uses only a buzzer. Servo/gate motor control can be added later without changing the QR verification endpoint.
