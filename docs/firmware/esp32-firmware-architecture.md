# EH Home — ESP32 Firmware Architecture & Execution Model

## 1. Overview
The EH Smart Switch application is designed for Espressif **ESP32-C6 / ESP32-C3** MCUs with 4MB embedded Flash and no external PSRAM.

The firmware architecture emphasizes low-latency local actuation (<10ms), bounded memory consumption, deterministic failure recovery, and zero-compromise cryptographic security.

---

## 2. Partition Table Layout (4MB Flash)

| Name | Type | SubType | Offset | Size | Purpose |
|---|---|---|---|---|---|
| `nvs` | `data` | `nvs` | `0x9000` | 24 KB | FreeRTOS / Wi-Fi runtime state |
| `otadata` | `data` | `ota` | `0xF000` | 8 KB | Bootloader OTA selection & rollback data |
| `phy_init`| `data` | `phy` | `0x11000`| 4 KB | RF calibration data |
| `fact_v2` | `data` | `nvs` | `0x12000`| 16 KB | Read-only factory identity & mTLS certs |
| `ota_0` | `app` | `ota_0` | `0x20000`| 1792 KB | Active application firmware slot 0 |
| `ota_1` | `app` | `ota_1` | `0x1E0000`| 1792 KB| Target application firmware slot 1 |
| `storage` | `data` | `spiffs`| `0x3A0000`| 384 KB | Offline event log / telemetry buffer |

---

## 3. Application Lifecycle State Machine

```
   ┌──────────────┐
   │ FACTORY_NEW  │ ◄─────── (No Wi-Fi credentials in NVS)
   └──────┬───────┘
          │ Start NimBLE GATT Service
          ▼
 ┌───────────────────┐
 │ BLE_COMMISSIONING │ ◄─── (EH-PROV/1 Handshake Active)
 └────────┬──────────┘
          │ Credentials Received & Validated
          ▼
 ┌───────────────────┐      Wi-Fi Lost
 │ WIFI_CONNECTING   │ ◄───────────────────┐
 └────────┬──────────┘                     │
          │ Got IP                         │
          ▼                                │
 ┌───────────────────┐                     │
 │  MQTT_CONNECTING  │                     │
 └────────┬──────────┘                     │
          │ TLS Handshake & Subscriptions  │
          ▼                                │
 ┌───────────────────┐                     │
 │      ACTIVE       │                     │
 └────────┬──────────┘                     │
          │ Connection Failure             │
          ▼                                │
 ┌───────────────────┐                     │
 │  ERROR_RECOVERY   │ ────────────────────┘
 └───────────────────┘ (Exponential backoff 1s..30s)
```

---

## 4. Hardware Pinout & Peripherals (3X Smart Switch)

| Channel | Function | MCU GPIO | Signal Type | Characteristics |
|---|---|---|---|---|
| **CH1** | Relay Drive 1 | `GPIO 18` | Digital Output | Active HIGH, initial boot state LOW |
| **CH2** | Relay Drive 2 | `GPIO 19` | Digital Output | Active HIGH, initial boot state LOW |
| **CH3** | Relay Drive 3 | `GPIO 20` | Digital Output | Active HIGH, initial boot state LOW |
| **CH1** | Physical Switch 1 | `GPIO 4` | Digital Input | Internal Pull-Up, Any-edge ISR |
| **CH2** | Physical Switch 2 | `GPIO 5` | Digital Input | Internal Pull-Up, Any-edge ISR |
| **CH3** | Physical Switch 3 | `GPIO 6` | Digital Input | Internal Pull-Up, Any-edge ISR |
| **METER**| BL0942 RX | `GPIO 7` (UART1) | Serial Async | 4800 baud, 8-N-1, 23-byte periodic frame |

---

## 5. Switch Debouncing & Local Override Latency
1. Switch transitions fire an edge interrupt (`gpio_isr_handler`).
2. Timestamp and channel are pushed to FreeRTOS queue `s_switch_evt_queue`.
3. `switch_task` inspects elapsed time against `EH_SWITCH_DEBOUNCE_MS` (50ms).
4. Valid toggles immediately trigger `relay_manager_toggle_power()` without awaiting cloud confirmation.
5. Total local actuation latency: **< 5ms**.
6. Cloud notification with `source: "PHYSICAL_SWITCH"` is dispatched asynchronously.
