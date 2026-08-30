# EH Home — Real Values Location Map & Architecture

## 1. Environment Classification

| Value Category | Storage Location | Loading Mechanism | Environment Scope | Secret |
| :--- | :--- | :--- | :--- | :--- |
| **Backend Base URL** | `.env` / `AppConfig` | Environment Variable / BuildConfig | DEV / STAGING / PROD | No |
| **Database URL** | `.env` (`DATABASE_URL`) | Node `process.env` | Backend Runtime | Yes |
| **Redis URL** | `.env` (`REDIS_URL`) | Node `process.env` | Backend Runtime | Yes |
| **MQTT Broker Host/Port**| `.env` (`MQTT_BROKER_URL`) | Node `process.env` / Config | DEV / STAGING / PROD | No |
| **MQTT TLS/mTLS Port** | `.env` (`MQTT_TLS_PORT`) | Node `process.env` | 8883 (mTLS) | No |
| **JWT Keypair (RS256)**| Disk Files (`/etc/eh/jwt/`) | File Path via `process.env` | Backend Runtime | Yes |
| **mTLS Root CA** | Disk Files (`/etc/eh/certs/`) | File Path via `process.env` | Backend / ESP32 | Public Cert |
| **Device Factory Identity** | ESP32 NVS (`fact_v2`) | Non-Volatile Flash partition | Hardware Factory | Secret (HMAC/Cert) |
| **BLE Protocol Constants** | `packages/contracts` | Compile-time constants | Multi-platform | No |

## 2. Security Separation Principles
1. **Source Code**: Contains zero secrets, passwords, or private keys.
2. **Configuration**: Supplied exclusively through environment variables or secure credential files.
3. **Hardware Factory Identity**: Preserved in write-protected NVS `fact_v2` and NEVER wiped during normal operation or remote unclaim.
