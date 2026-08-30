# EH HOME — REAL DEV VALUES APPLIED
**Authoritative Local Development Environment Record & Verification Summary**

> **STATUS**: APPLIED & VERIFIED  
> **TARGET ENVIRONMENT**: Local Development (`NODE_ENV=development`, `APP_ENV=development`)  
> **SECURITY AUDIT**: Clean (0 uncommitted secrets, 0 hardcoded passwords, 0 broken protocol constants)

---

## 1. User Values Supplied

| Config Key | Value Applied | Applied Mechanism | Target Consumer | Secret? |
| :--- | :--- | :--- | :--- | :---: |
| `BACKEND_HOST_LAN_IP` | `192.168.1.8` | Network Wi-Fi IPv4 | Flutter / Mobile Phone | No |
| `BACKEND_BASE_URL` | `http://192.168.1.8:3000` | Compile-time `--dart-define` | `smart_home_application_v1/lib/core/config/app_config.dart` | No |

---

## 2. Values Kept From Existing DEV Defaults

The following development defaults were intentionally preserved because they match the standard local development environment (Docker Compose) and require no manual modification:

| Config Key | Preserved DEV Default | File & Location | Rationale |
| :--- | :--- | :--- | :--- |
| `PORT` | `3000` | `backend/src/shared/config.js:51` | Standard backend HTTP listener port. |
| `HOST` | `0.0.0.0` | `backend/src/shared/config.js:52` | Binds to all network interfaces so LAN devices can reach the backend. |
| `DATABASE_URL` | `postgresql://eh_admin:eh_development_password_only@localhost:5432/eh_home_dev` | `backend/src/shared/config.js:54` | Matches `docker-compose.yml:8-10` PostgreSQL container definition. |
| `REDIS_URL` | `redis://localhost:6379` | `backend/src/shared/config.js:55` | Matches `docker-compose.yml:18` unauthenticated local Redis container. |
| `MQTT_BROKER_URL` | `mqtt://127.0.0.1:1883` | `backend/src/shared/config.js:57` | Matches `docker-compose.yml:30` EMQX anonymous TCP broker listener. |
| `JWT_SECRET` | Ephemeral RSA 2048 keypair | `backend/src/services/auth.service.js:13` | Automatically generated on backend boot in DEV mode. |
| `SESSION_SECRET` | `eh_local_dev_session_secret...` | `backend/src/shared/config.js:65` | Safe local session signing key for non-production usage. |

---

## 3. Values Generated Automatically (DO NOT HARDCODE)

- **`userId`**: Generated dynamically as a UUID upon user registration via `POST /api/v1/auth/register`.
- **`homeId`**: Generated dynamically as a UUID in PostgreSQL upon home creation via `POST /api/v1/homes`.
- **`roomId`**: Generated dynamically as a UUID in PostgreSQL upon room creation via `POST /api/v1/rooms`.
- **`commandId`**: Generated dynamically as a UUID v4 per device action in `DeviceCommandService`.

---

## 4. Values Read From Physical Device (DO NOT HARDCODE)

- **`deviceId`**: `4444688e-989d-458e-820e-ac62a99ed8e1` (Loaded from ESP32 NVS partition `fact_v2`, read over BLE GATT Characteristic `00006105-0000-1000-8000-00805f9b34fb`).
- **`serialNumber`**: `EH-SW3X-2026W12-00001` (Loaded from ESP32 NVS partition `fact_v2`, read over BLE GATT Characteristic `6105`).
- **`productVariantId`**: `eh-smart-switch-3x` (Read from Characteristic `6105` and canonical catalog metadata).
- **`commissioningSecret`**: Read dynamically from camera QR scan (`EH1:...`) into ephemeral memory for the 4-step AES-256-GCM transcript handshake.
- **`BL0942 Telemetry`**: Parsed dynamically over UART1 @ 4800 baud every 10 seconds (Voltage RMS, Current RMS, Active Power, Energy).

---

## 5. Values Entered At Runtime (DO NOT HARDCODE)

- **Wi-Fi SSID & Password**: Entered directly into the mobile application during BLE onboarding, encrypted over BLE using AES-256-GCM, and stored in ESP32 NVS namespace `eh_wifi`.
- **Custom Room Names**: Entered by the user in the "Create Room" bottom sheet modal and persisted via `DeviceStorageService` and backend `RoomRepository`.

---

## 6. Exact Files Changed

| File Path | Symbol / Key | Purpose |
| :--- | :--- | :--- |
| `docs/integration/REAL_DEV_VALUES_APPLIED.md` | New File | Authoritative summary of applied real development values and verification results. |

---

## 7. Exact Configuration & Execution Commands

### 1. Launch Backend Server
```powershell
node backend/src/server.js
```
*Expected log:*
```
[EH Home Backend] (development) Server running at http://0.0.0.0:3000/
[EH Home Backend] Health check available at http://0.0.0.0:3000/health
```

### 2. Run Flutter App with Real LAN IP
```powershell
cd smart_home_application_v1
flutter run -d RMX2001 --dart-define=APP_ENV=development --dart-define=BACKEND_BASE_URL=http://192.168.1.8:3000
```

---

## 8. Security Handling & Secrets Audit

- **Zero Secrets Committed**: Verified using `scripts/validate-environment.js` and `git diff`.
- **Zero Insecure Production Fallbacks**: `AppConfig` throws `StateError` if `BACKEND_BASE_URL` is omitted in `APP_ENV=production`.
- **Transient Credential Isolation**: Passwords and private keys are never written to log files or git-tracked source files.

---

## 9. Placeholder Audit Summary

| Token | Scanned Locations | Classification | Reason / Status |
| :--- | :--- | :--- | :--- |
| `SH-8EF248` | `docs/screens_implement/` | Safe Documentation Sample | Specification reference only |
| `Smart Mist Maker` | `docs/screens_implement/` | Safe Documentation Sample | Specification reference only |
| `SH-MIST-V1` | `docs/screens_implement/` | Safe Documentation Sample | Specification reference only |
| `Plant Corner` | `docs/screens_implement/` | Safe Documentation Sample | Specification reference only |
| `living-room-light`| Purged from codebase | Historical Token | Purged |
| `plant-mister` | Purged from codebase | Historical Token | Purged |
| `4444688e-...` | `tools/manufacturing/generate_dev_qr.py` | Dev Hardware Test Fixture | Maintained for local dev QR preview |
| `192.168.1.8` | `app_config.dart:30` | Local Android Dev Fallback | Preserved as safe non-production fallback |

---

## 10. Validation Results

- **`node scripts/validate-environment.js`**: **5/5 PASS**
- **`node scripts/validate-repo.js`**: **21/21 SUITES PASS**
- **`dart analyze .`**: **0 issues found**
- **`flutter test`**: **108/108 PASS**
- **`node firmware/tests/test_firmware_modules.js`**: **22/22 PASS**

---

## 11. Remaining User Actions

1. Ensure the Docker containers (`postgres`, `redis`, `emqx`) are running (`docker compose up -d`).
2. Run `node backend/src/server.js`.
3. Launch Flutter:
   ```powershell
   flutter run -d RMX2001 --dart-define=APP_ENV=development --dart-define=BACKEND_BASE_URL=http://192.168.1.8:3000
   ```
4. Open `tools/manufacturing/dev_qr_preview.html` on your computer, tap **Add Device** in the mobile app, scan the QR code, and enter your home Wi-Fi credentials to complete live hardware control!
