# Stage H — Next Development Roadmap & Engineering Milestones

**Generated Date:** October 31, 2026  
**Auditor:** Antigravity AI Engine  
**Project:** EH Home Platform  
**Baseline Anchor:** Phase 48 Checkpoint (`9d69a9d103283078590502049c4de1afa9fe809d`)

---

## 1. Ground Truth Assessment of Project Milestones

- **Canonical GitHub Baseline**: **Phase 48** (PR #58 — Home Ownership & Membership RBAC Checkpoint).
- **Phases 1 through 48**: **100% Completed, Verified & Merged**. Under no circumstances should Phases 1–48 be restarted or duplicated.
- **Local Development State**:
  - Locally, development continued through **commit `1e571fb`** (Monorepo enterprise structure, Fastify TypeScript API, Zod contracts, and Tauri desktop flasher).
  - The working directory further implemented **Phase 50 capabilities**: the FreeRTOS Autonomous Edge Routine Engine (`edge_routine_engine.c`), Auto-Mode LAN Switchover (`local_lan_device_service.dart`), local HTTP server on port 80, time sync fallback, and Redis state caching.

To maintain clean Git traceability and avoid unwieldy monolithic pull requests, future development is organized into two sequential, focused milestones:

---

## 2. Milestone: Phase 49 — Monorepo Enterprise Architecture & Manufacturing Workstation

**Goal**: Formally reconcile and merge the enterprise monorepo infrastructure, Zod contract verification, and the Tauri v2 manufacturing flasher into `origin/main`.

### Key Deliverables:
1. **Pnpm Workspaces Monorepo**: Formalize `apps/api`, `apps/desktop`, `packages/contracts`, and `packages/db-schema`.
2. **Database Migrations 030–035**: Hardware BOM specifications, firmware binary management, production inventory packing, telemetry MQTT OTA, and security RBAC audit.
3. **Tauri v2 Manufacturing Workstation**:
   - Native Rust esptool integration in `commands.rs`.
   - Automatic COM port probing and silicon interrogation (ESP32 vs ESP32-C6).
   - Windows Microsoft Print to PDF integration for zero-cost thermal and A4 sticker printing.
4. **Contract Validation**: Zod runtime schema validation across all cross-process boundaries.

### Acceptance Criteria:
- `pnpm install` and `pnpm test` execute cleanly across all packages.
- All 11 desktop test suites pass cleanly (`desktop.test.js`, `bench-provisioner.test.js`, `native-boundary-security.test.js`, `windows-pdf-printer.test.js`, etc.).
- GitHub PR #59 opened against `main` and merged.

---

## 3. Milestone: Phase 50 — Autonomous Edge Routine Engine, Local LAN Routing & Pilot Deployment

**Goal**: Deliver the completed edge-autonomous routine engine, sub-15ms local LAN control, and deploy the free-tier cloud backend for physical review distribution.

### Key Deliverables:
1. **FreeRTOS Edge Routine Engine**:
   - 16 autonomous routines per ESP32 chip stored in wear-leveled NVS flash.
   - Time-of-day schedules and countdown timer execution without internet.
   - Power loss state restoration in `<400ms`.
2. **Flutter Local-First Auto Switchover**:
   - Dynamic promotion to direct LAN HTTP (`POST /api/v1/relays/control`) via UDP port 4210 broadcasts.
   - Cloud HTTPS / MQTT fallback when off local Wi-Fi.
   - Scoped Android `network_security_config.xml`.
3. **Time Sync & Offline Recovery**:
   - Phone-to-ESP32 local time sync (`POST /api/v1/time`) during power cuts without internet.
   - Automatic BLE re-advertising after 10 failed Wi-Fi reconnect attempts.
4. **Free-Tier Cloud Deployment**:
   - Deploy Fastify backend on Render Web Service.
   - Provision free managed PostgreSQL on Supabase (500 MB).
   - Configure HiveMQ Cloud MQTT broker (TLS 8883).
   - UptimeRobot 5-minute health check keep-alive.
5. **Physical Reviewer Batch Assembly**:
   - Flash 5–10 ESP32 prototype boards using `factory_provisioner.py` and `scripts/build_firmware.ps1`.
   - Print A4 QR code sticker sheets (`tools/manufacturing/generate_a4_sticker_sheet.py`).
   - Execute the 4-step YouTuber demonstration protocol (The Zero-Internet Test, The Dead Router Test, The Power Cut Recovery Test, Multi-Space Remote Access).

### Acceptance Criteria:
- `flutter test` reaches **480/480 Tests Passed (100% Green)**.
- `flutter analyze` reports **0 errors, 0 warnings**.
- Standalone hardware toggles relays via LAN in `<15ms` and executes schedules autonomously with internet cable disconnected.
- Reviewer signed release APK (`v1.0.0+1`) generated.
- GitHub PR #60 opened against `main` and merged.

---

## 4. Milestone: Phase 51 — Commercial Production Scaling & Optional Local Hub (Future Horizon)

**Goal**: Transition from dev-board prototypes to commercial PCB manufacturing, and implement optional local hub interoperability for cross-device edge automations.

### Key Deliverables:
1. **Custom PCB Fabrication**: Fabricate production enclosures and double-sided SMD PCBs per `docs/hardware/production-pcb-design.md`.
2. **Silicon Security Hardening**: Enable Secure Boot v2 and AES-256 Flash Encryption via `build_production_firmware.ps1`.
3. **Optional Local Hub Bridge**:
   - Implement local hub runtime for Raspberry Pi / Linux edge devices per `EH_OPTIONAL_HUB_ECOSYSTEM_MASTER_SPECIFICATION.md`.
   - Cross-device local automations (e.g., Sensor A triggers Relay B without internet or cloud).
   - Matter & Apple HomeKit ecosystem bridging.

---

## 5. Verification Gate Taxonomy

To maintain engineering integrity, all roadmap deliverables must specify their validation boundary:

- **SOFTWARE-SIMULATED**: Unit and widget tests running against in-memory databases, mock MQTT clients, or simulated HTTP servers.
- **HOST-VERIFIED**: Native toolchain checks, static analysis, linting, and compiler verification (e.g. ESP-IDF 5.4.1 drift guard, Flutter Analyzer).
- **PHYSICALLY VALIDATED**: Real ESP32 microcontrollers connected over USB COM ports or running standalone on AC mains power, verified with physical relays, multimeters, and oscilloscopes.

