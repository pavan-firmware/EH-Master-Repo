# EH Home Current State

**Snapshot Date:** September 25, 2026  
**Repository:** `EH-Master-Repo` (`SMART_HOME_V1`)  
**Status:** Pre-New Platform Architecture Checkpoint  

---

## 1. Current Branch & Git Metadata

- **Active Branch:** `feature/phase48-home-ownership-membership-rbac`
- **Target Base:** `origin/main`
- **Current Head Commits Ahead of Origin Main:**
  - `9ea2ba2` (`fix(database): initialize postgres connection in migration cli`)
  - `2039325` (`feat(home): implement production home ownership and membership lifecycle`)
- **Working Tree State:** Staged & preserved complete current implementation across Backend, ESP32 Firmware, Flutter Application, Hardware Design, and Validation Tooling.

---

## 2. Current Phase Overview

- **Primary Phase:** **Phase 48 — Home Ownership, Membership, RBAC & Auth Identity Hardening**
- **Prior Foundation:** Phases 1 through 47 covering foundational contracts, MQTT broker integration (EMQX 5.8.0), BLE commissioning, signed OTA, energy intelligence, automations, multi-protocol connectivity, disaster recovery, PostgreSQL persistence, and ESP32 physical prototype validation.
- **Goal of Current State:** Provide a fully audited, verified, and stable checkpoint of all existing engineering work prior to initiating the EH Home Master Product-Platform & Lifecycle Architecture.

---

## 3. Backend Features

The backend is built on Node.js with dual-mode storage adapters (In-Memory and PostgreSQL with dynamic connection management), REST API routers, SSE realtime event bus, and background worker runners.

### Core Modules & Capabilities:
1. **Authentication & Identity (`backend/src/services/auth.service.js`, `backend/src/api/auth.router.js`):**
   - JWT-based authentication with access and refresh token lifecycle.
   - Dual-mode password hashing (scrypt / SHA-256 fallback).
   - Profile completion and identity metadata management (`user_profiles` table).
   - IANA Timezone validation (`Intl.DateTimeFormat` validation, strict fallback to `UTC`).
   - Legacy profile auto-healing and missing profile migration handlers.

2. **Home Ownership & RBAC (`backend/src/services/home.service.js`, `backend/src/repositories/index.js`):**
   - Canonical home authorization engine (`checkHomeAccess`, `requireRole`, `requireCapability`).
   - Multi-tenant role hierarchy: `OWNER` (full control, deletion, billing), `ADMIN` (device/room/automation management, member invitations), `MEMBER` (standard control and telemetry view), `GUEST` (read-only/temporary control).
   - Zero-state home handling: Clean zero-home states for new accounts (no stealth default home generation).
   - Multi-home membership switching and isolation.
   - Household invitations lifecycle (`PENDING`, `ACCEPTED`, `REJECTED`, `EXPIRED`, `REVOKED`).

3. **Room & Device Management (`backend/src/services/room.service.js`, `backend/src/services/device.service.js`, `backend/src/services/device-command.service.js`):**
   - Room layout, zone grouping, and custom icon assignment.
   - Device claim/unclaim with hardware identity preservation.
   - Channel-level relay labeling and status mapping.
   - Local LAN direct control endpoints.

4. **Realtime Event Stream & Telemetry (`backend/src/services/realtime-event-bus.js`, `backend/src/api/realtime-stream.router.js`, `backend/src/services/device-event-telemetry-ingestion.service.js`):**
   - Server-Sent Events (SSE) `/api/v1/realtime/stream` with home-scoped subscription isolation.
   - Monotonically increasing `_seq` numbers per home.
   - Realtime telemetry ingestion and energy load metrics processing.

5. **Persistence & Database Adapters (`backend/src/shared/`):**
   - `PostgresDatabaseAdapter` with connection pool, query parameterization, and transaction support.
   - `InMemoryDatabaseAdapter` supporting full unit-test execution without external database dependencies.
   - Migration CLI and verification suite (`backend/migrations/`).

---

## 4. Firmware Features (ESP32)

Targeting ESP32-C3 / ESP32-C6 / ESP32-WROOM platforms using ESP-IDF v5.4.1.

### Key Components (`firmware/platforms/esp32/smart-switch-app/`):
1. **Application Lifecycle & Main Loop (`main/main.c`, `main/app_lifecycle.c`):**
   - State machine: `INIT` -> `BLE_PROVISIONING` -> `WIFI_CONNECTING` -> `MQTT_CONNECTING` -> `ONLINE` / `DEGRADED` / `FACTORY_RESET`.
   - Non-blocking event queues and watchdog monitoring.

2. **Relay & Hardware Management (`main/relay_manager.c`, `main/switch_manager.c`):**
   - 3-channel relay control with hardware interlocks and power-on safety state (relays boot `OFF`).
   - Physical switch debouncing and dual-mode toggle/momentary edge detection.
   - Non-volatile storage (NVS) state persistence.

3. **Status Indication & Factory Reset (`main/status_led.c`, `main/reset_button.c`):**
   - Pattern-driven status LED (provisioning blink, Wi-Fi search blink, MQTT connected solid, error cadence).
   - Reset button hold-time discrimination: ignores short presses (<3s), requires continuous 10s hold for factory reset.
   - Factory reset clears Wi-Fi and MQTT credentials while preserving factory identity and calibration in protected NVS.

4. **BLE Commissioning & Local Server (`ble_commissioning.c`, `main/local_server.c`):**
   - GATT service for Wi-Fi provisioning, security handshakes, and diagnostic telemetry extraction.
   - Local HTTP/REST micro-server for zero-cloud LAN operations.

5. **Toolchain Pinning (`scripts/check-esp-idf-toolchain.js`, `scripts/activate_idf5.4.ps1`):**
   - Locked to ESP-IDF v5.4.1 to prevent toolchain drift.

---

## 5. Flutter Features (`smart_home_application_v1`)

Flutter cross-platform application (Android, iOS, Web, Desktop) using Flutter 3.x / Dart 3.x.

### Architecture & Capabilities:
1. **Authentication & Session Lifecycle:**
   - Real JWT auth flow, token refresh callbacks, auto-logout on 401.
   - Dedicated `ProfileCompletionScreen` for legacy or unconfigured user names.
   - Server base URL override configuration modal for local development.

2. **Home Shell & Dashboard (`lib/app/home_shell.dart`, `lib/features/dashboard/`):**
   - Dynamic bottom navigation with active home switcher.
   - Hero status cards, quick controls, active alerts sheet (`all_alerts_sheet.dart`).
   - Space management bottom sheets (`space_management_sheet.dart`, `control_group_editor_sheet.dart`, `other_spaces_devices_sheet.dart`).

3. **Rooms & Spaces (`lib/features/rooms/`):**
   - Hierarchical room view with per-room device controls.
   - Custom room creation, icon selection, and contextual device grouping.

4. **Device Provisioning & BLE Preflight (`lib/core/services/ble_preflight_service.dart`, `lib/features/connection/`):**
   - Platform-aware preflight checks for Android 12+ (Bluetooth permissions without requiring Location), Android <=30 (Location permissions handling), and iOS.
   - Step-by-step BLE discovery, Wi-Fi credential provisioning, and claiming progress UI.

5. **Settings & Home Details (`lib/features/settings/`):**
   - Home profile, household member management, invitation issuance/acceptance.
   - Timezone picker with comprehensive IANA timezone dictionary (`iana_timezones.dart`).
   - Help and customer support ticketing pages (`support_request_page.dart`).

---

## 6. Hardware / Production Assets

1. **KiCad Project `EH_SmartSocket_3X` (`hardware/kicad/EH_SmartSocket_3X/`):**
   - ESP32-C3-WROOM-02-N4 schematics (`EH_SmartSocket_3X.kicad_sch`), PCB layouts (`EH_SmartSocket_3X.kicad_pcb`), BL0942 power metering subsystem (`bl0942_module.kicad_sch`), relay channel modules (`relay_ch.kicad_sch`).
   - Custom footprints and 3D STEP models.

2. **KiCad Project `smart_switch_3x` (`hardware/kicad/smart_switch_3x/`):**
   - ESP32-C6-WROOM-1 smart switch design with HLK-PM01 AC-DC module, HF32F-G relays, TR5 fuse, 14D varistor, and NTC inrush protection.
   - Schematic PDF (`smart_switch_3x_schematic.pdf`) and 3D board renders (`render_top.png`, `render_iso.png`, `render_3d.png`).
   - Python automated PCB and schematic generation scripts (`build_perfect_project.py`, `generate_complete_clean_pcb.py`, etc.).

3. **Documentation:**
   - Production PCB Design specification (`docs/hardware/production-pcb-design.md`).
   - UI screen reference captures and design plan (`reference_screen_images/`).

---

## 7. Scripts & Development Tooling

- `scripts/validate-repo.js`: Monorepo test runner executing 64 automated test suites across contracts, simulator, migrations, backend, firmware, manufacturing PKI, and Flutter.
- `scripts/check-esp-idf-toolchain.js`: Enforces ESP-IDF 5.4.1 environment and VS Code configuration invariants.
- `scripts/activate_idf5.4.ps1`: Environment bootstrap script for ESP-IDF 5.4.1.
- `scripts/build_firmware.ps1`: Firmware build orchestration script.
- `scripts/setup-emqx-mtls.js`: mTLS certificate authority and EMQX broker certificate setup.
- `scripts/reset-dev-data.js`: Development database seeding and reset utility.

---

## 8. Known Limitations & Test Observability

### Current Validation Metrics:
- **Repository Validation (`scripts/validate-repo.js`):** 64 / 64 test suites passing (100% PASS).
- **Flutter Analyzer:** 0 issues found (clean pass).
- **Flutter Test Suite (`smart_home_application_v1`):** 425 / 425 tests passing across all 61 test files (100% PASS).
- **Backend Test Suite:** 100% pass across all phases (including Phase 7B Realtime Worker / `DeviceStaleDetector` 20/20, Phase 24 Intelligence 30/30, and Phase 48 Auth & RBAC suites).
- **Firmware Hardware Tests:** 100% pass across ESP32 pin map invariants, factory reset, BL0942 telemetry, and toolchain guards.

### Test Failure Resolution Summary (Pre-PR Triage & Fix):
1. **DeviceStaleDetector (Backend Priority 1):** Resolved stale transition logic to assign `connection_state: 'STALE'`, extract `homeId`, adapt table names for mock vs DB adapters, and map state record IDs.
2. **Phase 24 Intelligence Evaluate (Backend):** Resolved `realtimeEventBus.publish` property mismatch (`payload` vs `data`) in both `intelligence.service.js` and `realtime-event-bus.js`.
3. **Flutter Analyzer:** Removed unused `_splashDone` field in `app.dart` and migrated `HomeController.autoSync` to initializing formal.
4. **Flutter UI Layout Overflow:** Fixed `home_page.dart` space-selector header Row by wrapping in `Flexible` and ellipsizing on compact (<380dp) viewports.
5. **Flutter Controller Concurrency:** Added `autoSync: false` by default in `HomeController` to eliminate timer leaks across test suites while keeping background sync enabled in production.
6. **Flutter Actuator Command Isolation:** Guarded cloud-only actuators in `setLivingRoomLight` while preserving local multi-channel actuators in `setDeviceChannelPower`.
7. **Flutter Settings & Rooms Synchronization:** Dynamic fallback for room/device counts in `settings_page_rebuild.dart` and room freshness rendering in `room_context_page.dart`.
8. **Stale Widget Expectations:** Updated `widget_test.dart` to verify Notifications navigation on bell tap and Activity on bottom navigation bar tap.

---

## 9. Important Architectural Notes

- **Data Safety:** Working tree preserves existing schema migrations (001 through 029) and device identities.
- **Hardware Protection:** Factory NVS partition offsets must remain untouched to prevent bricking physical prototype boards during OTA migrations.
- **Monorepo Invariants:** Shared protocol contracts in `packages/contracts/` remain the single source of truth for message schemas across backend, firmware, and mobile app.
