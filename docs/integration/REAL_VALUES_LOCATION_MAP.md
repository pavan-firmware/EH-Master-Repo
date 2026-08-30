# EH HOME — REAL VALUES LOCATION MAP
**Authoritative Monorepo Configuration & Integration Location Audit**

> **AUDIT STATUS**: COMPLETED  
> **SCOPE**: Entire Monorepo (`smart_home_application_v1/`, `backend/`, `firmware/`, `tools/`, `packages/`, `scripts/`, `product-definitions/`, `docs/`)  
> **RULE ENFORCEMENT**: Strict audit only. Zero code modifications performed.

---

## A. Executive Summary

This document maps **every value, configuration key, environment variable, factory identifier, runtime entity, secret, and test fixture** across the entire EH Home repository.

When transitioning to a real development or production environment, the user must know **exactly what values to provide, where to place them, how they are generated, and what breaks if they are missing**.

### Summary of Audit Totals:
- **Total Actionable User-Provided Values**: 9 (Backend URL, DB URL, Redis URL, MQTT Broker, TLS certs, JWT Secret, Dev Account, Wi-Fi SSID, Wi-Fi Password)
- **Total Environment Variables**: 18
- **Total Runtime-Generated Entities**: 7 (Home ID, Room ID, User ID, Device Claim Record, Live Relay States, Energy Telemetry, Command Receipts)
- **Total Factory-Generated Values**: 5 (Device UUID, Serial Number, Commissioning Secret, X.509 Device Certificate, QR Payload)
- **Total "Do Not Edit" Protocol Constants**: 12 (BLE Service/Char UUIDs, GATT Handshake opcodes, Product IDs, Partition Labels)
- **Total Secrets Identified**: 7 (Database Password, Redis Password, MQTT Private Key, JWT Secret, Session Secret, Commissioning Secret, Wi-Fi Password)

---

## B. User-Provided Values

These values **must be provided by the developer or deployment administrator**. They cannot be inferred or automatically generated.

| Value | Category | Format / Example | Target Location | Secret? |
| :--- | :--- | :--- | :--- | :--- |
| `BACKEND_BASE_URL` | Network | `http://192.168.1.8:3000` (Dev) / `https://api.eh-home.io` (Prod) | `.env` / `--dart-define` | No |
| `DATABASE_URL` | Database | `postgresql://user:pass@host:5432/dbname` | `.env` (`DATABASE_URL`) | **YES** |
| `REDIS_URL` | Cache | `redis://:pass@host:6379` | `.env` (`REDIS_URL`) | **YES** (if authed) |
| `MQTT_BROKER_URL` | Broker | `mqtt://host:1883` / `mqtts://host:8883` | `.env` (`MQTT_BROKER_URL`) | No |
| `MQTT_CLIENT_KEY` | Security | Path to client private key `.key` | `.env` / Secret Store | **YES** |
| `JWT_SECRET` | Security | 32+ character random string (`openssl rand -hex 32`) | `.env` (`JWT_SECRET`) | **YES** |
| `DEV_USER_EMAIL` | Identity | `developer@eh-home.local` | Auth Screen / Seed Script | No |
| `DEV_USER_PASSWORD`| Identity | Strong password | Auth Screen / Seed Script | **YES** |
| `Wi-Fi SSID & Pass`| Onboarding | Real local 2.4 GHz network credentials | Entered in Mobile App UI | **YES** (Pass) |

---

## C. Environment Configuration

### Root & Backend `.env`
- **File**: `.env` (gitignored, copied from `.env.example`)
- **Loader**: `backend/src/shared/config.js` (lines 43–76)
- **Startup Validation**: `validateConfig(config)` at line 19 of `config.js`
- **Controlled Keys**:
  - `NODE_ENV`: `'development'` | `'staging'` | `'production'` | `'test'`
  - `PORT`: HTTP listener port (default `3000`)
  - `HOST`: HTTP listener host (default `'0.0.0.0'`)
  - `BACKEND_BASE_URL`: Public API endpoint
  - `DATABASE_URL`: PostgreSQL connection string
  - `REDIS_URL`: Redis URI
  - `MQTT_BROKER_URL` / `MQTT_TLS_BROKER_URL`: EMQX URI
  - `MQTT_PORT` / `MQTT_TLS_PORT`: Broker port
  - `MQTT_BACKEND_USERNAME` / `MQTT_BACKEND_PASSWORD`: Backend service auth
  - `MQTT_CA_FILE` / `MQTT_CLIENT_CERT` / `MQTT_CLIENT_KEY`: mTLS paths
  - `JWT_SECRET` / `SESSION_SECRET`: Token signing secrets
  - `JWT_EXPIRES_IN` / `REFRESH_TOKEN_EXPIRES_IN`: Token lifetimes (`15m` / `30d`)
  - `S3_ENDPOINT` / `S3_BUCKET` / `S3_ACCESS_KEY` / `S3_SECRET_KEY`: OTA storage

---

## D. Database Configuration

- **File**: `docker-compose.yml` (lines 4–15) & `backend/src/shared/config.js` (line 51)
- **Engine**: PostgreSQL 14+ (tested on PostgreSQL 16-alpine)
- **Development Default**: `postgresql://eh_admin:eh_development_password_only@localhost:5432/eh_home_dev`
- **Verification Script**: `backend/migrations/verify-migrations.js`
- **Tables Created by Migrations**:
  `users`, `refresh_tokens`, `homes`, `home_memberships`, `floors`, `rooms`, `product_families`, `products`, `product_variants`, `capabilities`, `product_capabilities`, `product_images`, `devices`, `device_credentials`, `network_identity`, `device_authorizations`, `device_state`, `channel_state`, `device_commands`, `device_events`, `audit_logs`, `outbox`, `provisioning_sessions`
- **User Action**: Provide managed production PostgreSQL URI in `.env`.

---

## E. Redis Configuration

- **File**: `docker-compose.yml` (lines 17–24) & `backend/src/shared/config.js` (line 52)
- **Engine**: Redis 7+
- **Development Default**: `redis://localhost:6379`
- **Consumer**: Realtime event worker and command coordination (`backend/src/workers/realtime-event-worker.js`)
- **User Action**: Provide Redis URI with password authentication for production.

---

## F. MQTT Configuration

- **Broker**: EMQX 5.8.0
- **TCP Port**: `1883` | **mTLS Port**: `8883` | **Dashboard**: `18083`
- **Files**:
  - `backend/src/services/mqtt-device-transport.js` (lines 123–138)
  - `firmware/common/mqtt_transport/`
  - `docker-compose.yml` (lines 26–37)
- **Security Invariant**: `rejectUnauthorized: true` is strictly enforced.
- **Topics**:
  - Commands: `eh/v1/devices/{deviceId}/commands` (QoS 1, retain false)
  - Receipts: `eh/v1/devices/{deviceId}/command-receipts` (QoS 1, retain false)
  - State: `eh/v1/devices/{deviceId}/state` (QoS 1, retain false)
  - Telemetry: `eh/v1/devices/{deviceId}/telemetry` (QoS 0, retain false)
  - Availability: `eh/v1/devices/{deviceId}/availability` (QoS 1, retain true, LWT)

---

## G. Authentication Configuration

- **Files**: `backend/src/services/auth.service.js` & `backend/src/shared/auth-middleware.js`
- **Algorithm**: HMAC-SHA256 (JWT)
- **Tokens**: Access Token (short-lived, 15m) + Refresh Token (long-lived, 30d)
- **User Action**: Configure `JWT_SECRET` and `SESSION_SECRET` with high-entropy keys. Never use development default in production.

---

## H. Flutter Configuration

- **Configuration Class**: `smart_home_application_v1/lib/core/config/app_config.dart`
- **Compile-Time Flags**:
  - `--dart-define=APP_ENV=development|staging|production`
  - `--dart-define=BACKEND_BASE_URL=http://<YOUR_LAN_IP>:3000`
- **API Client**: `smart_home_application_v1/lib/core/api/api_client.dart`
- **SSE Client**: `smart_home_application_v1/lib/core/api/sse_client.dart`
- **Production Guard**: If `APP_ENV == 'production'` and `BACKEND_BASE_URL` is empty, `AppConfig.backendBaseUrl` throws `StateError`.

---

## I. Android Configuration

- **Manifest**: `smart_home_application_v1/android/app/src/main/AndroidManifest.xml`
- **Permissions**:
  - `INTERNET`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`
  - `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`
  - `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
  - `CAMERA`
- **Cleartext Traffic**: `android:usesCleartextTraffic="true"` (for local HTTP development). Must be changed to `false` (or network security config with HTTPS only) for production release.
- **Gradle**: `smart_home_application_v1/android/app/build.gradle` (`applicationId: com.example.smart_home_application_v1`, `compileSdkVersion: flutter.compileSdkVersion`).

---

## J. Firmware Configuration

- **Target**: ESP32 / ESP32-C6 (ESP-IDF v5.4.1)
- **Partition Table**: `firmware/platforms/esp32/smart-switch-app/partitions.csv`
  - `nvs`: `0x9000` (24 KB) — Wi-Fi credentials (`eh_wifi` namespace)
  - `otadata`: `0xF000` (8 KB) — Active OTA boot slot
  - `fact_v2`: `0x12000` (16 KB) — Immutable factory provisioning partition
  - `ota_0`: `0x20000` (1792 KB) — Primary firmware slot
  - `ota_1`: `0x1E0000` (1792 KB) — Secondary OTA update slot
  - `storage`: `0x3A0000` (384 KB) — SPIFFS certificate/asset storage
- **Flash Size**: 4MB (`CONFIG_ESPTOOLPY_FLASHSIZE_4MB=y`)
- **BLE Stack**: NimBLE (`CONFIG_BT_NIMBLE_ENABLED=y`)
- **Factory Reset Hook**: UART console `FACTORY_RESET\n` or 10s physical button hold wipes `eh_wifi` and boots to `APP_STATE_BLE_COMMISSIONING`.

---

## K. Factory Device Data

Generated by `tools/manufacturing/factory_provisioner.py` and written to `fact_v2` NVS partition:

| Key | Storage / Transport | Format | Purpose |
| :--- | :--- | :--- | :--- |
| `device_id` | NVS string (37 bytes) | UUID v4 (e.g. `4444688e-989d-458e-820e-ac62a99ed8e1`) | Unique hardware identity |
| `serial_number` | NVS string (32 bytes) | `EH-SW3X-YYYYWww-NNNNN` | Inventory & manufacturing tracking |
| `comm_secret` | NVS blob (32 bytes) | 256-bit raw random key | AES-256-GCM BLE commissioning key |
| `cert_fp` | NVS string (65 bytes) | SHA-256 hex string | Client certificate fingerprint for mTLS |
| `QR Payload` | Sticker on hardware | `EH1:<uuid>:<variant>:<secret_hex>:<setup_code>` | Camera onboarding payload |

---

## L. Physical Device Runtime Data

Reported by ESP32 dynamically during operation:

- **Wi-Fi IP**: Obtained via DHCP from AP (`IP_EVENT_STA_GOT_IP`).
- **Relay States**: Channel 1, 2, 3 (`true` / `false`). Reported on toggle via MQTT and BLE.
- **Energy Telemetry**: BL0942 UART registers parsed every 10 seconds:
  - Voltage RMS (V)
  - Current RMS (A)
  - Active Power (W)
  - Accumulated Energy (kWh)
- **Wi-Fi RSSI**: Signal strength in dBm.

---

## M. Home / Room / User Data

Stored in backend database and fetched dynamically at runtime by Flutter:

- **User ID**: Generated by `UserRepository.create()` upon registration.
- **Home ID**: Generated by `HomeRepository.create()` when a home is created.
- **Room ID**: Generated by `RoomRepository.create()` when a user adds a room.
- **Device Claim**: Created when `DeviceClaimService.claimDevice()` binds a device ID to a Home and Room.
- **Rule**: Never hardcode User, Home, or Room IDs into client source code.

---

## N. PKI / Certificates

- **CA Manager**: `tools/manufacturing/ca_manager.py`
- **Root CA**: Generates `certs/ca/root-ca.pem` and `certs/ca/root-ca.key`.
- **EMQX Server Cert**: Signed by Root CA (SAN: `localhost`, `127.0.0.1`, `mqtt.eh-home.io`).
- **Backend Client Cert**: `certs/backend/backend-cert.pem` (mTLS client authentication).
- **Device Client Cert**: Generated during factory provisioning (`CN = deviceId`).
- **OTA Signing Key**: ECDSA P-256 private key used by `tools/manufacturing/sign_firmware.py`.

---

## O. OTA (Over-The-Air Update)

- **Service**: `backend/src/services/ota.service.js`
- **API**: `GET /api/v1/ota/check?productVariantId=...&hardwareRevision=...&currentVersion=...`
- **Manifest Format**: Signed JSON containing `version`, `minFirmwareVersion`, `targetHardwareRevisions`, `binarySha256`, `signature`, and `downloadUrl`.
- **Anti-Rollback**: Firmware rejects versions `< currentVersion` or violating `minFirmwareVersion` bridge constraint.

---

## P. Manufacturing

- **Tool**: `tools/manufacturing/factory_provisioner.py`
- **Output Files**:
  - `out/nvs_<device_id>.csv`: NVS partition binary generation source
  - `out/manufacturing_audit.json`: Immutable audit trail
  - `out/certs/<device_id>.crt` / `.key`: Device mTLS credentials
- **Preview QR Tool**: `tools/manufacturing/generate_dev_qr.py` -> `tools/manufacturing/dev_qr_preview.html`

---

## Q. Test-Only Values

The following are controlled test fixtures used **exclusively in automated test suites**:

| Value | File | Context |
| :--- | :--- | :--- |
| `dev_aaaa_1111` / `dev_bbbb_2222` | `smart_home_application_v1/test/phase9_lifecycle_convergence_test.dart` | Multi-device command isolation test |
| `home-test-1` / `home-test-2` | `smart_home_application_v1/test/phase9_lifecycle_convergence_test.dart` | Multi-home context isolation test |
| `test@example.com` / `admin@example.com` | `backend/tests/phase7a-auth.test.js` | User auth boundary test |
| `192.168.1.100` | `firmware/platforms/esp32/smart-switch-app/main/wifi_manager.c` | Host unit test IP mock (`#ifndef ESP_PLATFORM`) |
| `eh_development_password_only` | `docker-compose.yml` | Local developer Docker container |

---

## R. Placeholder / Dummy Audit

| Search Term | Found Locations | Classification | Status |
| :--- | :--- | :--- | :--- |
| `SH-8EF248` | `docs/screens_implement/` | Documentation Sample | Safe Doc Only |
| `Smart Mist Maker` | `docs/screens_implement/` | Documentation Sample | Safe Doc Only |
| `SH-MIST-V1` | `docs/screens_implement/` | Documentation Sample | Safe Doc Only |
| `Plant Corner` | `docs/screens_implement/` | Documentation Sample | Safe Doc Only |
| `living-room-light`| Purged from code | Historical Token | Purged |
| `plant-mister` | Purged from code | Historical Token | Purged |
| `4444688e-...` | `tools/manufacturing/generate_dev_qr.py` | Development Hardware Test Fixture | Maintained for dev board |
| `EH-SW3X-...` | `tools/manufacturing/generate_dev_qr.py` | Development Hardware Test Fixture | Maintained for dev board |

---

## S. Secrets Audit

| Secret Identifier | Location | Classification | Recommended Store |
| :--- | :--- | :--- | :--- |
| `DATABASE_URL` Password | `.env` | Environment Secret | Local `.env` / AWS Secrets Manager |
| `REDIS_URL` Password | `.env` | Environment Secret | Local `.env` / AWS Secrets Manager |
| `JWT_SECRET` | `.env` | Cryptographic Token Secret | Local `.env` / AWS Secrets Manager |
| `SESSION_SECRET` | `.env` | Cryptographic Token Secret | Local `.env` / AWS Secrets Manager |
| `MQTT_BACKEND_PASSWORD` | `.env` | Service Credential | Local `.env` / AWS Secrets Manager |
| `MQTT_CLIENT_KEY` | Filesystem | Private Key | File permissions `0600` / KMS |
| `commissioning_secret` | Flash `fact_v2` / QR | Factory Key | Hardware Secure Element / Encrypted Flash |
| `Wi-Fi Password` | In-Memory / Flash NVS | User Credential | ESP32 NVS (Encrypted via NVS encryption) |

---

## T. Files That Must NOT Be Modified ("Do Not Edit" Table)

These values are protocol standards, catalog contracts, or immutable schemas:

| File | Immutable Symbol / Key | Reason |
| :--- | :--- | :--- |
| `smart_home_application_v1/lib/features/onboarding/ble/ble_commissioning_channel.dart` | `SERVICE_UUID: 00006101-...` | Proprietary EH-PROV/1 BLE Service Protocol |
| `smart_home_application_v1/lib/features/onboarding/ble/ble_commissioning_channel.dart` | `CHAR_UUID_TRANSCRIPT: 00006102-...` | EH-PROV/1 Handshake Characteristic |
| `smart_home_application_v1/lib/features/onboarding/ble/ble_commissioning_channel.dart` | `CHAR_UUID_WIFI_PROV: 00006103-...` | EH-PROV/1 Wi-Fi Provisioning Characteristic |
| `smart_home_application_v1/lib/features/onboarding/ble/ble_commissioning_channel.dart` | `CHAR_UUID_DEV_IDENTITY: 00006105-...` | Device Identity Characteristic |
| `product-definitions/smart-switch/3x/metadata.json` | `productVariantId: eh-smart-switch-3x` | Canonical Product Catalog Definition |
| `product-definitions/smart-switch/3x/metadata.json` | `channelCount: 3` | Physical hardware specification |
| `firmware/platforms/esp32/smart-switch-app/partitions.csv` | `fact_v2`, `otadata`, `ota_0`, `ota_1` | Flash memory partition layout |
| `packages/contracts/` | JSON Schema definitions | Canonical API & Event contracts |

---

## U. Master Masters Table

| # | Value Name | Current Default | File Path | Symbol / Key | Value Type | Real Source | User Action | Secret? |
| :-: | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :-: |
| **1** | `BACKEND_BASE_URL` | `http://192.168.1.8:3000` | `app_config.dart` | `AppConfig.backendBaseUrl` | Config | LAN IP / Domain | Pass `--dart-define` | No |
| **2** | `DATABASE_URL` | `postgresql://...@localhost` | `config.js` | `config.databaseUrl` | Config | PostgreSQL URI | Set in `.env` | **YES** |
| **3** | `REDIS_URL` | `redis://localhost:6379` | `config.js` | `config.redisUrl` | Config | Redis URI | Set in `.env` | **YES** |
| **4** | `MQTT_BROKER_URL` | `mqtt://127.0.0.1:1883` | `config.js` | `config.mqttBrokerUrl` | Config | EMQX URI | Set in `.env` | No |
| **5** | `JWT_SECRET` | `eh_local_dev_jwt_...` | `config.js` | `config.jwtSecret` | Config | 32+ char secret | Set in `.env` | **YES** |
| **6** | `SESSION_SECRET` | `eh_local_dev_sess_...`| `config.js` | `config.sessionSecret` | Config | 32+ char secret | Set in `.env` | **YES** |
| **7** | `DEV_USER_EMAIL` | `developer@eh-home...` | `.env.example` | `DEV_USER_EMAIL` | User | Real Email | Enter in App | No |
| **8** | `DEV_USER_PASSWORD`| `DeveloperPass123!` | `.env.example` | `DEV_USER_PASSWORD` | User | Real Password | Enter in App | **YES** |
| **9** | `deviceId` | Factory NVS UUID | `fact_v2` | `device_id` | Factory | `factory_provisioner` | Flash to ESP32 | No |
| **10**| `serialNumber` | Factory NVS Serial | `fact_v2` | `serial_number` | Factory | `factory_provisioner` | Flash to ESP32 | No |
| **11**| `commissioningSecret` | Factory NVS 32B | `fact_v2` | `comm_secret` | Factory | `factory_provisioner` | Scan QR | **YES** |
| **12**| `homeId` | Backend DB UUID | DB `homes` | `home.id` | Runtime | Backend API | Generated at runtime | No |
| **13**| `roomId` | Backend DB UUID | DB `rooms` | `room.id` | Runtime | Backend API | Generated at runtime | No |
| **14**| `Wi-Fi SSID` | User Network | App Input | `wifi_ssid` | Runtime | Mobile App UI | Enter in App | No |
| **15**| `Wi-Fi Password` | User Network Pass | App Input | `wifi_password` | Runtime | Mobile App UI | Enter in App | **YES** |

---

## V. User Value Collection Form

When you are ready to supply your real values, fill out the form below:

```yaml
# =============================================================================
# REAL VALUES TO BE PROVIDED BY USER (DO NOT COMMIT SECRETS TO GIT)
# =============================================================================

Environment: DEV  # (DEV / STAGING / PROD)

# 1. Backend Server
BACKEND_HOST_IP: <TO BE PROVIDED - e.g. 192.168.1.8>
BACKEND_PORT: 3000
BACKEND_BASE_URL: <TO BE PROVIDED - e.g. http://192.168.1.8:3000>

# 2. Database (PostgreSQL)
DATABASE_HOST: <TO BE PROVIDED - e.g. localhost>
DATABASE_PORT: 5432
DATABASE_NAME: <TO BE PROVIDED - e.g. eh_home_dev>
DATABASE_USER: <TO BE PROVIDED - e.g. eh_admin>
DATABASE_PASSWORD: <STORE SECURELY IN .env>
DATABASE_URL: <STORE SECURELY IN .env>

# 3. Cache (Redis)
REDIS_HOST: <TO BE PROVIDED - e.g. localhost>
REDIS_PORT: 6379
REDIS_URL: <STORE SECURELY IN .env>

# 4. MQTT Broker (EMQX)
MQTT_HOST: <TO BE PROVIDED - e.g. localhost>
MQTT_PORT: 1883
MQTT_TLS_PORT: 8883
MQTT_BROKER_URL: <TO BE PROVIDED - e.g. mqtt://127.0.0.1:1883>
MQTT_BACKEND_USERNAME: <TO BE PROVIDED - e.g. eh_backend_service>
MQTT_BACKEND_PASSWORD: <STORE SECURELY IN .env>

# 5. Security & Tokens
JWT_SECRET: <STORE SECURELY IN .env - MIN 32 CHARACTERS>
SESSION_SECRET: <STORE SECURELY IN .env - MIN 32 CHARACTERS>

# 6. Development Account
DEV_USER_EMAIL: <TO BE PROVIDED - e.g. your_email@domain.com>
DEV_USER_PASSWORD: <ENTER DIRECTLY IN APP / STORE SECURELY>

# 7. Hardware & Network (Runtime)
TARGET_WIFI_SSID: <ENTER IN APP ONBOARDING SCREEN>
TARGET_WIFI_PASSWORD: <ENTER IN APP ONBOARDING SCREEN>
PHYSICAL_ESP32_PORT: <e.g. COM6 or /dev/ttyUSB0>
```
