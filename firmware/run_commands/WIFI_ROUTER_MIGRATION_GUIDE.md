# EH Home — Wi-Fi Router & Network Migration Guide

This guide documents the exact checklist, code locations, and commands required to migrate the entire system (Laptop backend, Mobile app, and ESP32 board) to a new Wi-Fi router.

---

## 1. Network Topology Overview

```
+------------------------------------------------------------------------+
|                          NEW WI-FI ROUTER                              |
|                          (e.g., 192.168.0.0/24)                        |
+-----------------------------------+------------------------------------+
                                    |
            +-----------------------+-----------------------+
            |                                               |
            v                                               v
   [LAPTOP: Backend Host]                          [MOBILE PHONE: Flutter App]
   - Backend API  :3000 (0.0.0.0)                  - Backend URL:
   - MQTT Broker  :1883 (0.0.0.0)                    http://<NEW_LAPTOP_IP>:3000
            ^
            | (MQTT + Direct LAN REST)
            v
   [ESP32 SMART SWITCH]
   - CONFIG_EH_MQTT_BROKER_URI -> mqtt://<NEW_LAPTOP_IP>:1883
   - Stored NVS Wi-Fi Credentials -> New Router SSID & Password
   - Local LAN Server (:80) + UDP Announcement Broadcast (:4210)
```

---

## 2. Checklist Before Migrating

1. **Find Laptop's New Local IP**:
   Once connected to the new Wi-Fi, run this in PowerShell:
   ```powershell
   Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like '*Wi-Fi*' } | Select-Object IPAddress
   ```
   *(e.g., `192.168.0.227`)*

2. **Windows Firewall / Network Profile**:
   Ensure Windows Wi-Fi network profile is set to **Private** (Settings > Network & Internet > Wi-Fi > Private network).
   *If left as "Public", Windows Firewall will block ports 3000 and 1883 from the phone and ESP32.*

3. **2.4 GHz Wi-Fi Support**:
   The ESP32 radio only operates on **2.4 GHz**. Ensure your new router has a 2.4 GHz SSID broadcast enabled.

---

## 3. Files to Modify (When Ready to Proceed)

### File 1: ESP32 Firmware MQTT Broker URI
- **File**: `firmware/platforms/esp32/smart-switch-app/main/main.c` (around line 58)
- **Change**:
  ```c
  #ifndef CONFIG_EH_MQTT_BROKER_URI
  #define CONFIG_EH_MQTT_BROKER_URI "mqtt://<NEW_LAPTOP_IP>:1883"
  #endif
  ```

### File 2: Flutter App Default Backend URL
- **File**: `smart_home_application_v1/lib/core/config/app_config.dart` (around line 40)
- **Change**:
  ```dart
  return 'http://<NEW_LAPTOP_IP>:3000';
  ```

### File 3: Flutter App Login Screen Hint
- **File**: `smart_home_application_v1/lib/features/auth/login_screen.dart` (around line 53)
- **Change**:
  ```dart
  hintText: 'http://<NEW_LAPTOP_IP>:3000',
  ```

### File 4: Flutter LAN Subnet Discovery Fallback
- **File**: `smart_home_application_v1/lib/core/services/local_lan_device_service.dart` (around line 204)
- **Change**: Ensure the new subnet prefix (e.g., `'192.168.0'`) is included in fallback subnets:
  ```dart
  subnets.add('192.168.0');
  ```

### Backend (`backend/src/server.js`)
- **No changes needed**: The backend already listens on `HOST=0.0.0.0` and `PORT=3000`.

---

## 4. Re-Provisioning the ESP32 on the New Router

When ready, follow these steps to connect the board:

### Step 1: Rebuild Firmware
From workspace root:
```powershell
powershell .\scripts\build_firmware.ps1 -Target esp32 -ProductType socket -Variant 3x
```

### Step 2: Flash Board, Wipe Old Router NVS Credentials, and Display QR Code
```powershell
powershell .\scripts\flash_and_show_qr.ps1 -Port COM6 -EraseFirst
```
*(Using `-EraseFirst` wipes the damaged router's Wi-Fi credentials from NVS, causing the ESP32 to immediately enter BLE pairing mode upon boot, while automatically popping up the device QR code).*

### Step 3: Commission via Mobile App
1. Connect your mobile phone to the **new Wi-Fi router** (same Wi-Fi network as the laptop: `192.168.0.x`).
2. Open the Flutter app on your phone (it automatically connects to `http://192.168.0.227:3000`).
3. Tap **Add Device** > **Scan QR Code**.
4. Scan the QR code displayed in the browser / terminal.
5. Select the new 2.4 GHz Wi-Fi SSID, enter password, and finish setup.

