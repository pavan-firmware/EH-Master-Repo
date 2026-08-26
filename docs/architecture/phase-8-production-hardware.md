# EH Home — Phase 8 Production Hardware & Manufacturing Architecture

## 1. Executive Summary & Purpose
Phase 8 establishes the complete production hardware, manufacturing PKI, and device lifecycle foundations for EH Home.

It transitions the system from virtualized simulator execution (`tools/device-simulator/`) to production-grade C firmware running on **ESP32-C6 / ESP32-C3**, provisioned via an automated manufacturing toolchain and managed through signed dual-slot OTA updates.

---

## 2. End-to-End System Architecture

```
Physical Switch / Relays / Meter
  │ (GPIO 18, 19, 20 / GPIO 4, 5, 6 / UART1 BL0942)
  ▼
ESP32 Application Layer (FreeRTOS)
  │ (NimBLE EH-PROV/1 + esp-mqtt mTLS + NVS fact_v2)
  ▼
EMQX 5.8.0 MQTT Broker (Port 8883 mTLS)
  │ (Per-device ACL + Canonical Topic Tree)
  ▼
Backend Ingestion & Command Router
  │ (PostgreSQL 16 Repositories + Realtime Event Bus)
  ▼
Server-Sent Events (SSE) Stream
  │ (/api/v1/homes/:homeId/stream)
  ▼
Flutter Mobile Application
  │ (Authoritative State Convergence + Live Telemetry)
```

---

## 3. Subsystem Breakdown

### 3.1 Production ESP-IDF Firmware (`firmware/platforms/esp32/smart-switch-app/`)
- **Target MCU:** ESP32-C6 (Primary) / ESP32-C3 (Compatible Fallback).
- **FreeRTOS Tasks:**
  - `app_main`: Subsystem initialization, factory identity loading.
  - `switch_task`: 50ms debouncing of edge interrupts on GPIO 4, 5, 6.
  - `telemetry_task`: 23-byte BL0942 frame parsing on UART1 @ 4800 baud.
  - `mqtt_task`: mTLS connection management, command reception, state publication.
- **Hardware Isolation:** GPIO manipulation is strictly encapsulated inside `relay_manager` and `switch_manager`; protocol handlers interact only via typed callback APIs.

### 3.2 Manufacturing PKI & Factory Provisioning (`tools/manufacturing/`)
- **CA Hierarchy:**
  - Offline Manufacturing Root CA (Air-gapped, 10-year validity).
  - Device Issuing Intermediate CA (Factory line, 5-year validity).
  - Per-Device Client Certificates (CN=`deviceId`, 2-year validity).
- **Factory Toolchain:**
  - `ca_manager.py`: Issues valid clientAuth x509 certificates.
  - `factory_provisioner.py`: Staging CLI generating device UUIDs, serial numbers, 256-bit commissioning secrets, `fact_v2` NVS binary partitions, and canonical `EH1:` QR payloads.
  - `manufacturing_audit.json`: Immutable factory staging log.

### 3.3 Device Security & Signed OTA Updates (`tools/ota/`, `backend/src/api/ota.router.js`)
- **Dual-Slot OTA Partition Scheme:** 4MB flash with `ota_0` (1792KB) and `ota_1` (1792KB).
- **Integrity & Authenticity:** Firmware binaries signed with Ed25519; SHA-256 validated before flash write.
- **Rollback Safety:** New firmware must successfully associate with Wi-Fi and connect to MQTT broker before calling `esp_ota_mark_app_valid_cancel_rollback()`. Boot crashes trigger automatic bootloader rollback to previous slot.
- **Anti-Rollback Policy:** Enforces semantic version checks against `minFirmwareVersion`.

### 3.4 Hardware Validation Harness (`tools/hardware-test-harness/`)
- 13-step physical verification runner.
- When physical silicon is detached, marks tests explicitly as `PENDING` per project governance rules.

---

## 4. Hardware Boundary Invariant
- `firmware/legacy-v1/`: Remains 100% frozen with zero changes.
- Production CA private keys: Strictly excluded from Git repository.
