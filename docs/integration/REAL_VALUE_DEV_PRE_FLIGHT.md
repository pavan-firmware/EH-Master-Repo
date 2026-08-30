# EH HOME — REAL VALUE DEV PRE-FLIGHT VALIDATION
**Source-Level Code Inspection & Minimal Development Requirements Map**

> **STATUS**: VERIFIED AGAINST ACTUAL SOURCE CODE  
> **SCOPE**: Authoritative classification of what is strictly required for local physical development vs staging/production.  
> **RULE ENFORCEMENT**: Audit only. Zero production code modified.

---

## 1. Source-Level Code Verifications

The following table summarizes the exact findings from inspecting the runtime source code:

| Question | Source Finding | Code Evidence |
| :--- | :--- | :--- |
| **Does DEV use plain MQTT or MQTT TLS?** | **Plain TCP MQTT (`mqtt://127.0.0.1:1883`)** | `backend/src/shared/config.js:57` defaults to `mqtt://127.0.0.1:1883`. `docker-compose.yml:30` exposes port 1883. TLS is optional in DEV. |
| **Does Redis require authentication in DEV?** | **No** | `docker-compose.yml:18` uses standard `redis:7-alpine` without password. `config.js:55` defaults to `redis://localhost:6379`. |
| **Is MQTT backend auth enabled in DEV?** | **No** | Default EMQX docker container allows anonymous TCP connection on port 1883 for development. |
| **Is MQTT mTLS required in DEV?** | **No** | `MqttDeviceTransport` connects over TCP unless `MQTT_CA_FILE` / `MQTT_CLIENT_CERT` are explicitly supplied. |
| **Does `JWT_SECRET` have a DEV fallback?** | **Yes** | `backend/src/services/auth.service.js:13` generates ephemeral RSA 2048 keypairs automatically if not set. `config.js:64` provides dev fallback. |
| **Does `SESSION_SECRET` have a DEV fallback?** | **Yes** | `config.js:65` provides local dev fallback. |
| **How are user accounts created?** | **Dynamically via API/UI** | `POST /api/v1/auth/register` (`auth.router.js:26`) registers users on demand. No static database seed required. |
| **How does Flutter read configuration?** | **`--dart-define` at compile-time** | `AppConfig.dart:13` uses `String.fromEnvironment('BACKEND_BASE_URL')`. Flutter does NOT natively load `.env`. |
| **How does Backend load `.env`?** | **Command-line / `process.env`** | Node.js native `--env-file=.env` or shell environment variables. |

---

## 2. Complete Value Classification for Local Development

### A. REQUIRED FROM USER FOR CURRENT DEV (Must Provide)

| # | Value Name | Target Consumer | Where To Supply | Why It Is Required |
| :-: | :--- | :--- | :--- | :--- |
| **1** | `BACKEND_BASE_URL` | Flutter Client (`AppConfig`) | Flutter run command: `--dart-define=BACKEND_BASE_URL=http://<PC_LAN_IP>:3000` | Physical Android phone cannot resolve `localhost` and must reach your computer's Wi-Fi LAN IP. |
| **2** | `Target Wi-Fi SSID` | ESP32 (`wifi_manager.c`) | Entered into Mobile App UI at Onboarding | ESP32 must associate with your 2.4 GHz home network to reach the backend/MQTT. |
| **3** | `Target Wi-Fi Password` | ESP32 (`wifi_manager.c`) | Entered into Mobile App UI at Onboarding | WPA2/3 Pre-Shared Key for Wi-Fi authentication. |

---

### B. OPTIONAL FOR CURRENT DEV (Have Working Automatic Defaults)

| # | Value Name | Default Value in Code | Source File / Symbol | Action Needed |
| :-: | :--- | :--- | :--- | :--- |
| **1** | `PORT` | `3000` | `config.js:51` (`config.port`) | **DO NOT PROVIDE** (unless changing port) |
| **2** | `HOST` | `0.0.0.0` | `config.js:52` (`config.host`) | **DO NOT PROVIDE** (binds to all interfaces) |
| **3** | `DATABASE_URL` | `postgresql://eh_admin:eh_development_password_only@localhost:5432/eh_home_dev` | `config.js:54` (`config.databaseUrl`) | **DO NOT PROVIDE** (matches `docker-compose.yml`) |
| **4** | `REDIS_URL` | `redis://localhost:6379` | `config.js:55` (`config.redisUrl`) | **DO NOT PROVIDE** (matches `docker-compose.yml`) |
| **5** | `MQTT_BROKER_URL` | `mqtt://127.0.0.1:1883` | `config.js:57` (`config.mqttBrokerUrl`) | **DO NOT PROVIDE** (matches `docker-compose.yml`) |
| **6** | `JWT_SECRET` | Ephemeral RSA 2048 keypair | `auth.service.js:13` | **DO NOT PROVIDE** for local dev |
| **7** | `SESSION_SECRET` | `eh_local_dev_session_secret...` | `config.js:65` | **DO NOT PROVIDE** for local dev |
| **8** | `NODE_ENV` / `APP_ENV` | `'development'` | `config.js:10` / `app_config.dart:13` | **DO NOT PROVIDE** (defaults to development) |

---

### C. STAGING / PRODUCTION ONLY (NOT NEEDED FOR CURRENT DEV)

| # | Value Name | Purpose in Production | Current Dev Status |
| :-: | :--- | :--- | :--- |
| **1** | `MQTT_TLS_BROKER_URL` | mTLS connection on port 8883 | **DO NOT PROVIDE** (DEV uses plain TCP 1883) |
| **2** | `MQTT_CA_FILE` | Root CA Certificate for broker verification | **DO NOT PROVIDE** (DEV uses plain TCP) |
| **3** | `MQTT_CLIENT_CERT` | Backend mTLS client certificate | **DO NOT PROVIDE** (DEV uses plain TCP) |
| **4** | `MQTT_CLIENT_KEY` | Backend mTLS client private key | **DO NOT PROVIDE** (DEV uses plain TCP) |
| **5** | `MQTT_BACKEND_PASSWORD`| EMQX User password for ACL | **DO NOT PROVIDE** (EMQX dev allows anonymous) |
| **6** | `S3_ENDPOINT` / `S3_BUCKET` | Cloud storage for OTA firmware releases | **DO NOT PROVIDE** (Local dev testing) |

---

### D. VALUES GENERATED AUTOMATICALLY (DO NOT HARDCODE)

| Value | Generating Component | Source of Truth |
| :--- | :--- | :--- |
| `userId` | Backend `UserRepository.create()` | Generated dynamically upon user registration |
| `homeId` | Backend `HomeRepository.create()` | Generated dynamically when user creates/joins a home |
| `roomId` | Backend `RoomRepository.create()` | Generated dynamically when user creates a room |
| `commandId` | Backend `DeviceCommandService` | Generated as UUID v4 per command dispatch |
| `JWT Keypair` | Node.js `crypto.generateKeyPairSync` | Ephemeral RSA 2048 generated at server startup |

---

### E. VALUES READ FROM HARDWARE / FACTORY (DO NOT HARDCODE)

| Value | Storage on Hardware | How App Discovers It |
| :--- | :--- | :--- |
| `deviceId` (UUID) | ESP32 Flash `fact_v2` NVS | Read dynamically over BLE GATT Characteristic `6105` |
| `serialNumber` | ESP32 Flash `fact_v2` NVS | Read dynamically over BLE GATT Characteristic `6105` |
| `commissioningSecret` | ESP32 Flash `fact_v2` NVS | Scanned dynamically from the QR Code via camera |
| `BL0942 Energy Data` | BL0942 Hardware Registers | Parsed dynamically over UART1 @ 4800 baud every 10s |

---

## 3. Exact Commands to Apply & Validate

### 1. Find Your Host LAN IPv4
```powershell
ipconfig
# Find your Wi-Fi IPv4 Address, e.g., 192.168.1.8
```

### 2. Start Infrastructure
```powershell
docker compose up -d
```

### 3. Verify Database Migrations
```powershell
node backend/migrations/verify-migrations.js
```

### 4. Start Backend Server
```powershell
node backend/src/server.js
```
*Validation:*
```powershell
curl http://localhost:3000/health
# Response: {"status":"healthy", ...}
```

### 5. Flash ESP32 Firmware
```powershell
. C:\esp\v5.4.1\esp-idf\export.ps1
idf.py -C firmware/platforms/esp32/smart-switch-app flash monitor
```

### 6. Launch Flutter App
```powershell
cd smart_home_application_v1
flutter run -d <DEVICE_ID> --dart-define=BACKEND_BASE_URL=http://<YOUR_LAN_IP>:3000
```

---

## 4. Development Startup Order

```
1. Docker Compose (PostgreSQL, Redis, EMQX)
   ↓
2. Backend Migrations Check
   ↓
3. Backend Server (node backend/src/server.js)
   ↓
4. ESP32 Flashed & Advertising BLE
   ↓
5. Open QR Preview (tools/manufacturing/dev_qr_preview.html)
   ↓
6. Launch Flutter with --dart-define=BACKEND_BASE_URL=http://<YOUR_LAN_IP>:3000
   ↓
7. In App: Tap 'Add Device' -> Scan Screen QR -> Enter Wi-Fi Credentials
   ↓
8. Real Physical Control Active!
```

---

## 5. Final User Value Form (For Current DEV Setup)

Since the repository provides working defaults for Docker services, you only need to provide **one single value** to run the complete environment:

```yaml
# =============================================================================
# THE ONLY VALUE NEEDED TO RUN CURRENT LOCAL DEV
# =============================================================================

BACKEND_HOST_LAN_IP: <YOUR_COMPUTER_WIFI_IPV4>  # e.g., 192.168.1.8
```

*(Wi-Fi SSID and password will simply be typed into the mobile application on your phone during onboarding).*
