# ESP32 4X Switch Firmware (Non-EM) — Build, Flash & Monitor Guide

This guide details the exact step-by-step commands to build, flash, and monitor the **4-Channel Smart Switch (Non-EM / Standard Panel)** firmware on the connected **ESP32-D0WD-V3** development board.

---

## Hardware & Environment Profile
- **Target MCU:** ESP32-D0WD-V3 (`CONFIG_IDF_TARGET="esp32"`)
- **Variant:** 4-Channel Relay, Physical Wall Switches, Non-EM (Energy Metering disabled)
- **Serial Port:** `COM6` (*Silicon Labs CP210x USB to UART Bridge*)
- **ESP-IDF Version:** v5.4.1 (`C:\esp\v5.4.1\esp-idf`)
- **Working Directory:**
  ```powershell
  cd C:\Users\pavan\Downloads\Flutter\SMART_HOME_V1\firmware\platforms\esp32\smart-switch-app
  ```

---

## 1. Activate ESP-IDF Environment

In your PowerShell terminal, navigate to the project directory and load the ESP-IDF tools:

```powershell
cd C:\Users\pavan\Downloads\Flutter\SMART_HOME_V1\firmware\platforms\esp32\smart-switch-app
. C:\esp\v5.4.1\esp-idf\export.ps1
```

> **Note:** The dot and space before the path (`. C:\...`) are required in PowerShell to export environment variables into the current session.

---

## 2. Build Firmware

To compile the application:

```powershell
idf.py build
```

### Clean Rebuild (Optional)
If you recently switched pin definitions, targets, or pulled repository updates:
```powershell
idf.py fullclean
idf.py build
```

---

## 3. Flash to ESP32

Flash the compiled bootloader, partition table, and application binary to `COM6`:

```powershell
idf.py -p COM6 flash
```

---

## 4. Monitor Serial Output

To view live boot diagnostics, IP assignment, and relay state logs:

```powershell
idf.py -p COM6 monitor
```

> **Shortcut to Exit Monitor:** Press `Ctrl + ]`.

---

## 5. Combined One-Liner (Build, Flash & Monitor)

Build the code, upload it to the board, and immediately open the serial monitor:

```powershell
idf.py -p COM6 flash monitor
```

---

## 6. Factory Erase & Flash (Recommended for Clean State)

To wipe old NVS Wi-Fi credentials, stored routine state, and restart with clean BLE commissioning:

```powershell
idf.py -p COM6 erase-flash flash monitor
```

---

## Verified Safe Hardware Pinout Summary (`ESP32-D0WD-V3`)

| Function | Pin | Notes |
|---|---|---|
| **Relay 1** | `GPIO 18` | Glitch-free digital output |
| **Relay 2** | `GPIO 19` | Glitch-free digital output |
| **Relay 3** | `GPIO 21` | Glitch-free digital output |
| **Relay 4** | `GPIO 22` | Glitch-free digital output |
| **Switch 1** | `GPIO 23` | Active-LOW, internal pull-up (Non-strapping) |
| **Switch 2** | `GPIO 25` | Active-LOW, internal pull-up (Non-strapping) |
| **Switch 3** | `GPIO 26` | Active-LOW, internal pull-up (Non-strapping) |
| **Switch 4** | `GPIO 27` | Active-LOW, internal pull-up (Non-strapping) |
| **Factory Reset Button** | `GPIO 33` | Primary safe production pin (10s hold required). GPIO 0 DevKit BOOT button also supported |
| **Status LED** | `GPIO 13` | Primary non-strapping pin (mirrored to GPIO 2 DevKit LED) |
