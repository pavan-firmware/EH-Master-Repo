# EH Home — Multi-Product Firmware Maintenance & Build Guide

This comprehensive runbook provides step-by-step instructions for building, flashing, monitoring, and maintaining production firmware across all **Smart Switch** and **Smart Socket** variants on both the **ESP32 Development Board** (`ESP32-D0WD-V3`) and the **ESP32-C6 Commercial Production PCB**.

---

## 1. Environment & Prerequisites

### Pinned Toolchain Environment
- **ESP-IDF Version:** `v5.4.1` (Pinned path: `C:\esp\v5.4.1\esp-idf`)
- **Python Environment:** Python 3.14 (`C:\Users\pavan\.espressif\python_env\idf5.4_py3.14_env`)
- **Serial Bridge:** Silicon Labs CP210x on `COM6` (115200 baud monitor, 460800 baud flash)

### Step 1: Environment Activation (Run Once per PowerShell Session)
Open PowerShell and run:
```powershell
cd C:\Users\pavan\Downloads\Flutter\SMART_HOME_V1\firmware\platforms\esp32\smart-switch-app
. C:\esp\v5.4.1\esp-idf\export.ps1
```
*(Note: The dot and space before `C:\esp\...` are mandatory in PowerShell to export environment variables).*

### Step 2: Verify Activation
```powershell
idf.py --version
# Expected Output: ESP-IDF v5.4.1
```

---

## 2. Master Product & Variant Matrix

| Product Line | Variant | Active Channels | Active Pins (ESP32 Dev Board) | Active Pins (ESP32-C6 PCB) | Model Identifier |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Smart Switch** | **1X** | 1 | Relay: `GPIO 18` \| Switch: `GPIO 23` | Relay: `GPIO 0` \| Switch: `GPIO 18` | `EH-SW-1X` |
| **Smart Switch** | **2X** | 2 | Relays: `18, 19` \| Switches: `23, 25` | Relays: `0, 1` \| Switches: `18, 19` | `EH-SW-2X` |
| **Smart Switch** | **3X** | 3 | Relays: `18, 19, 21` \| Switches: `23, 25, 26` | Relays: `0, 1, 2` \| Switches: `18, 19, 20` | `EH-SW-3X` |
| **Smart Switch** | **4X** | 4 | Relays: `18, 19, 21, 22` \| Switches: `23, 25, 26, 27` | Relays: `0, 1, 2, 3` \| Switches: `18, 19, 20, 21` | `EH-SW-4X` |
| **Smart Socket** | **1X** | 1 | Relay: `GPIO 18` \| Switch: `GPIO 23` | Relay: `GPIO 0` \| Switch: `GPIO 18` | `EH-SK-1X` |
| **Smart Socket** | **2X** | 2 | Relays: `18, 19` \| Switches: `23, 25` | Relays: `0, 1` \| Switches: `18, 19` | `EH-SK-2X` |
| **Smart Socket** | **3X** | 3 | Relays: `18, 19, 21` \| Switches: `23, 25, 26` | Relays: `0, 1, 2` \| Switches: `18, 19, 20` | `EH-SK-3X` |

*System Peripherals (All Variants):*
- **Status LED:** ESP32: `GPIO 13` (mirrored `GPIO 2`) \| ESP32-C6: `GPIO 22`
- **Reset Button:** ESP32: `GPIO 33` (mirrored `GPIO 0`) \| ESP32-C6: `GPIO 10`
- **BL0942 Energy Meter UART (Optional EM):** ESP32: `TX 17, RX 16` \| ESP32-C6: `TX 6, RX 7`

---

## 3. Build Commands

You can build any variant using the repository build script `scripts/build_firmware.ps1`.

### A. Building for Your Active ESP32 Dev Board (`Target: esp32`)

```powershell
# From repository root:
cd C:\Users\pavan\Downloads\Flutter\SMART_HOME_V1

# 1. Smart Switch 1X
powershell .\scripts\build_firmware.ps1 -Target esp32 -ProductType switch -Variant 1x

# 2. Smart Switch 2X
powershell .\scripts\build_firmware.ps1 -Target esp32 -ProductType switch -Variant 2x

# 3. Smart Switch 3X
powershell .\scripts\build_firmware.ps1 -Target esp32 -ProductType switch -Variant 3x

# 4. Smart Switch 4X (Non-EM Baseline)
powershell .\scripts\build_firmware.ps1 -Target esp32 -ProductType switch -Variant 4x

# 5. Smart Socket 1X
powershell .\scripts\build_firmware.ps1 -Target esp32 -ProductType socket -Variant 1x

# 6. Smart Socket 2X
powershell .\scripts\build_firmware.ps1 -Target esp32 -ProductType socket -Variant 2x

# 7. Smart Socket 3X
powershell .\scripts\build_firmware.ps1 -Target esp32 -ProductType socket -Variant 3x
```

### B. Building for Commercial Production Board (`Target: esp32c6`)

```powershell
# Example: Smart Switch 4X for Production ESP32-C6
powershell .\scripts\build_firmware.ps1 -Target esp32c6 -ProductType switch -Variant 4x

# Example: Smart Socket 3X for Production ESP32-C6
powershell .\scripts\build_firmware.ps1 -Target esp32c6 -ProductType socket -Variant 3x
```

---

## 4. Flashing & Monitoring (`COM6`)

Navigate to the firmware application directory:
```powershell
cd C:\Users\pavan\Downloads\Flutter\SMART_HOME_V1\firmware\platforms\esp32\smart-switch-app
```

### 1. Quick Incremental Flash (Keeps Wi-Fi and NVS state)
Uploads newly compiled binary code without erasing saved network credentials:
```powershell
idf.py -p COM6 flash
```

### 2. Live Serial Monitor
Inspect boot sequence, IP assignment, and relay events:
```powershell
idf.py -p COM6 monitor
```
*(Press `Ctrl + ]` to exit the serial monitor).*

### 3. Flash & Auto-Show QR Code in 1 Step (Recommended for Development)
To eliminate running manual Python commands to find or view the QR code, use the automated flash script:
```powershell
powershell .\scripts\flash_and_show_qr.ps1 -Port COM6
```
**What happens automatically:**
1. Flashes the firmware to `COM6`.
2. Listens to the bootloader output for the `DEV_COMMISSIONING_QR` payload.
3. **Prints an ASCII QR code directly inside PowerShell.**
4. **Automatically opens `dev_qr_preview.html` in your default browser.**

### 4. Show QR Code for Currently Connected Board (Without Re-flashing)
If the board is already flashed and you just need to display its QR code for phone scanning:
```powershell
powershell .\scripts\show_board_qr.ps1 -Port COM6
```

### 5. Clean Factory Reset Flash
If you ever need to manually wipe Wi-Fi credentials and start completely fresh:
```powershell
idf.py -p COM6 erase-flash flash monitor
```
*(Note: Because of our automatic NVS tag-migration, switching variants from `switch` to `socket` now automatically regenerates the correct serial tag `EH-SK` vs `EH-SW` without requiring a manual `erase-flash`).*

---

## 5. Verifying Successful Boot & Operation

When the device starts up, verify the deterministic boot banner in the serial monitor:

```text
==================================================
EH SMART HOME PROTOTYPE
==================================================
Product      : SMART_SOCKET
Model        : EH-SK-3X
Family       : esp32c6-socket-platform
Variant      : 3X
Hardware     : ESP32_DEV_BOARD
Firmware     : 1.0.0
Relay Count  : 3
Switch Count : 3
Status LED   : GPIO 13
Reset Button : GPIO 33 (Hold 10s)
Energy Meter : DISABLED (Standard Non-EM Panel)
BLE          : ENABLED
WiFi         : ENABLED
MQTT         : ENABLED
OTA          : ENABLED
==================================================
```

### Identity & BLE Verification:
1. **Dynamic BLE GATT Characteristic `0x6105`:** 
   Confirm in serial or during BLE pairing that the device advertises its true identity:
   `{"model":"EH Smart Socket 3X","type":"socket","channels":3,"has_energy":false,"sku":"eh-smart-socket-3x"}`.
2. **Automatic Serial Migration:** 
   If a socket firmware is flashed over an existing switch serial in NVS, verify the automatic migration log:
   `Serial number tag mismatch with running firmware (EH-SW4X-... vs EH-SK3X). Regenerating serial...`
3. **Commissioning QR:**
   Verify the dynamic QR string matches the flashed SKU:
   `DEV_COMMISSIONING_QR: EH1:<deviceId>:eh-smart-socket-3x:<secret>:123456`.

### Hardware Verification Checks:
1. **Relay Pre-Bias:** Ensure zero click or chatter on relays during power-on reset.
2. **Physical Wall Switches:** Toggle switch inputs on channels 1..N. Verify instant local toggle (<5ms) and LED pulse feedback.
3. **Unused Channels:** For 1X/2X/3X variants, verify pins for unassigned channels remain dead silent and do not react to electrical noise.
4. **10-Second Factory Reset:** Press and hold the reset button for 10 seconds. Observe rapid burst LED flashing followed by flash wipe and automatic reboot.

---

## 6. Industrial Manufacturing & Packaging Reference

For how devices are labeled, boxed, and paired in volume production (preventing sticker mix-ups between devices and retail packaging):
- Refer to [INDUSTRIAL_PACKAGING_AND_QR_ARCHITECTURE.md](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/firmware/run_commands/INDUSTRIAL_PACKAGING_AND_QR_ARCHITECTURE.md).

