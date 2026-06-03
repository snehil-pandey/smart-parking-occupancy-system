# ESP32 Park Here Gate

This sketch lets an ESP32 act as a simple Park Here QR gate bridge. It does not control a servo or camera yet. It accepts a scanned/passed `qrId`, calls the Python verification server, and plays buzzer patterns.

## First-Time Setup

1. Upload `park_here_gate.ino` to the ESP32.
2. Open the Serial Monitor at `115200`.
3. On boot, the ESP32 starts its local setup/control access point:

```text
SSID: SIT-SmartGate
Password: parkhere123
Device IP: http://192.168.4.1
```

4. Connect a phone/laptop to `SIT-SmartGate`.
5. Run the Streamlit control app.
6. Open the **ESP32 Gate Configuration** tab.
7. Enter:
   - ESP32 IP address: `192.168.4.1`
   - Python server IP: `192.168.4.2` by default
   - parking area `locationId`
8. Click **Update ESP32 Config**.

The ESP32 stores `serverUrl` and `locationId` in Preferences/NVS. No Python server IP or parking area id needs to be hardcoded in the sketch.

## Python Server Field

The Streamlit config panel sends a raw Python server IP address.

```text
192.168.4.2
```

The ESP32 converts it to:

```text
http://<ip>:5000
```

## Normal Gate Mode

On boot, the ESP32:

1. Reads saved server/location config from NVS.
2. Starts the `SIT-SmartGate` access point.
3. Starts the QR gate HTTP server at `192.168.4.1`.
4. Uses defaults when no saved config exists:

```text
serverUrl: http://192.168.4.2:5000
locationId: loc_1779943110578
```

## Endpoints

The ESP32 exposes:

```text
GET /scan?id=<qrId>
GET /status
GET /update_config?serverIp=<ip>&locationId=<parkingAreaId>
GET /reset_config
GET /reset-config
```

`/scan` always uses the saved parking area/location id.

The ESP32 forwards verification to:

```text
GET <PYTHON_SERVER_BASE_URL>/verify?id=<qrId>&locationId=<parkingAreaId>
```

The Python bridge returns plain text commands consumed by the buzzer logic.

## Status

Open:

```text
http://<esp32-ip>/status
```

It returns JSON:

```json
{
  "status": "online",
  "locationId": "loc_1779943110578",
  "serverUrl": "http://192.168.4.2:5000",
  "apSsid": "SIT-SmartGate"
}
```

## Configure From Streamlit

When the laptop is connected to `SIT-SmartGate`, the Streamlit control panel can update gate configuration with:

```text
GET http://<esp32-ip>/update_config?serverIp=192.168.4.2&locationId=area_sit_main_lot
```

The ESP32 saves these values to Preferences/NVS and then uses the saved `locationId` for:

```text
GET /scan?id=<qrId>
```

That scan is forwarded to:

```text
GET http://<python-server-ip>:5000/verify?id=<qrId>&locationId=<saved-locationId>
```

## Reset / Change WiFi

To reset Python server IP and `locationId`, either use Streamlit or open:

```text
http://<esp32-ip>/reset_config
```

`/reset-config` is also accepted as a compatibility alias. The endpoint clears saved Preferences/NVS values and reloads defaults.

Then use `http://192.168.4.1/status` to confirm the defaults.

## Beep Patterns

| Python result | Meaning | Buzzer |
| --- | --- | --- |
| `ENTRY` | Entry verified | One short beep |
| `EXIT` | Parking completed | Two short beeps |
| `INVALID` / `EXPIRED` / `ERROR` | Denied | Long error beep |

## Notes

- The QR payload must be only the opaque `qrId`.
- Firebase truth lives on the Python server, not on the ESP32.
- There is no camera requirement in this sketch. A serial QR reader, test client, or future hardware reader can call `/scan?id=<qrId>`.
- During development, use `server/streamlit_qr_control.py` to simulate scans before testing ESP32 hardware.
- Scans are location-aware. A QR for one parking area is rejected when scanned at a different saved `locationId`.
- The same QR performs entry first, then exit on the next valid scan.
- The current ESP32 `/scan` flow is location-based and does not pass camera type.
- The current hardware path uses only a buzzer. Servo/gate motor control can be added later without changing the QR verification endpoint.
