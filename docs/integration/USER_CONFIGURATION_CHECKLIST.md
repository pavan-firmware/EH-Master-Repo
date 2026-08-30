# EH Home — User Configuration Checklist

Use this checklist to ensure all environment requirements are met before running tests, development builds, or production releases.

---

## 1. Before Running the Backend

- [ ] `.env` file copied from `.env.example` and customized with local values.
- [ ] `PORT` and `HOST` configured (default: `3000` / `0.0.0.0`).
- [ ] `BACKEND_BASE_URL` contains reachable LAN IP or public domain.
- [ ] PostgreSQL is reachable at `DATABASE_URL`.
- [ ] Database schema migrations executed (`node backend/migrations/verify-migrations.js`).
- [ ] Redis server is reachable at `REDIS_URL`.
- [ ] EMQX MQTT 5.8 broker is running on port `1883` (TCP) or `8883` (TLS).
- [ ] `JWT_SECRET` configured with high entropy (min 32 characters in production).

---

## 2. Secrets & Security Policy

- [ ] No real secrets, passwords, or private keys committed to Git.
- [ ] Production certificates stored in secure external storage / Secret Manager.
- [ ] MQTT client certificates generated with device-specific common names.
- [ ] `NODE_ENV=production` enforces TLS (`mqtts://`), valid PostgreSQL credentials, and strong JWT secrets.

---

## 3. Flutter Client (Mobile Application)

- [ ] Compile-time `--dart-define=BACKEND_BASE_URL=...` passed during `flutter run` / `flutter build`.
- [ ] Android device connected on the same 2.4 GHz Wi-Fi / LAN subnet as the backend host machine.
- [ ] Android Bluetooth & Nearby Devices permissions enabled when prompted.
- [ ] Location services enabled on mobile device (required by Android OS for BLE scanning).
- [ ] Camera permission granted for QR code scanning.

---

## 4. Physical ESP32 Hardware

- [ ] Target ESP32 board powered on and connected to USB (COM port detected).
- [ ] Firmware built and flashed using ESP-IDF v5.4.1.
- [ ] Factory NVS partition `fact_v2` contains valid UUID, Serial Number, and Commissioning Secret.
- [ ] ESP32 is actively advertising `EH-PROV/1` BLE service (LED indicator / console output).
- [ ] Target 2.4 GHz Wi-Fi SSID and password known and entered into onboarding screen.
- [ ] Device connects, obtains IP, and securely transitions to `ACTIVE` state.
