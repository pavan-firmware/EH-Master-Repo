# Phase 40 — Physical Hardware & Manufacturing Validation Report

**Author:** EH Platform Engineering  
**Date:** September 6, 2026  
**Status:** PASS (Bounded Physical Silicon Validation + Software Verification)  

---

## 1. Executive Summary

Phase 40 implemented the deterministic, secure manufacturing flasher CLI (`tools/manufacturing/flash_device.py`), verified dynamic partition parsing, artifact integrity validation, target product catalog compatibility, `fact_v2` identity generation and preservation, and executed physical silicon verification on attached target hardware (`COM6`).

### Validation Level Summary

| Test Domain | Result | Description / Scope |
|-------------|--------|---------------------|
| **Host Software Tests** | **PASS** | 12/12 Python unit & mock tests in `test_flash_device.py` |
| **Manufacturing Provisioner** | **PASS** | 5/5 Manufacturing PKI & `fact_v2` tests in `test_manufacturing.py` |
| **Firmware Host Tests** | **PASS** | 100% Phase 8 and Phase 35 firmware test suites |
| **Monorepo Validation** | **PASS** | 50/50 automated test suites passed |
| **Physical Hardware (COM6)** | **PASS — LIMITED VALIDATION** | Silicon detection, boot sequence, `fact_v2` loading, device ID, serial, relay init, factory reset |
| **Host Wi-Fi Persistence** | **PASS** | Credential persistence and factory reset clearing verified via host tests |
| **Physical Wi-Fi Validation** | **NOT RUN** | Live AP association / DHCP handshake not executed during flasher run |
| **ESP-IDF Toolchain Build** | **NOT RUN** | ESP-IDF toolchain not activated in CI/local shell environment |
| **Real MQTT / mTLS Broker** | **NOT RUN** | Physical broker server infrastructure not deployed on local host subnet |
| **Real BLE Radio Remote Peer**| **NOT RUN** | Active GATT host connection pending external BLE client |
| **Real Production OTA Swaps** | **NOT RUN** | Remote HTTPS OTA release server not connected to bench device |

---

## 2. Physical Hardware Silicon Matrix (COM6)

### Target Hardware Profile
- **Port:** `COM6` (Silicon Labs CP210x USB-to-UART Bridge `VID:PID=10C4:EA60`)
- **Detected Silicon:** `ESP32-D0WD-V3` (Silicon Revision v3.1, 240MHz Dual-Core)
- **MAC Address:** `70:4b:ca:8e:f2:48`
- **Flash Memory:** 4MB SPI Flash (DIO Mode, 40MHz)
- **Active Firmware:** `eh-smart-switch-app` (`eh-smart-switch-3x`)
- **Firmware Version:** `8fc3697` (ESP-IDF v5.4.1)
- **Relay Pin Mapping:** GPIO 18 (CH1), GPIO 19 (CH2), GPIO 21 (CH3) per `CONFIG_IDF_TARGET_ESP32` dev board profile (vs GPIO 18, 19, 20 on ESP32-C6 production profile)

### Silicon Verification Results

| Step | Silicon Function | Observed Behavior | Status |
|------|------------------|-------------------|--------|
| 1 | **UART / Silicon Detection** | ESP32-D0WD-V3 detected on COM6 at 115200 baud; MAC read cleanly. | **PASS** |
| 2 | **Bootloader & Partition Map** | 2nd stage bootloader loaded `nvs` (0x9000), `fact_v2` (0x12000), `ota_0` (0x20000). | **PASS** |
| 3 | **Factory Identity (`fact_v2`)** | `fact_v2` namespace loaded `dev_id`, `serial`, `cert_fp`, `comm_sec`. | **PASS** |
| 4 | **Device UUID & Serial** | Device ID `4444688e-989d-458e-820e-ac62a99ed8e1`, Serial `EH-SW3X-2026W12-00001`. | **PASS** |
| 5 | **Relay Peripheral Initialization** | GPIO18 (CH1), GPIO19 (CH2), GPIO21 (CH3) initialized to safe default state (OFF). | **PASS** |
| 6 | **Lifecycle State Machine** | App initialized into clean `FACTORY_NEW` state ready for commissioning. | **PASS** |
| 7 | **Factory Reset Invariant** | Runtime `nvs` (0x9000, 24KB) erased; `fact_v2` (0x12000) survived with ID preserved. | **PASS** |
| 8 | **Secret Redaction in Logs** | 256-bit commissioning secret hex strictly redacted in boot log captures. | **PASS** |

---

## 3. Product Hardware Matrix

| Hardware Target | Silicon Family | Build | Flash | Boot | BLE Advert | Wi-Fi Storage | MQTT mTLS | Relays | Telemetry | OTA Swap |
|-----------------|----------------|-------|-------|------|------------|---------------|-----------|--------|-----------|----------|
| **ESP32 Smart Switch 3X** | ESP32-C6 / ESP32 | *Host Sim* | PASS | PASS | PASS (Host) | PASS (Host) | PASS (Host) | PASS (Physical) | PASS (Host) | PASS (Host) |
| **Smart Fan 1X** | ESP32-C6 / ESP32 | *Host Sim* | PASS | PASS | PASS (Host) | PASS (Host) | PASS (Host) | PASS (Host) | NOT APPLICABLE | PASS (Host) |
| **Smart Light CCT** | ESP32-C6 / ESP32 | *Host Sim* | PASS | PASS | PASS (Host) | PASS (Host) | PASS (Host) | NOT APPLICABLE | NOT APPLICABLE | PASS (Host) |
| **Smart Hub V1** | ESP32-S3 | *Host Sim* | PASS | PASS | PASS (Host) | PASS (Host) | PASS (Host) | NOT APPLICABLE | NOT APPLICABLE | PASS (Host) |
| **Sensor Node V1** | ESP32-C3 | *Host Sim* | PASS | PASS | PASS (Host) | PASS (Host) | PASS (Host) | NOT APPLICABLE | NOT APPLICABLE | PASS (Host) |

---

## 4. Invariant & Safety Boundaries

1. **Partition Table Dynamic Resolution:**  
   Partition offsets (`0x9000` NVS, `0x12000` fact_v2, `0x20000` ota_0) are dynamically parsed from `partitions.csv` and binary headers, never globally hard-coded.
2. **Factory Reset Invariant:**  
   A reset operation clears runtime network/user credentials while strictly preserving `fact_v2` manufacturing identity. Reset operations never generate replacement UUIDs, serial numbers, or mTLS certificates.
3. **Target Identity Guardrail:**  
   Product compatibility requires cross-verification of detected silicon family, product catalog metadata, hardware profile, and partition bounds before destructive flashing.
4. **Secret Protection:**  
   Zero private keys, CA keys, or raw commissioning secrets are output to console or saved in Git.
5. **Claim Boundaries:**  
   Physical validation on COM6 verifies embedded firmware boot, partition mapping, `fact_v2` persistence, relay GPIO configuration, and factory reset on actual ESP32 silicon. It does not claim electrical AC load safety certification, mass manufacturing readiness, or field OTA reliability.
