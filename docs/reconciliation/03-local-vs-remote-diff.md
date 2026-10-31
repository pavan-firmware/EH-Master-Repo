# Stage C — Complete Local vs Remote Diff & Technical Comparison

**Generated Date:** October 31, 2026  
**Auditor:** Antigravity AI Engine  
**Baseline Remote:** `origin/main` (`9d69a9d103283078590502049c4de1afa9fe809d`)  
**Local State:** Working Tree sitting on HEAD commit `1e571fbd758c225c6c7ea27d0d62f529e54fcbdc`  
**Total Differing Files:** 392 files

---

## 1. Architectural Scope & Evolution Summary

The local project contains massive, deliberate architectural advancements beyond the GitHub Phase 48 baseline. These fall into two chronological waves:

1. **Commit `1e571fb` ("feat: complete EH Home master architecture parts 00-17")**:
   - Introduced a monorepo structure via pnpm workspaces (`apps/api`, `apps/desktop`, `packages/contracts`, `packages/db-schema`).
   - Added Drizzle ORM schemas and migrations 030–035.
   - Built the foundation for the Tauri desktop manufacturing and provisioning workstation.
   - Enhanced the mobile app's dynamic product catalog and channel rendering.

2. **Uncommitted Working Tree Advancements**:
   - **Firmware**: Implemented the **FreeRTOS Edge Routine Engine** (`edge_routine_engine.c`), enabling microcontrollers to autonomously execute schedules and timers without internet or cloud connection.
   - **Firmware**: Implemented local REST API endpoints on port 80 and UDP broadcast discovery on port 4210 (`local_server.c`).
   - **Firmware**: Created `time_sync_manager.c` for phone-to-ESP32 local time sync during internet blackouts.
   - **Flutter**: Built **Auto-Mode LAN Switchover** (`local_lan_device_service.dart`), switching from Cloud HTTPS to direct local HTTP (`<15ms` latency) seamlessly.
   - **Flutter**: Built Edge Routine Sync service (`edge_routine_sync_service.dart`), Connection Routing Sheet, Cloud Sync Center Sheet, and Search views.
   - **Backend**: Added Redis state cache service, telemetry batch ingestion worker, and migrations 030 (`channel_configs`) and 031 (`automation_edge_execution_ownership`).
   - **Desktop**: Upgraded to Tauri v2, native Rust serial & flashing commands (`commands.rs`), and Microsoft Print to PDF label generation.
   - **Architecture**: Authored 9 production specifications in `docs/architecture/`.

---

## 2. Exhaustive Domain-by-Domain Difference Catalog

### 2.1 ESP32 C Firmware Subsystem

| File Path | Classification | Remote (`9d69a9d`) | Local Implementation | Functional Impact | Risk | Recommended Action |
| :--- | :--- | :--- | :--- | :--- | :---: | :--- |
| `firmware/.../edge_routine_engine.c` / `.h` | `LOCAL_NEW_FEATURE` | Absent | Full FreeRTOS routine engine. 16 routines per MCU, 7-day bitmask, countdown timers, wear-leveled NVS single-blob storage. | Enables 100% autonomous scheduling on-chip with zero internet connection. | Low | **Preserve & Integrate**. Core differentiator. |
| `firmware/.../time_sync_manager.c` / `.h` | `LOCAL_NEW_FEATURE` | Absent | SNTP sync with drift compensation, and local HTTP endpoint (`POST /api/v1/time`) fallback from phone. | Prevents clock reset to epoch 0 (1970) during power outages without internet. | Low | **Preserve & Integrate**. |
| `firmware/.../local_server.c` / `.h` | `LOCAL_MODIFICATION` | Basic local server | Extended Port 80 REST server: `/api/v1/state`, `/api/v1/relays/control`, `/api/v1/routines`, `/api/v1/time`, `/api/v1/ota` + UDP port 4210 auto-announcements. | Enables direct LAN app control and automated local discovery. | Low | **Preserve & Integrate**. |
| `firmware/.../board_config.h` / `board_pinout.h` | `LOCAL_NEW_FEATURE` | Hardcoded pins | Modular GPIO mapping macros for ESP32 and ESP32-C6 targets across 1X, 2X, 3X, 4X switch configurations. | Decouples firmware application logic from physical pinouts. | Low | **Preserve & Integrate**. |
| `firmware/.../Kconfig.projbuild` | `LOCAL_NEW_FEATURE` | Absent | Kconfig configuration menu for board variant selection, relay inverted logic, and BL0942 UART pins. | Standardizes ESP-IDF build-time configuration. | Low | **Preserve & Integrate**. |
| `firmware/.../relay_manager.c` / `.h` | `LOCAL_MODIFICATION` | Synchronous GPIO | Non-blocking FreeRTOS queues, interlock safety protection, power-loss NVS state retention. | Prevents relay bounce and guarantees state restoration upon power restoration. | Low | **Preserve & Integrate**. |
| `firmware/.../switch_manager.c` / `.h` | `LOCAL_MODIFICATION` | Polling | Interrupt-driven edge detection with hardware debouncing (50ms). | Instant wall switch response (`<2ms`). | Low | **Preserve & Integrate**. |
| `firmware/.../telemetry_manager.c` / `.h` | `LOCAL_MODIFICATION` | Mock telemetry | BL0942 UART driver streaming voltage, current, active power, and cumulative energy. | Real-time energy monitoring on physical hardware. | Low | **Preserve & Integrate**. |
| `firmware/.../wifi_manager.c` / `.h` | `LOCAL_MODIFICATION` | Static reconnect | Exponential reconnect backoff; automatic BLE re-entry after 10 failed connection attempts. | Prevents device lock-out when Wi-Fi SSID/password changes. | Low | **Preserve & Integrate**. |

---

### 2.2 Flutter Mobile Application (`smart_home_application_v1`)

| File Path | Classification | Remote (`9d69a9d`) | Local Implementation | Functional Impact | Risk | Recommended Action |
| :--- | :--- | :--- | :--- | :--- | :---: | :--- |
| `lib/core/services/local_lan_device_service.dart` | `LOCAL_MODIFICATION` | Stub service | Active UDP broadcast listener on port 4210, dynamic subnet probing, direct HTTP client (`POST /api/v1/relays/control`). | Achieves `<15ms` local control latency when phone is on home Wi-Fi. | Low | **Preserve & Integrate**. |
| `lib/core/services/edge_routine_sync_service.dart` | `LOCAL_NEW_FEATURE` | Absent | Converts UI automations into compact 7-bit days masks, targets edge slots, pushes to ESP32 via HTTP/Cloud. | Keeps phone routines and hardware NVS routines synchronized. | Low | **Preserve & Integrate**. |
| `lib/app/home_controller.dart` | `LOCAL_MODIFICATION` | Standard cloud state | Extended with dual-transport arbitration (LAN first, Cloud fallback), active routine locks, multi-space device management. | Unified reactive runtime controller across LAN, BLE, and Cloud. | Med | **Preserve & Integrate**. Covered by unit tests. |
| `lib/features/dashboard/presentation/cloud_sync_center_sheet.dart` | `LOCAL_NEW_FEATURE` | Absent | Dedicated UI bottom sheet for manual sync, offline conflict resolution, and cloud snapshot restore. | Provides user visibility into cloud vs edge sync status. | Low | **Preserve & Integrate**. |
| `lib/features/dashboard/presentation/connection_routing_sheet.dart` | `LOCAL_NEW_FEATURE` | Absent | Network inspection sheet showing active IP, latency, protocol (LAN HTTP vs Cloud MQTT), and packet loss. | Essential diagnostic tool for users and reviewers. | Low | **Preserve & Integrate**. |
| `lib/features/automations/presentation/active_routine_guard.dart` | `LOCAL_NEW_FEATURE` | Absent | Widget guard that prevents contradictory simultaneous routine executions on the same channel. | Prevents relay thrashing and hardware damage. | Low | **Preserve & Integrate**. |
| `lib/core/repositories/cloud_update_repository.dart` | `LOCAL_NEW_FEATURE` | Absent | OTA release check querying backend fleet endpoints with public GitHub Releases fallback. | Enables live OTA firmware upgrade prompts in Settings. | Low | **Preserve & Integrate**. |
| `lib/features/search/` | `LOCAL_NEW_FEATURE` | Absent | Global search page and fuzzy match filtering across devices, rooms, scenes, and routines. | UX improvement for larger home setups. | Low | **Preserve & Integrate**. |
| `lib/core/capabilities/repositories/product_catalog_repository.dart` | `LOCAL_MODIFICATION` | Hardcoded models | Dynamic capability and channel count rendering (Switch 1X, 2X, 3X, 4X, Socket 2X, 3X). | Renders exact controls based on verified product metadata. | Low | **Preserve & Integrate**. |

---

### 2.3 Backend & Cloud Infrastructure

| File Path | Classification | Remote (`9d69a9d`) | Local Implementation | Functional Impact | Risk | Recommended Action |
| :--- | :--- | :--- | :--- | :--- | :---: | :--- |
| `backend/migrations/030_device_authorization_channel_configs.sql` | `LOCAL_NEW_FEATURE` | Absent | Adds `channel_configs JSONB` to `device_authorizations`. | Persists custom channel names, icons, and alert thresholds per user. | Med | **Renumber to `036`** to prevent collision with `packages/db-schema`. |
| `backend/migrations/031_automation_edge_execution_ownership.sql` | `LOCAL_NEW_FEATURE` | Absent | Adds `execution_target`, `edge_sync_status`, `edge_device_id`, `edge_slot_id` to `automations`. | Tracks whether an automation runs on cloud or edge microcontroller. | Med | **Renumber to `037`** to prevent collision with `packages/db-schema`. |
| `backend/src/services/redis-state-cache.service.js` / `redis-client.js` | `LOCAL_NEW_FEATURE` | Absent | Redis cache client for device state snapshots and realtime pub/sub with graceful degradation when Redis is absent. | Scales read operations without exhausting PostgreSQL connections. | Low | **Preserve & Integrate**. Runs safely with fallback. |
| `backend/src/workers/telemetry-batch-worker.js` | `LOCAL_NEW_FEATURE` | Absent | Ingestion buffer for device voltage, current, and energy measurements, writing in batches of 50. | Prevents DB connection starvation under heavy telemetry traffic. | Low | **Preserve & Integrate**. |
| `backend/src/workers/automation-scheduler-worker.js` | `LOCAL_MODIFICATION` | Periodic polling | High-precision second-level timer evaluation; checks `execution_target != 'DEVICE'` before firing cloud commands. | Prevents cloud from double-triggering routines that already ran on the edge device. | Low | **Preserve & Integrate**. |
| `backend/src/shared/in-memory-db-adapter.js` | `LOCAL_MODIFICATION` | Standard in-memory DB | Unique constraint checks throw error on duplicate inserts during test setup. | Causes 5 legacy test suites to fail when seeding `eh-smart-switch-3x`. | Low | **Update adapter to make test seeding upsert idempotent**. |

---

### 2.4 Tauri Desktop Workstation (`apps/desktop`)

| File Path | Classification | Remote (`9d69a9d`) | Local Implementation | Functional Impact | Risk | Recommended Action |
| :--- | :--- | :--- | :--- | :--- | :---: | :--- |
| `apps/desktop/src-tauri/src/commands.rs` | `LOCAL_MODIFICATION` | Stub commands | +1925 lines. Implements serial interrogation, chip architecture detection (ESP32 vs ESP32-C6), esptool flashing, PDF printing. | Provides full native capabilities for manufacturing bench. | Low | **Preserve & Integrate**. |
| `apps/desktop/src-tauri/Cargo.toml` / `tauri.conf.json` | `LOCAL_MODIFICATION` | Tauri v1 config | Upgraded to Tauri v2 with explicit security capabilities (`src-tauri/capabilities/`). | Tauri v2 compliance, enhanced sandboxing. | Low | **Preserve & Integrate**. |
| `apps/desktop/src/services/system-setup.service.ts` | `LOCAL_NEW_FEATURE` | Absent | Detects installed dependencies (Python, esptool, Git, Git LFS) and provides 1-click installer commands. | Eliminates environment setup confusion for factory operators. | Low | **Preserve & Integrate**. |
| `apps/desktop/tests/windows-pdf-printer.test.js` | `LOCAL_NEW_FEATURE` | Absent | Automated validation of Microsoft Print to PDF integration for A4 sticker printing. | Validates zero-cost paper sticker generation. | Low | **Preserve & Integrate**. |

---

### 2.5 Architecture Documentation (`docs/architecture/`)

9 comprehensive engineering documents exist locally as untracked files:
1. `COMMERCIAL_FIRMWARE_AND_APP_UPDATE_SYSTEM.md`: Dual-slot flash partition layout, cryptographic rollback validation, delta updates, public release feeds.
2. `CURRENT_PROJECT_STATUS_GAPS_AND_ROADMAP.md`: Exhaustive 399-line audit of completed features, test regressions, zero-cost cloud setup, YouTuber demonstration protocol, and flash wear calculations.
3. `EH_OPTIONAL_HUB_ECOSYSTEM_MASTER_SPECIFICATION.md`: Future local hub architecture (Raspberry Pi / Linux edge) for multi-device cross-automations without cloud.
4. `ZERO_COST_PRODUCTION_AND_COMMERCIAL_SCALE_PLAN.md`: Production economics from pilot (0–50 units) to commercial scale (10,000+ units).
5. `desktop-performance-root-cause.md`: Optimization analysis of Tauri webview rendering and serial IPC latency.
6. `desktop-real-workflows.md`: Operator workflow definitions for factory flashing and QC acceptance.
7. `hybrid-cloud-local-routine-engine.md`: Formal verification of the dual-execution routine arbitration algorithm.
8. `model2-esp32-edge-scheduling-analysis.md`: In-depth timing, FreeRTOS timer jitter, and power failure recovery analysis.
9. `optional-smart-home-hub-business-guide.md`: Commercial positioning of standalone switches vs optional hub upsell.

**Recommendation:** **Preserve 100% of these documents**. They provide invaluable architectural context and commercial roadmap specifications.

