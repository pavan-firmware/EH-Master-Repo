# EH Smart Socket 3X — ESP32 Firmware

Production ESP-IDF firmware application for the **EH Smart Socket 3X** (3-gang smart relay socket with BL0942 power monitoring, physical switch debouncing, status LED signaling, BLE provisioning, and mTLS MQTT telemetry).

---

## 1. Pinned Toolchain Environment

This firmware line is strictly pinned to **ESP-IDF v5.4.1**. Automatic or silent migration to ESP-IDF 6.x is prohibited.

| Parameter | Specification / Exact Path |
|---|---|
| **Product / Firmware** | EH Smart Socket 3X (`eh-smart-switch-app`) |
| **Silicon Target** | `esp32` (ESP32 DevKit, 4MB Flash) |
| **ESP-IDF Framework** | `ESP-IDF v5.4.1` (`C:\esp\v5.4.1\esp-idf`) |
| **Python Environment** | `Python 3.14.6` (`C:\Users\pavan\.espressif\python_env\idf5.4_py3.14_env`) |
| **Toolchain / Compiler** | `xtensa-esp-elf-gcc (crosstool-NG esp-14.2.0_20241119) 14.2.0` |
| **GDB Debugger** | `xtensa-esp-elf-gdb 14.2_20240403` |
| **Build System** | CMake `3.30.2` + Ninja `1.12.1` + ccache `4.10.2` |
| **Managed Components** | None required (uses native ESP-IDF 5.4.1 built-in components + local monorepo components) |
| **Lock Policy** | Locked to `>=5.4.0, <6.0.0` |

---

## 2. Pin Mapping & Hardware Architecture

| Function | GPIO Pin | Hardware Configuration |
|---|---|---|
| **Relay CH1** | GPIO 18 | Active HIGH, boots OFF |
| **Relay CH2** | GPIO 19 | Active HIGH, boots OFF |
| **Relay CH3** | GPIO 21 | Active HIGH, boots OFF |
| **Switch In CH1** | GPIO 4 | Input pull-up, 50ms debounced |
| **Switch In CH2** | GPIO 5 | Input pull-up, 50ms debounced |
| **Switch In CH3** | GPIO 13 | Input pull-up, 50ms debounced |
| **BL0942 UART TX** | GPIO 17 | UART1 TX (to BL0942 RX) |
| **BL0942 UART RX** | GPIO 16 | UART1 RX (from BL0942 TX), 4800 baud |
| **Status LED** | GPIO 2 | Active HIGH, pattern driven |
| **Reset Button** | GPIO 0 | Active LOW, 10-second hold for factory reset |

---

## 3. Deterministic Build Procedure

### Step 1: Environment Activation
In any PowerShell prompt:
```powershell
. .\scripts\activate_idf5.4.ps1
```

### Step 2: Version Verification
```powershell
python "%IDF_PATH%\tools\idf.py" --version
# Expected: ESP-IDF v5.4.1
```

### Step 3: Build
```powershell
# From repository root:
powershell -ExecutionPolicy Bypass -File .\scripts\build_firmware.ps1

# Or manually from application folder:
cd firmware/platforms/esp32/smart-switch-app
idf.py set-target esp32
idf.py build
```

---

## 4. Flash and Monitor

```powershell
# Identify COM port (e.g. COM6 for Silicon Labs CP210x)
Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match "COM\d+" }

# Flash the firmware without erasing factory NVS/partition data:
idf.py -p COM6 flash

# Monitor serial output (115200 baud):
idf.py -p COM6 monitor
```

---

## 5. Toolchain Drift Detection & Monorepo Validation

Run the automated toolchain drift guard:
```bash
node scripts/check-esp-idf-toolchain.js
```

Or full monorepo validation:
```bash
node scripts/validate-repo.js
```

---

## 6. Future ESP-IDF Upgrade Policy

**DO NOT upgrade ESP-IDF automatically or silently.**

To perform a future toolchain migration (e.g., to ESP-IDF 6.x):
1. Create a dedicated migration issue/branch.
2. Read the official Espressif migration guide for target version.
3. Update dependency manifests and resolve component moves (e.g. `espressif/mqtt` in IDF 6.x).
4. Update source code for API deprecations.
5. Re-generate `sdkconfig.defaults` and resolve kconfig deprecations.
6. Run full firmware host tests and hardware integration suite.
7. Build clean binaries and verify memory budgets.
8. Perform low-voltage bench regression testing on physical hardware.
9. Commit as an explicit, reviewed version migration change.
