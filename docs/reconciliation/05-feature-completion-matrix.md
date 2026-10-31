# Stage E — Feature Completion Matrix & Prioritization Register

**Generated Date:** October 31, 2026  
**Auditor:** Antigravity AI Engine  
**Project:** EH Home Platform  
**Comparison:** Canonical GitHub (`9d69a9d`) vs Local Working Workspace  

---

## 1. Feature Completion Matrix (All 15 Domains)

| Domain | GitHub Status (`9d69a9d`) | Local Status | Gap | Risk | Recommended Action | Priority |
| :--- | :--- | :--- | :--- | :---: | :--- | :---: |
| **Flutter Mobile App** | Phase 48 UI, cloud-only routing, 425 passing tests. | Dynamic catalog, auto LAN switchover, edge routine sync, cloud sync center, search, 470/480 passing tests. | 10 test assertion mismatches due to UI hardening; Android usesCleartextTraffic needs subnet scoping. | Low | Scoping Android network security config; align 10 test assertions; preserve all local UI. | **P1** |
| **Backend API** | Fastify backend, REST routes, SSE push, in-memory DB. | Fastify backend with Redis state cache, telemetry batch worker, apps/api TypeScript package. | apps/api and backend coexistence; in-memory DB unique constraint on duplicate test insert. | Low | Make test seeding in in-memory DB idempotent; integrate Redis caching with fallback. | **P1** |
| **PostgreSQL Database** | Migrations 001–029 verified (Phase 48). | Migrations 001–035 verified (121 tables) + local migrations 030/031 in `backend/migrations/`. | Numbering overlap between `backend/migrations/030` and `packages/db-schema/030`. | Med | Renumber local backend migrations 030/031 to 036/037 to maintain strict monotonicity. | **P0** |
| **Authentication & RBAC** | Phase 48 home ownership & membership RBAC (Owner/Admin/Member). | Preserved + refined in UI chips and invitation dialogues. | Zero functional gap; tests need assertion update for "Owner only" chips. | Low | Update chip assertions in test suites. | **P2** |
| **Device Control** | Cloud MQTT command dispatching via backend. | Dual-path: Direct LAN HTTP (`<15ms`) on local Wi-Fi, automatic Cloud MQTT fallback off LAN. | Production cloud URL fallback needed in `app_config.dart`. | Low | Keep default cloud URL fallback with settings override; preserve LAN HTTP engine. | **P1** |
| **MQTT / mTLS** | EMQX 5.8 mTLS config with `{deny, all}` fail-closed ACLs. | Identical broker config + HiveMQ Cloud TLS connection specs in architecture docs. | Live broker tests require Docker container running during test execution. | Low | Retain local broker configs; document cloud broker credentials setup for pilot. | **P2** |
| **Firmware (ESP32)** | Socket 3X prototype definition, basic relay & BLE. | FreeRTOS Edge Routine Engine (16 routines), local HTTP/UDP server, time sync manager, board pinouts (1X-4X). | Firmware requires compilation and flash on physical ESP32 boards for hardware pilot. | Med | Preserve all firmware C modules; build production binaries using ESP-IDF 5.4.1. | **P1** |
| **Hardware** | Smart Socket 3X schematics and prototype pinout. | Modular pinout headers (`board_config.h`, `board_pinout.h`) supporting 1X, 2X, 3X, 4X switch variants. | Physical PCB fabrication pending commercial scale (not blocking pilot on dev boards). | Low | Use dev-board prototypes for pilot; keep modular pinout architecture. | **P3** |
| **Energy & Telemetry** | Theoretical telemetry models and database tables. | BL0942 UART driver in firmware; telemetry batch ingestion worker in backend. | Factory calibration offsets (`v_cal`, `i_cal`, `p_cal`) needed in NVS for precision calibration. | Low | Add NVS calibration offsets in `factory_identity_v2.c` during pilot bench testing. | **P2** |
| **Automation & Routines** | Cloud-scheduled automations evaluated by backend worker. | Autonomous Edge Routines on-chip (FreeRTOS) + cloud cross-device evaluation + active routine collision guard. | Synchronizing routine deletion across edge and cloud. | Low | Preserve edge routine engine & `active_routine_guard.dart`. | **P1** |
| **Notifications** | SSE stream delivery and notification tables. | Mobile local notification repository; background FCM push notification integration documented. | `firebase_core` & `firebase_messaging` dependencies pending in mobile `pubspec.yaml`. | Med | Wire FCM dependencies and background token dispatch for terminated app state alerts. | **P1** |
| **Manufacturing Bench** | Python `factory_provisioner.py` and `flash_device.py`. | Tauri v2 desktop application (`apps/desktop`) with native Rust flashing commands + Windows PDF printer. | Requires building firmware manifest before desktop silicon polish test runs. | Low | Build firmware manifest via `build_firmware.ps1`; preserve Tauri v2 desktop app. | **P2** |
| **OTA Firmware Rollout** | Dual-slot OTA partition table and rollback validation. | Firmware `ota_manager.c` + backend local OTA binary serving + mobile `cloud_update_repository.dart`. | Ephemeral port string mismatch in `test_local_ota_serving.js`; public GitHub releases fallback. | Low | Fix ephemeral port regex in test; integrate GitHub releases fallback in mobile app. | **P2** |
| **Infrastructure** | Docker Compose with EMQX, Postgres, Backend. | Docker files preserved + zero-cost cloud deployment architecture (Render + Supabase + HiveMQ Cloud). | Backend currently runs on local localhost; free cloud deployment pending. | Med | Deploy backend on Render + Supabase free tier; set UptimeRobot keep-alive. | **P1** |
| **CI / CD Workflows** | GitHub Actions CI with full repo validation suite. | Monorepo CI extended with firmware, desktop, and storage test suites. | CI needs to pass 100% green before opening PR for next milestone. | Low | Resolve test assertions in Flutter and backend test fixtures before pushing. | **P1** |

---

## 2. Prioritized Action Matrix

### P0 Priority: Critical Integrity & Data Safety (Must Resolve First)
1. **Migration Monotonicity Guard**: Renumber `backend/migrations/030_device_authorization_channel_configs.sql` and `backend/migrations/031_automation_edge_execution_ownership.sql` to `036` and `037` respectively to prevent collision with `packages/db-schema/migrations/030-035`.
2. **Preserve Complete Backup**: Completed. Verified at `C:\Users\pavan\Downloads\Flutter\SMART_HOME_V1_BACKUP_20261031_PRE_RECONCILIATION`.
3. **Prevent Hard Resets**: Do not run `git reset --hard` or overwrite local working changes with remote files.

### P1 Priority: Core Product Integration & Green Validation (Milestone Blockers)
1. **Flutter Test Suite Alignment**: Align finders and text expectations in the 10 failing Flutter tests (`no_production_auth_bypass_test.dart`, `phase48_account_profile_timezone_test.dart`, `phase47_stage4_real_product_integration_test.dart`, `phase36_flutter_runtime_auth_navigation_test.dart`, `ble_preflight_service_test.dart`) to achieve **480/480 Tests Passed (100% Green)**.
2. **Backend In-Memory DB Test Fix**: Make test fixture insertion in `backend/src/shared/in-memory-db-adapter.js` idempotent so that `eh-smart-switch-3x` does not trigger unique constraint errors during test setup (instantly fixes 5 legacy test suites).
3. **Android Network Security Configuration**: Add RFC 1918 private subnet scoping in `network_security_config.xml` to allow cleartext LAN HTTP to `192.168.x.x` while enforcing HTTPS globally.
4. **Local OTA Test Assertion Fix**: Resolve ephemeral port matching in `backend/tests/test_local_ota_serving.js`.
5. **Dynamic Cloud URL Fallback**: Update mobile `app_config.dart` with cloud production URL fallback instead of hardcoded dev IP.

### P2 Priority: Tooling, Packaging & Factory Readiness
1. **Desktop Flasher Integration**: Run `powershell -File scripts/build_firmware.ps1` to produce canonical `firmware-build-manifest.json`, passing all 22 checks in `apps/desktop/tests/desktop-silicon-repo-polish.test.js`.
2. **A4 Adhesive QR Sticker Generator**: Complete `tools/manufacturing/generate_a4_sticker_sheet.py` using Python ReportLab to generate printable PDF QR sheets for pilot enclosures.
3. **Free Cloud Tier Deployment**: Deploy backend on Render + Supabase PostgreSQL; configure UptimeRobot 5-minute health check.

### P3 Priority: Future Expansion & Commercial Scaling
1. **Optional Hub Specification**: Implement Raspberry Pi / Linux edge hub for local multi-device cross-automations per `EH_OPTIONAL_HUB_ECOSYSTEM_MASTER_SPECIFICATION.md`.
2. **Hardware PCB Design**: Transition from breadboard/perfboard dev modules to custom PCB layouts per `docs/hardware/production-pcb-design.md`.

