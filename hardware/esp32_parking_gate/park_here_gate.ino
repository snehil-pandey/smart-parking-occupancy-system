#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>

const char* WIFI_SSID = "YOUR_WIFI_NAME";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// Example: "http://192.168.1.10:5000"
const char* PYTHON_SERVER_BASE_URL = "http://YOUR_SERVER_IP:5000";
const int BUZZER_PIN = 25;

WebServer server(80);

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

void handleScan() {
  String qrId = server.arg("id");
  String locationId = server.arg("locationId");
  String mode = server.arg("mode");

  if (qrId.length() == 0) {
    beepError();
    server.send(400, "text/plain", "INVALID");
    return;
  }

  String url = String(PYTHON_SERVER_BASE_URL) + "/verify?id=" + qrId;
  if (locationId.length() > 0) {
    url += "&locationId=" + locationId;
  }
  if (mode.length() > 0) {
    url += "&mode=" + mode;
  }

  HTTPClient http;
  http.begin(url);
  int statusCode = http.GET();
  String result = statusCode > 0 ? http.getString() : "ERROR";
  result.trim();
  http.end();

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

void handleHealth() {
  server.send(200, "text/plain", "OK");
}

void setup() {
  Serial.begin(115200);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("Park Here gate IP: ");
  Serial.println(WiFi.localIP());

  server.on("/health", HTTP_GET, handleHealth);
  server.on("/scan", HTTP_GET, handleScan);
  server.begin();
}

void loop() {
  server.handleClient();
}
