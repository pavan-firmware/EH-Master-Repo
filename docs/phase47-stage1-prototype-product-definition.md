# Phase 47 / Stage 1: Prototype Product Definition & ESP32 Dev-Board Target

## Executive Overview
Phase 47 Stage 1 establishes the canonical prototype product definition, firmware configuration, backend models, Flutter dynamic capability consumption, and real authentication foundation for the **EH Smart Socket 3X** running on an **ESP32 Development Board** (`ESP32_DEV_BOARD`).

This stage is **FOUNDATION ONLY**. All changes strictly reuse and extend the existing canonical schema contracts, firmware drivers, product catalog services, and dynamic UI renderers without introducing dummy accounts, fake bypasses, or parallel architectures.

---

## 1. Prototype Target Specifications

| Parameter | Specification |
| :--- | :--- |
| **Product Family** | `SMART_SOCKET` (`smart_socket`) |
| **Variant** | `3X` (`eh-smart-socket-3x`) |
| **Hardware Target** | `ESP32_DEV_BOARD` |
| **Silicon Target** | Espressif ESP32-D0WD / ESP32 Dev Board (Dual Core Xtensa) |
| **Total Channel Count** | `3` |
| **Relay Output Channels** | `3` (Channels 1, 2, 3) |
| **Physical Switch Inputs** | `3` (Channels 1, 2, 3) |
| **Energy Metering** | BL0942 UART @ 4800 baud (Fixed-point integer telemetry) |
| **Connectivity** | 2.4 GHz Wi-Fi (802.11b/g/n) + BLE 5.0 (EH-PROV/1) |
| **Transport** | MQTT over mTLS (Port 8883) with Canonical Topic Taxonomy |
| **OTA Subsystem** | Dual-Slot HTTPS OTA with Anti-Rollback & Ed25519 signatures |

---

## 2. GPIO Hardware Mapping (ESP32 Dev Board Profile)

The GPIO configuration safely reserves strapping pins (GPIO 0, 2, 12, 15) and SPI flash memory pins (GPIO 6–11):

| Channel | Relay Output GPIO | Switch Input GPIO | Energy / Comm UART |
| :--- | :--- | :--- | :--- |
| **Channel 1** | GPIO `18` | GPIO `4` | UART1 RX: GPIO `22` |
| **Channel 2** | GPIO `19` | GPIO `5` | UART1 TX: GPIO `23` |
| **Channel 3** | GPIO `21` | GPIO `13` | — |

---

## 3. Firmware Startup Diagnostic Banner

At boot time, firmware prints the standard deterministic diagnostic identity block:

```
==================================================
EH SMART HOME PROTOTYPE
==================================================
Product      : SMART_SOCKET
Variant      : 3X
Hardware     : ESP32_DEV_BOARD
Firmware     : 1.0.0
Device ID    : <canonical-uuid-v4>
Serial       : <manufacturing-serial>
Relay Count  : 3
Switch Count : 3
Energy       : ENABLED
BLE          : ENABLED
WiFi         : ENABLED
MQTT         : ENABLED
OTA          : ENABLED
==================================================
```

---

## 4. Real Authentication & Dynamic UI Architecture

1. **Clean Authentication Route**:
   - Zero hardcoded demo users or automatic bypasses in runtime paths.
   - App startup checks authentication state:
     $$\text{App Launch} \longrightarrow \text{Auth State Check} \longrightarrow \text{Real Login / Register} \longrightarrow \text{Home / Devices}$$
   - Settings page triggers `authController.logout()` returning immediately to the unauthenticated login screen.
2. **Capability-Driven UI Generation**:
   - Flutter `DynamicDeviceView` derives channel count dynamically from the canonical `ProductVariantDefinition` / `ResolvedDevice` model ($N=3$).
   - Socket controllers are dynamically created for each channel without hardcoded switch limits or manual user channel toggles.

---

## 5. Verification & Test Suite

The automated test suite (`backend/tests/phase47-stage1-prototype.test.js`) validates:
1. `SMART_SOCKET 3X` ProductMetadata schema compliance.
2. 3X resolves to exactly 3 channels.
3. Deterministic channel IDs (`Socket 1`, `Socket 2`, `Socket 3`).
4. Relay capability count matches 3.
5. Switch capability count matches 3.
6. JSON serialization round-trip preservation.
7. Backend capability resolution and device model state integrity.
8. Flutter capability consumption without hardcoded assumptions.
9. Dynamic UI generation produces 3 independent channel controllers.
10. Zero demo credentials in app startup path.
11. Unauthenticated startup leads to `LoginScreen`.
12. Logout returns to unauthenticated state.
13. Prototype firmware pin mappings (relays 18, 19, 21; switches 4, 5, 13).
14. Firmware startup diagnostic banner structure.
15. Non-regression across all 11 canonical product definitions.

---

## 6. Physical Validation Claim Boundary

> [!WARNING]
> **NOT YET PHYSICALLY VALIDATED ON BENCH HARDWARE**
> 
> The following physical/electrical capabilities have been software-modeled and simulated via unit, integration, and host test harnesses, but **HAVE NOT YET BEEN PHYSICALLY VALIDATED** on real mains electrical hardware:
> - Physical relay electrical switching under AC load.
> - Physical mechanical switch debouncing on live hardware lines.
> - Live RF Wi-Fi 2.4 GHz association against real access points.
> - Live mTLS broker handshake with TLS client certificates over physical network.
> - Physical BL0942 UART telemetry acquisition from shunt/current transformers.
> - Physical flash partition OTA binary download and dual-slot bootloader swap.
> - Power-cycle brownout endurance and RTC backup clock behavior.
