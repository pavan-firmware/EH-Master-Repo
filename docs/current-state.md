# EH Home Current State

**Snapshot Date:** November 2026  
**Repository:** `EH-Master-Repo` (`SMART_HOME_V1`)  
**Status:** Phase 50 Complete & Validated (80/80 Monorepo Test Suites Passing)  

---

## 1. Current Branch & Git Metadata

- **Active Branch:** `feature/phase50-backend-resilience-and-edge-fixes`
- **Target Base:** `origin/main`
- **Working Tree State:** Completely reconciled across Backend (Fastify/Node.js), ESP32 FreeRTOS Firmware, Flutter Application (`smart_home_application_v1`), Desktop Manufacturing Suite (Tauri v2 + Rust), and Hardware Automation.
- **Pre-Push Validation:** 80/80 test suites passing via `node scripts/validate-repo.js`.
- **Flutter Analyzer:** 0 issues found via `flutter analyze`.

---

## 2. Platform Progression (Phases 1 — 50)

- **Phases 1–36:** Canonical contracts (19 schemas), PostgreSQL persistence, product catalog engine, BLE commissioning (`EH-PROV/1`), MQTT mTLS (`EMQX 5.8.0`), RS256 JWT auth, realtime SSE streams, firmware signed OTA, dynamic tariffs, and Flutter runtime integration.
- **Phases 37–46:** 37 symmetric database migrations, remote backup storage, product catalog expansion, manufacturing flasher, fleet safe OTA rollout, and final production acceptance.
- **Phases 47–48:** Hardware ESP32 target verification, multi-switch pinouts, home ownership & membership RBAC (`OWNER`, `ADMIN`, `MEMBER`, `GUEST`), and profile timezone management.
- **Phase 49:** FreeRTOS edge routine engine, zero-touch UDP LAN switchover, migrations 036–037, desktop manufacturing suite (Tauri bench provisioner, thermal label printer, dual-scan packing station), and Windows PDF printing subsystem.
- **Phase 50:** Cross-layer master flows, backend resilience, truthful standby telemetry, dark-theme contrast tokens, routine notification filtering, offline stale-while-revalidate UX, and home owner administrative access alignment.

---

## 3. Subsystem Status Summary

### 3.1 Backend Services & Database
- **Migrations:** 37 bidirectional, 100% symmetric UP/DOWN PostgreSQL migrations managing 121 relational tables.
- **API Routers:** Fastify & Node.js HTTP/SSE routers covering Auth, Account, Homes, Devices, Commands, Energy, Context, Intelligence, Operations, Trust, Recovery, Fleet, and Observability.
- **RBAC Engine:** Canonical home authorization engine (`checkHomeAccess`, `requireRole`, `requireCapability`) enforcing tenant isolation. Home owners (`OWNER`) possess full administrative privileges over their households.
- **Realtime Event Stream:** SSE endpoint (`/api/v1/realtime/stream`) with per-home monotonic sequence numbers (`_seq`), heartbeat keep-alive, and stale connection detection.

### 3.2 Flutter Mobile Application (`smart_home_application_v1`)
- **Stale-While-Revalidate UX:** Settings, home profiles, and routines render instantly from local cache during cold starts, app resumes, and screenshot transitions without blanking or endless spinning.
- **Role-Aware Views:** Home owners (`OWNER`) and Home Admins access full administrative tools (Disaster Recovery, Device Trust, Fleet Operations). Invited members (`MEMBER`/`GUEST`) are cleanly presented with `AdminAccessRequiredView`.
- **Theme Engine:** Full high-contrast semantic palette (`context.ehColors`) in both light and dark themes with zero illegible dark-on-dark text regressions.
- **Notification De-Duplication:** Socket and routine toggles are filtered from the alert center via `event_classification.dart` while preserving hardware safety alerts and the Activity audit trail.
- **Zero-Touch LAN Control:** High-speed UDP broadcast listener (`port 4210`) and local HTTP actuator commands achieve `<15ms` execution without internet access.

### 3.3 ESP32 Firmware (`firmware/platforms/esp32/smart-switch-app`)
- **Edge Routine Engine:** Hardware FreeRTOS timer-driven task executing weekly multi-action schedules autonomously from on-chip NVS storage.
- **Transports:** Dual-mode communication supporting direct LAN HTTP (:80) / UDP (:4210) and secure cloud MQTT (:8883) with mTLS client certificate verification.
- **Energy Telemetry:** Fixed-point BL0942 integration reporting voltage, current, active power, total energy, and power factor.

### 3.4 Desktop Suite (`apps/desktop/`)
- **Bench Provisioner:** Tauri v2 + Rust desktop application injecting unique device credentials and cryptographic certificates.
- **Label Printer:** TSPL thermal label generation for product barcodes and packaging serials.
- **Dual-Scan Packing Station:** Hardware verification and pairing validation prior to commercial boxing.

---

## 4. Verification & Quality Gates

| Check | Tool / Command | Result |
|:---|:---|:---:|
| **Monorepo Test Suites** | `node scripts/validate-repo.js` | **80/80 PASSED (100%)** |
| **Flutter Static Analysis** | `flutter analyze` | **0 issues found** |
| **Flutter Unit & Widget Tests** | `flutter test --no-pub` | **70+ test suites PASSED** |
| **EMQX Integration & mTLS** | `backend/tests/phase6-emqx-integration.test.js` | **22/22 PASSED** |
| **PostgreSQL Migration Symmetry** | `node backend/tests/phase37-real-pg-migration.test.js` | **100% UP/DOWN verified** |
| **Git Tracking Cleanliness** | `git status` | **`prompt_images/` ignored** |
