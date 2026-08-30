# EH Home — Real Value Application Plan

## 1. Value Collection Table

| Key | DEV Requirement | PROD Requirement | Loading Location |
| :--- | :--- | :--- | :--- |
| `BACKEND_BASE_URL` | Explicit Dev Host/LAN | Fully Qualified Domain (HTTPS) | Backend / Flutter AppConfig |
| `PORT` | 3000 | 3000 / 8080 (Reverse Proxy) | `backend/.env` |
| `DATABASE_URL` | PostgreSQL / SQLite test | Managed PostgreSQL | `backend/.env` |
| `REDIS_URL` | Redis 7.x | Cluster Redis with TLS | `backend/.env` |
| `MQTT_BROKER_URL` | EMQX 5.8 | Production EMQX Cluster | `backend/.env` |
| `MQTT_TLS_PORT` | 8883 | 8883 (mTLS Enforced) | `backend/.env` |
| `JWT_PRIVATE_KEY` | Development RSA Key | Cloud HSM / Vault / Mounted Secret | File Path |
| `MQTT_CA_FILE` | Dev Root CA Cert | Production Root CA Cert | File Path |

## 2. Reconciled Boundaries
- Flutter client reads backend base URL dynamically from runtime configuration or build flavor.
- ESP32 hardware connects to MQTT broker via mTLS on port 8883 using provisioned device certificates.
