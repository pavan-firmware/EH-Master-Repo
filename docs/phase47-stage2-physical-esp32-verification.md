# Phase 47 Stage 2: Physical ESP32 Dev-Board Flash, Boot, Provisioning & 3X Hardware Verification

## Overview

This report documents the verification of the ESP32 prototype hardware target for the **EH Smart Socket 3X** (`eh-smart-socket-3x`) and the separation between deterministic CI build verification and physical local bench testing.

---

## 1. Prototype Target Configuration & Firmware Build Architecture

- **Silicon Target**: ESP32-D0WD-V3 (Xtensa Dual-Core 32-bit LX6 @ 240MHz, silicon rev v3.1)
- **Flash Geometry**: 4MB Quad-SPI Flash (4,194,304 bytes)
- **Toolchain / Framework**: Espressif ESP-IDF v5.4.1
- **Project Location**: `firmware/platforms/esp32/smart-switch-app`
- **Partition Layout**:
  - `fact_v2`: Offset `0x12000` (Factory identity namespace)
  - `ota_0`: Offset `0x20000` (Application binary slot 0, 1.75MB)
  - `ota_1`: Offset `0x1E0000` (Application binary slot 1, 1.75MB)

### Canonical Build Artifacts:
- Application Binary: `build/eh-smart-switch-app.bin`
- Bootloader Binary: `build/bootloader/bootloader.bin`
- Partition Table Binary: `build/partition_table/partition-table.bin`

---

## 2. GPIO Prototype Mapping Contract

The 3-channel socket prototype uses the following dedicated GPIO pins:

| Channel | Relay Output GPIO | Switch Input GPIO | Default State | Debounce Filter |
|---|---|---|---|---|
| Channel 1 | GPIO 18 | GPIO 4 | LOW (OFF) | 50ms Edge Filter |
| Channel 2 | GPIO 19 | GPIO 5 | LOW (OFF) | 50ms Edge Filter |
| Channel 3 | GPIO 21 | GPIO 13 | LOW (OFF) | 50ms Edge Filter |

---

## 3. Separation of Environments

### CI Environment (GitHub Actions Runner)
- Deterministic ESP-IDF v5.4.1 compilation inside official container (`espressif/idf:v5.4.1`).
- Target configuration: `idf.py set-target esp32 && idf.py build`.
- Structural artifact validation (ELF/bin presence, size bounds within 1.75MB partition).
- Verification of C contracts, partition layouts, catalog resolution, and Flutter route security.
- **Never attempts physical COM port or USB device access.**

### Local Hardware Bench Environment
- Physical CP210x USB-to-UART Bridge on `COM6`.
- Hardware flash @ 460,800 baud.
- Hardware power-on bootloader execution.
- Startup banner diagnostic logging on UART.
- NVS `fact_v2` hardware identity persistence.
- BLE commissioning advertising (`0x6101` & `0x6102`).
- Physical relay GPIO toggling and switch debouncing.

---

## 4. Verification Checklist & Claim Boundaries

| Domain | Scope | Status | Notes |
|---|---|---|---|
| ESP-IDF 5.4.1 Build | CI | **PASS** | Generates bootloader, partition-table, and application binary |
| Binary Size Gate | CI | **PASS** | App binary fits comfortably within 1.75MB OTA partition limit |
| Partition Offsets | CI | **PASS** | Verified against custom `partitions.csv` |
| Product Catalog Resolution | CI | **PASS** | Resolves `eh-smart-socket-3x` with 3 dynamic channels |
| Real Auth Navigation Flow | CI | **PASS** | Zero hardcoded demo bypasses |
| USB / Serial Detection | Local Bench | **LOCAL VERIFIED** | CP210x on COM6 |
| Physical Silicon | Local Bench | **LOCAL VERIFIED** | ESP32-D0WD-V3 (rev v3.1, 4MB Flash) |
| Physical Flash & Boot | Local Bench | **LOCAL VERIFIED** | Flashed and booted successfully |
| BLE Advertisement | Local Bench | **LOCAL VERIFIED** | Advertising EH-PROV/1 |
| Physical Energy Metering | Bench Target | **NOT RUN** | BL0942 metering IC not fitted on standard dev-board |
| High-Voltage AC Switching | Bench Target | **NOT RUN** | Safe low-voltage bench testing only |
