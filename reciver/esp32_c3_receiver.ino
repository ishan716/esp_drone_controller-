#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <ArduinoJson.h>

const char *kSsid = "DroneController";
const char *kPassword = "12345678";
const uint16_t kUdpPort = 5005;
const IPAddress kApIp(192, 168, 4, 1);
const IPAddress kApGateway(192, 168, 4, 1);
const IPAddress kApSubnet(255, 255, 255, 0);

const int kCrsfTxPin = 20;
const int kCrsfRxPin = 21;
const uint32_t kCrsfBaud = 420000;

const uint8_t kCrsfAddress = 0xC8;
const uint8_t kCrsfTypeRcChannels = 0x16;
const uint8_t kCrsfPayloadSize = 22;
const uint8_t kCrsfFrameSize = 1 + 1 + 1 + kCrsfPayloadSize + 1;

WiFiUDP udp;
HardwareSerial CrsfSerial(1);

uint16_t channels[16];
unsigned long lastReceivedMs = 0;
unsigned long lastSendMs = 0;

uint8_t crc8(const uint8_t *data, size_t len) {
  uint8_t crc = 0;
  for (size_t i = 0; i < len; i++) {
    crc ^= data[i];
    for (uint8_t bit = 0; bit < 8; bit++) {
      if (crc & 0x80) {
        crc = (crc << 1) ^ 0xD5;
      } else {
        crc <<= 1;
      }
    }
  }
  return crc;
}

uint16_t mapToCrsf(int value) {
  value = constrain(value, 1000, 2000);
  const int crsfMin = 172;
  const int crsfMax = 1811;
  return (uint16_t)map(value, 1000, 2000, crsfMin, crsfMax);
}

void setDefaultChannels() {
  channels[0] = mapToCrsf(1500);
  channels[1] = mapToCrsf(1500);
  channels[2] = mapToCrsf(1000);
  channels[3] = mapToCrsf(1500);
  channels[4] = mapToCrsf(1000);
  for (int i = 5; i < 16; i++) {
    channels[i] = mapToCrsf(1500);
  }
}

void packChannels(uint8_t *payload, const uint16_t *ch) {
  memset(payload, 0, kCrsfPayloadSize);
  uint32_t bitBuffer = 0;
  uint8_t bitCount = 0;
  uint8_t outIndex = 0;

  for (int i = 0; i < 16; i++) {
    bitBuffer |= ((uint32_t)(ch[i] & 0x07FF)) << bitCount;
    bitCount += 11;
    while (bitCount >= 8) {
      payload[outIndex++] = bitBuffer & 0xFF;
      bitBuffer >>= 8;
      bitCount -= 8;
    }
  }
}

void sendCrsfFrame() {
  uint8_t frame[kCrsfFrameSize];
  const uint8_t length = 1 + kCrsfPayloadSize + 1;

  frame[0] = kCrsfAddress;
  frame[1] = length;
  frame[2] = kCrsfTypeRcChannels;

  packChannels(&frame[3], channels);

  const uint8_t crc = crc8(&frame[2], 1 + kCrsfPayloadSize);
  frame[3 + kCrsfPayloadSize] = crc;

  CrsfSerial.write(frame, kCrsfFrameSize);
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println();
  Serial.println("ESP32-C3 UDP receiver starting...");

  setDefaultChannels();

  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(kApIp, kApGateway, kApSubnet);
  const bool apStarted = WiFi.softAP(kSsid, kPassword, 1, 0, 4);
  udp.begin(kUdpPort);

  Serial.print("WiFi AP started: ");
  Serial.println(apStarted ? "yes" : "no");
  Serial.print("WiFi AP SSID: ");
  Serial.println(kSsid);
  Serial.print("WiFi AP IP: ");
  Serial.println(WiFi.softAPIP());
  Serial.print("UDP listening on port: ");
  Serial.println(kUdpPort);

  CrsfSerial.begin(kCrsfBaud, SERIAL_8N1, kCrsfRxPin, kCrsfTxPin);
  Serial.println("CRSF serial started");
}

void loop() {
  const int packetSize = udp.parsePacket();
  if (packetSize > 0) {
    char buffer[256];
    const int len = udp.read(buffer, sizeof(buffer) - 1);
    if (len > 0) {
      buffer[len] = '\0';
      Serial.print("Raw UDP: ");
      Serial.println(buffer);

      StaticJsonDocument<256> doc;
      DeserializationError error = deserializeJson(doc, buffer);
      if (error == DeserializationError::Ok) {
        const int roll = doc["roll"] | 1500;
        const int pitch = doc["pitch"] | 1500;
        const int yaw = doc["yaw"] | 1500;
        const int throttle = doc["throttle"] | 1000;
        const int arm = doc["arm"] | 0;

        channels[0] = mapToCrsf(roll);
        channels[1] = mapToCrsf(pitch);
        channels[2] = mapToCrsf(throttle);
        channels[3] = mapToCrsf(yaw);
        channels[4] = mapToCrsf(arm ? 2000 : 1000);

        lastReceivedMs = millis();

        Serial.print("UDP packet from ");
        Serial.print(udp.remoteIP());
        Serial.print(":");
        Serial.print(udp.remotePort());
        Serial.print(" len=");
        Serial.print(len);
        Serial.print(" roll=");
        Serial.print(roll);
        Serial.print(" pitch=");
        Serial.print(pitch);
        Serial.print(" yaw=");
        Serial.print(yaw);
        Serial.print(" throttle=");
        Serial.print(throttle);
        Serial.print(" arm=");
        Serial.println(arm ? 1 : 0);
      } else {
        Serial.print("JSON parse failed: ");
        Serial.println(error.c_str());
      }
    }
  }

  const unsigned long now = millis();
  if (now - lastReceivedMs > 300) {
    setDefaultChannels();
  }

  if (now - lastSendMs >= 20) {
    sendCrsfFrame();
    lastSendMs = now;
  }
}
