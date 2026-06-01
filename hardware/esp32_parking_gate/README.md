# ESP32 Park Here Gate

This sketch lets an ESP32 act as a simple Park Here QR gate bridge. It does not control a servo yet. It only calls the Python verification server and plays buzzer patterns.

## Endpoints

The ESP32 exposes:

```text
GET /scan?id=<qrId>&locationId=<parkingAreaId>
```

For exit checks:

```text
GET /scan?id=<qrId>&locationId=<parkingAreaId>&mode=exit
```

The ESP32 forwards the request to:

```text
GET <PYTHON_SERVER_BASE_URL>/verify?id=<qrId>&locationId=<parkingAreaId>
```

## Beep Patterns

| Python result | Meaning | Buzzer |
| --- | --- | --- |
| `ENTRY` | Entry verified | One short beep |
| `EXIT` | Parking completed | Two short beeps |
| `BEFORE_TIME` | QR scanned too early | One long beep |
| `INVALID` / `USED` / `EXPIRED` / `ERROR` | Denied | Long error beep |

## Configuration

Edit these values in `park_here_gate.ino`:

```cpp
const char* WIFI_SSID = "YOUR_WIFI_NAME";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char* PYTHON_SERVER_BASE_URL = "http://YOUR_SERVER_IP:5000";
const int BUZZER_PIN = 25;
```

Upload with the Arduino IDE or PlatformIO after installing ESP32 board support.

## Notes

- The QR payload must be only the opaque `qrId`.
- Firebase truth lives on the Python server, not on the ESP32.
- The same QR cannot open entry twice. Normal repeat scans return `USED`.
- Exit is intentionally explicit through `mode=exit` so an accidental second entry scan cannot complete the booking.
