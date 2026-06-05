#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>
#include <Preferences.h>

// --- Network Configuration ---
const char* AP_SSID = "SIT-SmartGate";
const char* AP_PASS = "parkhere123";
const char* DEFAULT_SERVER_URL = "http://192.168.4.2:5000";
const char* DEFAULT_LOCATION_ID = "loc_1779943110578";

String pythonServerBaseUrl;
String currentLocationId;

WebServer server(80);
Preferences preferences;

// --- Hardware Pins ---
const int internalLED = 2;    
const int ENTRY_SENSOR = 13;  
const int BUZZER_PIN = 25;

// --- Hardware States ---
int entryState = 0; 
unsigned long entryCountdownTimer = 0;
unsigned long entryTimeoutTimer = 0;
const int DELAY_TIME = 10000; 
const int TIMEOUT_TIME = 30000;
int entryDebounceCount = 0;
bool entryStableState = HIGH;

// --- Audio Controls ---
void beep(int durationMs) { digitalWrite(BUZZER_PIN, HIGH); delay(durationMs); digitalWrite(BUZZER_PIN, LOW); }
void beepShort() { beep(150); }
void beepError() { beep(900); }
void beepClose() { beep(150); delay(100); beep(150); } 
void beepExit() { beep(100); delay(80); beep(100); }
void beepSuccess() { beep(100); delay(50); beep(100); delay(50); beep(200); } // Config saved chime

String urlEncode(String value) {
  String encoded = ""; const char* hex = "0123456789ABCDEF";
  for (size_t i = 0; i < value.length(); i++) {
    unsigned char c = value.charAt(i);
    if (isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~') encoded += char(c);
    else { encoded += '%'; encoded += hex[(c >> 4) & 0x0F]; encoded += hex[c & 0x0F]; }
  }
  return encoded;
}

String jsonEscape(String value) {
  value.replace("\\", "\\\\");
  value.replace("\"", "\\\"");
  return value;
}

void loadSavedConfig() {
  currentLocationId = preferences.getString("locationId", DEFAULT_LOCATION_ID);
  pythonServerBaseUrl = preferences.getString("serverUrl", DEFAULT_SERVER_URL);
}

// --- Streamlit API Endpoints ---

// 1. Streamlit checks if the gate is alive
void handleStatus() {
  String payload = "{";
  payload += "\"status\":\"online\",";
  payload += "\"locationId\":\"" + jsonEscape(currentLocationId) + "\",";
  payload += "\"serverUrl\":\"" + jsonEscape(pythonServerBaseUrl) + "\",";
  payload += "\"apSsid\":\"" + String(AP_SSID) + "\"";
  payload += "}";
  server.send(200, "application/json", payload);
}

// 2. Streamlit sends new configuration
void handleUpdateConfig() {
  if (server.hasArg("locationId")) {
    currentLocationId = server.arg("locationId");
    preferences.putString("locationId", currentLocationId);
  }
  
  if (server.hasArg("serverIp")) {
    pythonServerBaseUrl = "http://" + server.arg("serverIp") + ":5000";
    preferences.putString("serverUrl", pythonServerBaseUrl);
  }

  Serial.println("Config updated");
  Serial.println("Server URL: " + pythonServerBaseUrl);
  Serial.println("Location ID: " + currentLocationId);
  beepSuccess();
  server.send(200, "application/json", "{\"message\":\"Config Saved\"}");
}

void handleResetConfig() {
  preferences.clear();
  currentLocationId = DEFAULT_LOCATION_ID;
  pythonServerBaseUrl = DEFAULT_SERVER_URL;
  beepSuccess();
  Serial.println("Config reset to defaults");
  server.send(200, "application/json", "{\"message\":\"Config Reset\"}");
}

// --- Existing Cloud Verification ---
void handleScan() {
  String qrId = server.hasArg("id") ? server.arg("id") : "";
  if (qrId.length() == 0) { beepError(); server.send(400, "text/plain", "INVALID"); return; }

  String url = pythonServerBaseUrl + "/verify?id=" + urlEncode(qrId) + "&locationId=" + urlEncode(currentLocationId);
  Serial.println("Checking Cloud: " + url);

  HTTPClient http; http.begin(url);
  int statusCode = http.GET();
  String result = statusCode > 0 ? http.getString() : "ERROR";
  result.trim(); http.end();

  if (result == "ENTRY") {
    beepShort(); digitalWrite(internalLED, HIGH); entryState = 1; entryTimeoutTimer = millis();
  } else if (result == "EXIT") {
    beepExit(); digitalWrite(internalLED, HIGH); entryState = 1; entryTimeoutTimer = millis();
  } else {
    beepError(); 
  }
  
  server.send(200, "text/plain", result);
}

bool readEntrySensorDebounced() {
  bool read = digitalRead(ENTRY_SENSOR);
  if (read == entryStableState) entryDebounceCount = 0;
  else if (++entryDebounceCount > 3) { entryStableState = read; entryDebounceCount = 0; }
  return entryStableState;
}

void setup() {
  Serial.begin(115200);
  pinMode(BUZZER_PIN, OUTPUT); 
  pinMode(internalLED, OUTPUT); 
  pinMode(ENTRY_SENSOR, INPUT_PULLUP);

  // Load Saved Memory
  preferences.begin("gate-config", false);
  loadSavedConfig();
  
  Serial.println("\nStarting SIT-SmartGate AP...");
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASS);
  Serial.print("Gate AP Ready! IP: "); Serial.println(WiFi.softAPIP());
  Serial.println("Server URL: " + pythonServerBaseUrl);
  Serial.println("Location ID: " + currentLocationId);

  // Register API Routes
  server.on("/scan", HTTP_GET, handleScan);
  server.on("/status", HTTP_GET, handleStatus);             // Streamlit ping
  server.on("/update_config", HTTP_GET, handleUpdateConfig); // Streamlit push
  server.on("/reset_config", HTTP_GET, handleResetConfig);
  server.on("/reset-config", HTTP_GET, handleResetConfig);
  
  server.begin();
}

void loop() {
  server.handleClient();

  // Physical Gate Logic
  static bool lastEntryState = HIGH;
  bool currentEntryState = readEntrySensorDebounced(); 
  
  if (entryState == 1 && lastEntryState == HIGH && currentEntryState == LOW) entryState = 2; 
  if (entryState == 2 && lastEntryState == LOW && currentEntryState == HIGH) { entryCountdownTimer = millis(); entryState = 3; }
  lastEntryState = currentEntryState; 

  if (entryState == 3 && (millis() - entryCountdownTimer >= DELAY_TIME)) {
    beepClose(); digitalWrite(internalLED, LOW); entryState = 0;                   
  }

  if (entryState == 1 && (millis() - entryTimeoutTimer >= TIMEOUT_TIME)) {
    beepError();
    digitalWrite(internalLED, LOW);
    entryState = 0;
  }
}
