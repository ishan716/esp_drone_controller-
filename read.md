
# 📡 Flutter WiFi Drone Controller (ESP32 + Betaflight CRSF)

A custom drone control system that uses a **Flutter mobile app as a joystick controller**, sending real-time commands over **WiFi (UDP)** to an **ESP32-C3 receiver**, which converts them into **CRSF signals for Betaflight flight controllers**.

---

## 🚀 System Overview

```
Flutter App (Joystick UI)
        ↓ UDP (WiFi)
ESP32-C3 Receiver
        ↓ UART (CRSF Protocol)
Betaflight Flight Controller (F4/F7)
        ↓
ESCs + Motors
```

---

## ✨ Features

* 📱 Real-time mobile joystick control (Flutter)
* 📡 Low-latency UDP communication over WiFi
* ⚡ ESP32-C3 as wireless receiver bridge
* 🎮 CRSF protocol support for Betaflight
* 🧠 Smooth RC channel mapping (Roll, Pitch, Yaw, Throttle)
* 🛑 Failsafe support (signal loss protection)
* 📊 Optional telemetry back to app (future upgrade)

---

## 🧩 Project Components

### 1. Flutter App (Controller)

* Virtual joystick UI
* Sends control data over UDP
* Runs at 50–100 Hz update rate

Example packet:

```json
{
  "roll": 1500,
  "pitch": 1500,
  "yaw": 1500,
  "throttle": 1200,
  "arm": 1
}
```

---

### 2. ESP32-C3 (Receiver Bridge)

* Connects to phone via WiFi
* Receives UDP packets
* Maps values to CRSF channels
* Sends data to flight controller via UART

Responsibilities:

* UDP server (WiFi)
* Packet parsing
* CRSF encoding
* UART transmission

---

### 3. Betaflight Flight Controller

* Receives CRSF input
* Handles stabilization & mixing
* Controls motors via ESCs

Configuration:

* Receiver Mode: Serial-based receiver
* Provider: CRSF
* Serial RX enabled on correct UART

---

## ⚙️ Communication Protocols

### 📡 UDP (Flutter → ESP32)

* Fast, lightweight
* 50–100 Hz update rate
* Ideal for real-time control

### 🔌 CRSF (ESP32 → FC)

* Native Betaflight protocol
* Low latency RC communication
* Reliable failsafe support

---

## 🛠️ Hardware Requirements

* ESP32-C3 module
* Betaflight-compatible flight controller (F4/F7)
* ESCs + motors
* LiPo battery
* WiFi-enabled smartphone

---

## 🔌 Wiring

ESP32-C3 → Flight Controller:

```
ESP32 TX  → FC RX (UART)
ESP32 GND → FC GND
```

Optional:

```
FC TX → ESP32 RX (telemetry)
```

---

## 🧠 Control Mapping

Standard RC channel mapping:

| Channel | Function |
| ------- | -------- |
| CH1     | Roll     |
| CH2     | Pitch    |
| CH3     | Throttle |
| CH4     | Yaw      |
| CH5+    | Modes    |

Range:

* 1000 → Minimum
* 1500 → Center
* 2000 → Maximum

---

## 🛑 Safety Warning

⚠️ This system is experimental.

Before flight:

* Always test **without propellers**
* Configure Betaflight failsafe to **DROP**
* Ensure stable WiFi connection
* Use throttle limits during testing

---

## 📈 Performance

| Component        | Latency  |
| ---------------- | -------- |
| Flutter → UDP    | 20–60ms  |
| ESP32 Processing | 1–3ms    |
| CRSF Output      | 1–5ms    |
| **Total**        | ~30–80ms |

---

## 🔮 Future Improvements

* 📊 Telemetry back to Flutter app
* 🎮 Physical joystick support (ESP32 ground controller)
* 📡 ESP-NOW low-latency mode upgrade
* 📷 FPV video integration
* 🧭 GPS + return-to-home logic
* 🔋 Smart battery monitoring

---

## 🧪 Project Goal

To build a **custom WiFi-based drone control system** combining:

* Mobile UI (Flutter)
* Embedded systems (ESP32)
* Drone firmware (Betaflight)
* Real-time communication (UDP + CRSF)

---

## 👨‍💻 Author

Built for experimental UAV control research and embedded systems learning.
