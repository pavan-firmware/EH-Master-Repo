# EH Home — Local Development Bootstrap Guide

This guide walks you through bootstrapping the complete EH Home environment from zero to running real physical device control with backend, database, and Flutter mobile client.

---

## Prerequisites

- **Node.js**: v18+ (tested on v20 & v24)
- **Flutter SDK**: 3.22+
- **ESP-IDF**: v5.4.1 (for ESP32 flashing)
- **PostgreSQL**: 14+ (or Docker)
- **Redis**: 7+ (or Docker)
- **EMQX Broker**: 5.8+ (or Docker)
- **Physical Device**: ESP32-D0WD-V3 connected via USB (COM port / `/dev/ttyUSB0`)

---

## Step 1: Environment Configuration

1. Copy the master `.env.example` to `.env`:
   ```powershell
   copy .env.example .env
   ```
2. Find your computer's local Wi-Fi IPv4 address:
   ```powershell
   ipconfig
   # Look for "IPv4 Address", e.g. 192.168.1.8
   ```
3. In `.env`, set:
   ```env
   BACKEND_BASE_URL=http://192.168.1.8:3000
   PORT=3000
   HOST=0.0.0.0
   ```

---

## Step 2: Start Infrastructure (PostgreSQL, Redis, EMQX)

### Option A: Using Docker Compose
```bash
docker compose -f deployments/docker/docker-compose.dev.yml up -d
```

### Option B: Local Services
Ensure PostgreSQL is running on port 5432 and Redis on port 6379.

---

## Step 3: Run Database Migrations

Apply and verify SQL migrations:
```powershell
node backend/migrations/verify-migrations.js
```

---

## Step 4: Start Backend Server

Start the Node.js backend server:
```powershell
node backend/src/server.js
```
Expected output:
```
[EH Home Backend] (development) Server running at http://0.0.0.0:3000/
[EH Home Backend] Health check available at http://0.0.0.0:3000/health
```

Verify backend health in browser or PowerShell:
```powershell
curl http://localhost:3000/health
# Response: {"status":"healthy","uptime":...}
```

---

## Step 5: Flash ESP32 Firmware

1. Open a PowerShell terminal with ESP-IDF environment:
   ```powershell
   . C:\esp\v5.4.1\esp-idf\export.ps1
   ```
2. Build and flash the firmware:
   ```powershell
   idf.py -C firmware/platforms/esp32/smart-switch-app set-target esp32
   idf.py -C firmware/platforms/esp32/smart-switch-app flash monitor
   ```
3. Verify firmware logs:
   ```
   [FACTORY] Device Identity: ID=4444688e-989d-458e-820e-ac62a99ed8e1, Serial=EH-SW3X-2026W12-00001
   [BLE] Advertising proprietary EH-PROV/1 UUID
   ```

---

## Step 6: Launch Flutter Mobile Application

1. Connect your Android phone via USB with USB Debugging enabled.
2. Run the application pointing to your computer's LAN IP:
   ```powershell
   cd smart_home_application_v1
   flutter run -d <DEVICE_ID> --dart-define=BACKEND_BASE_URL=http://192.168.1.8:3000
   ```

---

## Step 7: Onboarding & Hardware Control

1. **Open QR Preview**:
   Open `tools/manufacturing/dev_qr_preview.html` in your browser to display the device commissioning QR.
2. **Scan QR Code**:
   In the mobile app, tap **Add Device** -> **Scan QR Code**. Point camera at the screen QR.
3. **Provision Wi-Fi**:
   Enter your home Wi-Fi SSID and password. Tap **Connect**.
4. **Assign Room**:
   Select or create a room (e.g. `Living Room` or `Office`). Tap **Finish Setup**.
5. **Control Relays**:
   Tap **Switch 1**, **Switch 2**, or **Switch 3** from the dashboard or room page. Observe physical relay click and instant state confirmation!
