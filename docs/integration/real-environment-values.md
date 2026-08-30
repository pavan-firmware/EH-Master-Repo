# EH Home — Real-Environment Integration & Configuration Map

This document establishes the authoritative configuration map across the EH Home monorepo (Flutter client, Node.js backend, PostgreSQL database, Redis, EMQX MQTT broker, ESP32 firmware, and manufacturing PKI).

---

## 1. Real-Environment Configuration Table

| Category | Variable / Value | Real Source | User Must Provide? | Secret? | Used By | Exact File / Location |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Backend** | `BACKEND_BASE_URL` | Local LAN IPv4 or Domain | **YES** | No | Flutter (`AppConfig`), Web | `smart_home_application_v1/lib/core/config/app_config.dart`<br>`.env.example` |
| **Backend** | `PORT` | Environment / Host | Optional (Default: `3000`) | No | Backend Server HTTP listener | `backend/src/shared/config.js` |
| **Backend** | `HOST` | Environment / Host | Optional (Default: `0.0.0.0`) | No | Backend Server HTTP listener | `backend/src/shared/config.js` |
| **Backend** | `NODE_ENV` / `APP_ENV` | Build / Deployment | Optional (Default: `development`) | No | Backend runtime, Flutter | `backend/src/shared/config.js`<br>`smart_home_application_v1/lib/core/config/app_config.dart` |
| **Database** | `DATABASE_URL` | PostgreSQL Server URI | **YES** (for staging/prod) | **YES** | Backend Repositories & Migrations | `backend/src/shared/config.js`<br>`.env.example` |
| **Cache & Queue** | `REDIS_URL` | Redis 7+ Server URI | Optional (Default: `redis://localhost:6379`) | **YES** (if authenticated) | Backend Realtime & Cache | `backend/src/shared/config.js`<br>`.env.example` |
| **MQTT** | `MQTT_BROKER_URL` | EMQX 5.8 TCP URI | Optional (Default: `mqtt://127.0.0.1:1883`) | No | Backend `MqttDeviceTransport` | `backend/src/services/mqtt-device-transport.js` |
| **MQTT** | `MQTT_TLS_BROKER_URL` | EMQX 5.8 mTLS URI | **YES** (for prod: `mqtts://...:8883`) | No | Backend & ESP32 Transport | `backend/src/shared/config.js` |
| **MQTT Auth** | `MQTT_BACKEND_USERNAME` | EMQX User ACL | Optional (Default: `eh_backend_service`) | No | Backend EMQX Client | `backend/src/shared/config.js` |
| **MQTT Auth** | `MQTT_BACKEND_PASSWORD` | EMQX Password | **YES** (in staging/prod) | **YES** | Backend EMQX Client | `backend/src/shared/config.js` |
| **MQTT TLS** | `MQTT_CA_FILE` | Root CA Certificate (.pem) | **YES** (for mTLS) | No (Public cert) | Backend EMQX Client | `backend/src/shared/config.js` |
| **MQTT TLS** | `MQTT_CLIENT_CERT` | Backend Client Cert (.pem) | **YES** (for mTLS) | No (Public cert) | Backend EMQX Client | `backend/src/shared/config.js` |
| **MQTT TLS** | `MQTT_CLIENT_KEY` | Backend Client Key (.key) | **YES** (for mTLS) | **YES** | Backend EMQX Client | `backend/src/shared/config.js` |
| **Authentication** | `JWT_SECRET` | Secret Manager / Env | **YES** (Min 32 chars) | **YES** | Backend `AuthService` | `backend/src/shared/config.js` |
| **Authentication** | `SESSION_SECRET` | Secret Manager / Env | **YES** (Min 32 chars) | **YES** | Backend Session Manager | `backend/src/shared/config.js` |
| **Dev Account** | `DEV_USER_EMAIL` | User Registration / Seed | **YES** | No | Flutter Login & Auth | `smart_home_application_v1/lib/features/auth/` |
| **Dev Account** | `DEV_USER_PASSWORD` | User Registration / Seed | **YES** | **YES** | Flutter Login & Auth | `smart_home_application_v1/lib/features/auth/` |
| **Physical Device** | `deviceId` | Factory NVS (`fact_v2`) / BLE | **Generated** by Factory PKI | No | ESP32, BLE Onboarding, Backend | Read via BLE Char `6105` at runtime |
| **Physical Device** | `serialNumber` | Factory NVS (`fact_v2`) / BLE | **Generated** by Factory PKI | No | ESP32, BLE Onboarding, Backend | Read via BLE Char `6105` at runtime |
| **Physical Device** | `commissioningSecret` | Factory Provisioning / QR | **Generated** by Manufacturing | **YES** (Session only) | ESP32, Flutter EH-PROV/1 | Transferred via EH1 QR Scanner |
| **Physical Device** | `productVariantId` | Product Catalog | Catalog Constant | No | Product Catalog, Flutter | `product-definitions/catalog.json` |
| **Home** | `homeId` | Backend Database | **Generated** by Backend API | No | Flutter `HomeController` | Fetched dynamically via `/api/v1/homes` |
| **Home** | `homeName` | User Input / Backend | **User Provided** at runtime | No | Flutter Home Shell | Entered by user during home creation |
| **Rooms** | `roomId` | Backend Database | **Generated** by Backend API | No | Flutter `RoomsPage` | Fetched dynamically via `/api/v1/homes/:id/rooms` |
| **Rooms** | `roomName` | User Input / Backend | **User Provided** at runtime | No | Flutter `RoomsPage` | Entered by user in Create Room dialog |
| **Wi-Fi** | `SSID` | Home Wi-Fi Network | **User Provided** at runtime | No | Flutter Onboarding, ESP32 | Entered by user in Provisioning screen |
| **Wi-Fi** | `Password` | Home Wi-Fi Password | **User Provided** at runtime | **YES** (Transient) | Flutter Onboarding, ESP32 | Encrypted via AES-256-GCM over BLE |

---

## 2. Value Classification Taxonomy

Every value in the EH Home ecosystem belongs strictly to one of the following classes:

1. **CODE CONSTANT**: Protocol identifiers, BLE UUIDs (`00006101-...`), GATT characteristics, standard MQTT topic formats.
2. **ENVIRONMENT CONFIG**: `BACKEND_BASE_URL`, `DATABASE_URL`, `REDIS_URL`, `MQTT_BROKER_URL`, `PORT`, `HOST`.
3. **SECRET**: `JWT_SECRET`, `SESSION_SECRET`, Database credentials, MQTT private keys, Wi-Fi passwords, Factory commissioning secrets.
4. **FACTORY/MANUFACTURING DATA**: Device UUID, Serial Number, Factory private key, X.509 device certificate, QR Payload.
5. **DEVICE RUNTIME DATA**: Telemetry (V, I, P, E), IP address, Relay states (CH1, CH2, CH3), Wi-Fi RSSI.
6. **DATABASE DATA**: User ID, Home ID, Room ID, Device Registration records, Event logs, Audit records.
7. **TEST FIXTURE**: Isolated deterministic mocks inside `test/` or `tests/` directories used exclusively during unit tests.
8. **PREVIEW/DEMO DATA**: Offline design mocks used only when rendering standalone widget tests.
9. **DOCUMENTATION SAMPLE**: Illustrative code blocks in markdown guides.
10. **ACCIDENTAL HARDCODE**: Any production fallback that bypassed environment configuration (all purged in Phase 9+).

---

## 3. Exact Modification Location Map

### 1. `BACKEND_BASE_URL`
- **Purpose**: Points the Flutter application to the reachable backend server instance.
- **Development Value**: `http://<YOUR_COMPUTER_LAN_IP>:3000` (e.g. `http://192.168.1.8:3000`).
- **Production Value**: `https://api.yourdomain.com`.
- **Location**: `smart_home_application_v1/lib/core/config/app_config.dart`.
- **How to supply**:
  ```bash
  flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.8:3000
  ```
- **Validation**: Open app and check that `/health` request succeeds without `Connection refused`.

### 2. `DATABASE_URL`
- **Purpose**: PostgreSQL connection string for backend services, migrations, and event storage.
- **Development Value**: `postgresql://eh_admin:eh_development_password_only@localhost:5432/eh_home_dev`.
- **Production Value**: Managed cloud database URI (e.g. AWS RDS / Google Cloud SQL).
- **Location**: `.env` (loaded by `backend/src/shared/config.js`).
- **Validation**: Run `node backend/migrations/verify-migrations.js`.

### 3. `MQTT_BROKER_URL` & `MQTT_TLS_BROKER_URL`
- **Purpose**: EMQX 5.8 broker endpoint for device command and telemetry routing.
- **Development Value**: `mqtt://127.0.0.1:1883` (TCP) / `mqtts://localhost:8883` (mTLS).
- **Production Value**: `mqtts://mqtt.yourdomain.com:8883`.
- **Location**: `.env` (loaded by `backend/src/shared/config.js` and `backend/src/services/mqtt-device-transport.js`).
- **Validation**: Run `node backend/tests/phase6-mqtt.test.js`.

### 4. `JWT_SECRET` & `SESSION_SECRET`
- **Purpose**: Signs and validates user access tokens and refresh tokens.
- **Requirement**: Minimum 32-character random string (e.g. `openssl rand -hex 32`).
- **Location**: `.env` (loaded by `backend/src/shared/config.js`).
- **Validation**: Run `node backend/tests/phase7a-auth.test.js`.

### 5. Physical Device Factory Data (`deviceId`, `serialNumber`, `commissioningSecret`)
- **Purpose**: Unique hardware cryptographic identity.
- **Location**: Flash partition `fact_v2` on ESP32 / QR Code on packaging.
- **How to supply**: Generated using `tools/manufacturing/provision_device.py`.
- **Validation**: ESP32 boots and logs `Factory Identity: DeviceID=... Serial=...`.
