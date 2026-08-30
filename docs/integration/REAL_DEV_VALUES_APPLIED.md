# EH Home — Real Development Values Applied

## Status Summary

All real development configuration values are structured to be read from explicit environment variables and runtime secrets:

- **Backend Host**: Configurable via `PORT` and `HOST`.
- **Database**: Configurable via `DATABASE_URL`.
- **Redis Cache/PubSub**: Configurable via `REDIS_URL`.
- **MQTT Transport**: Configurable via `MQTT_BROKER_URL` and `MQTT_TLS_PORT`.
- **Security & Authorization**: Asymmetric RS256 token verification with separate key paths.
- **ESP32 Provisioning**: AES-GCM EH-PROV/1 transcript handshake with secure zero-leakage state machine.
