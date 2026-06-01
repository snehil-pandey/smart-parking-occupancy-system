#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <ctype.h>

const char* SETUP_AP_SSID = "ParkHere-Gate-Setup";
const char* SETUP_AP_PASSWORD = "parkhere123";
const int BUZZER_PIN = 25;
const unsigned long WIFI_CONNECT_TIMEOUT_MS = 15000;

WebServer server(80);
Preferences preferences;

String wifiSsid;
String wifiPassword;
String pythonServerBaseUrl;
String defaultLocationId;
bool setupMode = false;

void beep(int durationMs) {
  digitalWrite(BUZZER_PIN, HIGH);
  delay(durationMs);
  digitalWrite(BUZZER_PIN, LOW);
}

void beepShort() {
  beep(120);
}

void beepLong() {
  beep(650);
}

void beepExit() {
  beepShort();
  delay(140);
  beepShort();
}

void beepError() {
  beep(900);
}

String htmlEscape(String value) {
  value.replace("&", "&amp;");
  value.replace("<", "&lt;");
  value.replace(">", "&gt;");
  value.replace("\"", "&quot;");
  return value;
}

String urlEncode(String value) {
  String encoded = "";
  const char* hex = "0123456789ABCDEF";
  for (size_t i = 0; i < value.length(); i++) {
    unsigned char c = value.charAt(i);
    if (isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~') {
      encoded += char(c);
    } else {
      encoded += '%';
      encoded += hex[(c >> 4) & 0x0F];
      encoded += hex[c & 0x0F];
    }
  }
  return encoded;
}

String normalizeServerBaseUrl(String serverInput) {
  serverInput.trim();
  if (serverInput.length() == 0) {
    return "";
  }
  if (serverInput.startsWith("http://") || serverInput.startsWith("https://")) {
    return serverInput;
  }
  return "http://" + serverInput + ":5000";
}

void loadConfig() {
  preferences.begin("parkhere-gate", false);
  wifiSsid = preferences.getString("wifiSsid", "");
  wifiPassword = preferences.getString("wifiPass", "");
  pythonServerBaseUrl = preferences.getString("serverUrl", "");
  defaultLocationId = preferences.getString("locationId", "");

  Serial.println("Loaded Park Here gate configuration.");
  Serial.print("Saved WiFi SSID: ");
  Serial.println(wifiSsid.length() > 0 ? wifiSsid : "(none)");
  Serial.print("Python server: ");
  Serial.println(pythonServerBaseUrl.length() > 0 ? pythonServerBaseUrl : "(none)");
  Serial.print("Default locationId: ");
  Serial.println(defaultLocationId.length() > 0 ? defaultLocationId : "(none)");
}

void saveConfig(String ssid, String password, String serverInput, String locationId) {
  ssid.trim();
  serverInput.trim();
  locationId.trim();

  wifiSsid = ssid;
  wifiPassword = password;
  pythonServerBaseUrl = normalizeServerBaseUrl(serverInput);
  defaultLocationId = locationId;

  preferences.putString("wifiSsid", wifiSsid);
  preferences.putString("wifiPass", wifiPassword);
  preferences.putString("serverUrl", pythonServerBaseUrl);
  preferences.putString("locationId", defaultLocationId);
}

void clearConfig() {
  Serial.println("Clearing saved Park Here gate configuration.");
  preferences.clear();
  wifiSsid = "";
  wifiPassword = "";
  pythonServerBaseUrl = "";
  defaultLocationId = "";
}

bool hasRequiredConfig() {
  return wifiSsid.length() > 0 &&
         pythonServerBaseUrl.length() > 0 &&
         defaultLocationId.length() > 0;
}

bool connectToSavedWifi() {
  if (wifiSsid.length() == 0) {
    Serial.println("No saved WiFi credentials found.");
    return false;
  }

  Serial.print("Connecting to saved WiFi SSID: ");
  Serial.println(wifiSsid);
  WiFi.mode(WIFI_STA);
  WiFi.begin(wifiSsid.c_str(), wifiPassword.c_str());

  const unsigned long startedAt = millis();
  while (WiFi.status() != WL_CONNECTED &&
         millis() - startedAt < WIFI_CONNECT_TIMEOUT_MS) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WiFi connected.");
    Serial.print("Gate local IP: ");
    Serial.println(WiFi.localIP());
    return true;
  }

  Serial.println("Saved WiFi connection failed. Starting setup AP.");
  WiFi.disconnect(true);
  return false;
}

void startSetupAccessPoint() {
  setupMode = true;
  WiFi.mode(WIFI_AP);
  WiFi.softAP(SETUP_AP_SSID, SETUP_AP_PASSWORD);

  Serial.println("Park Here gate setup mode started.");
  Serial.print("AP SSID: ");
  Serial.println(SETUP_AP_SSID);
  Serial.print("AP password: ");
  Serial.println(SETUP_AP_PASSWORD);
  Serial.print("Open setup page: http://");
  Serial.println(WiFi.softAPIP());
}

void sendConfigPage(String message = "") {
  const String ipText = setupMode ? WiFi.softAPIP().toString() : WiFi.localIP().toString();
  String page = "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>";
  page += "<title>Park Here Gate Setup</title>";
  page += "<style>body{font-family:Arial,sans-serif;background:#fff8dc;color:#111827;margin:0;padding:24px;}";
  page += ".card{max-width:560px;margin:auto;background:#fff;border:2px solid #111827;border-radius:10px;padding:20px;box-shadow:6px 6px 0 #facc15;}";
  page += "label{display:block;font-weight:700;margin-top:14px;}input{width:100%;box-sizing:border-box;padding:11px;margin-top:6px;border:1px solid #9ca3af;border-radius:6px;font-size:16px;}";
  page += "button,.button{display:inline-block;margin-top:18px;background:#111827;color:#facc15;border:0;border-radius:6px;padding:12px 16px;font-weight:800;text-decoration:none;}";
  page += ".muted{color:#4b5563}.warn{background:#fee2e2;padding:10px;border-radius:6px;}</style></head><body><div class='card'>";
  page += "<h1>Park Here Gate Setup</h1>";
  page += "<p class='muted'>Device IP: " + htmlEscape(ipText) + "</p>";
  if (message.length() > 0) {
    page += "<p class='warn'>" + htmlEscape(message) + "</p>";
  }
  page += "<form method='POST' action='/save-config'>";
  page += "<label>WiFi SSID</label><input name='ssid' value='" + htmlEscape(wifiSsid) + "' required>";
  page += "<label>WiFi password</label><input name='password' type='password' value='" + htmlEscape(wifiPassword) + "'>";
  page += "<label>Python server IP or URL</label><input name='server' placeholder='192.168.1.10 or http://192.168.1.10:5000' value='" + htmlEscape(pythonServerBaseUrl) + "' required>";
  page += "<label>Parking area locationId</label><input name='locationId' placeholder='area_sit_main_lot' value='" + htmlEscape(defaultLocationId) + "' required>";
  page += "<button type='submit'>Save and restart</button></form>";
  page += "<a class='button' href='/status'>Status</a> ";
  page += "<a class='button' href='/reset-config' onclick=\"return confirm('Clear saved config and restart setup mode?')\">Reset config</a>";
  page += "</div></body></html>";
  server.send(200, "text/html", page);
}

void handleRoot() {
  sendConfigPage();
}

void handleSaveConfig() {
  if (!server.hasArg("ssid") ||
      !server.hasArg("server") ||
      !server.hasArg("locationId")) {
    server.send(400, "text/plain", "Missing required config fields.");
    return;
  }

  saveConfig(
    server.arg("ssid"),
    server.arg("password"),
    server.arg("server"),
    server.arg("locationId")
  );

  Serial.println("Saved new Park Here gate configuration. Restarting...");
  server.send(200, "text/html", "<p>Configuration saved. Restarting gate...</p>");
  delay(800);
  ESP.restart();
}

void handleResetConfig() {
  clearConfig();
  server.send(200, "text/html", "<p>Configuration cleared. Restarting setup mode...</p>");
  delay(800);
  ESP.restart();
}

void handleStatus() {
  String status = "mode=" + String(setupMode ? "setup_ap" : "gate") + "\n";
  status += "wifiStatus=" + String(WiFi.status() == WL_CONNECTED ? "connected" : "not_connected") + "\n";
  status += "ssid=" + (WiFi.status() == WL_CONNECTED ? WiFi.SSID() : wifiSsid) + "\n";
  status += "localIp=" + String(setupMode ? WiFi.softAPIP().toString() : WiFi.localIP().toString()) + "\n";
  status += "server=" + pythonServerBaseUrl + "\n";
  status += "locationId=" + defaultLocationId + "\n";
  server.send(200, "text/plain", status);
}

void handleHealth() {
  server.send(200, "text/plain", "OK");
}

void handleScan() {
  if (setupMode || pythonServerBaseUrl.length() == 0) {
    beepError();
    server.send(503, "text/plain", "ERROR");
    return;
  }

  String qrId = server.arg("id");
  qrId.trim();
  String locationId = server.arg("locationId");
  locationId.trim();
  if (locationId.length() == 0) {
    locationId = defaultLocationId;
  }
  String mode = server.arg("mode");
  mode.trim();

  if (qrId.length() == 0 || locationId.length() == 0) {
    beepError();
    server.send(400, "text/plain", "INVALID");
    return;
  }

  String url = pythonServerBaseUrl + "/verify?id=" + urlEncode(qrId);
  url += "&locationId=" + urlEncode(locationId);
  if (mode.length() > 0) {
    url += "&mode=" + urlEncode(mode);
  }

  Serial.print("Verifying QR through Python server: ");
  Serial.println(url);

  HTTPClient http;
  http.begin(url);
  int statusCode = http.GET();
  String result = statusCode > 0 ? http.getString() : "ERROR";
  result.trim();
  http.end();

  Serial.print("Python verification result: ");
  Serial.println(result);

  if (result == "ENTRY") {
    beepShort();
  } else if (result == "EXIT") {
    beepExit();
  } else if (result == "BEFORE_TIME") {
    beepLong();
  } else {
    beepError();
  }

  server.send(200, "text/plain", result);
}

void registerRoutes() {
  server.on("/", HTTP_GET, handleRoot);
  server.on("/save-config", HTTP_POST, handleSaveConfig);
  server.on("/reset-config", HTTP_GET, handleResetConfig);
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/health", HTTP_GET, handleHealth);
  server.on("/scan", HTTP_GET, handleScan);
}

void setup() {
  Serial.begin(115200);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  Serial.println();
  Serial.println("Starting Park Here ESP32 QR gate...");
  loadConfig();

  if (hasRequiredConfig() && connectToSavedWifi()) {
    setupMode = false;
    Serial.println("Normal gate mode ready.");
  } else {
    startSetupAccessPoint();
  }

  registerRoutes();
  server.begin();
  Serial.println("HTTP server started.");
}

void loop() {
  server.handleClient();
}
