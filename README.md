# EH Home — Production Smart-Home Platform Monorepo

Welcome to the **EH Home** ecosystem repository. EH Home is an enterprise-grade, edge-autonomous, local-first smart-home platform supporting multi-gang smart switches (1X/2X/3X/4X), sockets, fan regulators, CCT/dimmable lighting, deterministic energy monitoring, on-chip FreeRTOS automation, and multi-protocol hardware abstraction (Wi-Fi, BLE, Thread, Matter).

---

## 1. Monorepo Architecture Overview

The workspace is organized as a unified monorepo engineered for strict contract safety, zero-downtime offline execution, and metadata-driven UI:

```
SMART_HOME_V1/
├── apps/
│   ├── api/                     # High-performance Fastify REST API & SSE Realtime Engine
│   └── desktop/                 # Tauri v2 + Rust + React Desktop Suite (Bench Provisioner, TSPL, Packing)
├── assets/                      # Brand, visual assets & product iconography
├── backend/                     # Node.js backend services, migrations, repositories & workers
│   ├── migrations/              # 37 symmetric UP/DOWN PostgreSQL migrations & seed data
│   ├── src/                     # Repositories, domain services, and REST/SSE API routers
│   └── tests/                   # Monorepo database integration, hardening & lifecycle test suites
├── docs/                        # Complete technical architecture, ADRs, runbooks & phase reports
│   ├── adr/                     # Architectural Decision Records (ADR-000 through ADR-004)
│   ├── architecture/            # Architecture specifications, Parts 00–17 & business guides
│   ├── contracts/               # Protocol contracts & deterministic energy specifications
│   ├── manufacturing/           # Factory bench provisioning & thermal label printing guides
│   └── reconciliation/          # Technical reconciliation audits & feature completion registers
├── firmware/                    # Production ESP32 embedded firmware
│   ├── platforms/esp32/         # FreeRTOS firmware (Edge Routine Engine, UDP Discovery, mTLS MQTT, OTA)
│   └── legacy-v1/               # Preserved legacy node/hub reference implementation
├── packages/
│   ├── contracts/               # Canonical Draft-07 JSON Schemas, TypeScript contracts & validators
│   └── db-schema/               # Drizzle ORM relational models & database definitions
├── product-definitions/         # Metadata-driven product catalog definitions (SKUs & hardware profiles)
├── smart_home_application_v1/   # Production Flutter mobile application (iOS, Android, Web)
│   ├── lib/                     # Stale-while-revalidate UI, capability engine, theme tokens, controllers
│   └── test/                    # Full unit, widget, lifecycle & capability regression test suites
├── tools/
│   ├── database/                # Backup, restore & replication utilities
│   ├── device-simulator/        # Contract-compliant device hardware simulator
│   ├── hardware-test-harness/   # Python hardware loopback and ESP32 lifecycle runner
│   └── manufacturing/           # Factory flasher, PKI manager & TSPL label generators
├── scripts/
│   └── validate-repo.js         # Master CI pre-push validation suite (80 comprehensive test suites)
├── .env.example                 # Local development configuration template
└── docker-compose.yml           # Local infrastructure stack (PostgreSQL, Redis, EMQX 5.8.0, MinIO)
```

---

## 2. Platform Architecture Phases (Phases 1 — 50)

| Phase Range | Subsystems Covered | Key Capabilities Implemented | Status |
|:---|:---|:---|:---:|
| **Phases 1–4** | Contracts, Persistence, Catalog & Domain | 19 canonical Draft-07 JSON schemas, PostgreSQL persistence, catalog discovery, home/floor/room/device domain entities. | ✅ Complete |
| **Phases 5–7** | Onboarding, Transports & Realtime | EH-PROV/1 BLE commissioning (AES-256-GCM, HKDF), EMQX 5.8.0 mTLS transport with per-device ACLs, RS256 JWT auth, realtime SSE event bus. | ✅ Complete |
| **Phases 8–11** | PKI, Automations & Fleet Reliability | Manufacturing root PKI, signed dual-slot OTA rollback, FreeRTOS edge routine engine, hardware watchdog & auto-healing. | ✅ Complete |
| **Phases 12–18** | Security, Fleet Rollout & Cloud Sync | Multi-tenant RBAC, remote backup storage, staggered OTA fleet deployments, disaster recovery snapshotting. | ✅ Complete |
| **Phases 19–25** | Energy, Tariffs & Decision Intelligence | Fixed-point energy telemetry (`BL0942`), ToU dynamic tariffs, energy optimization engine, occupancy presence inference. | ✅ Complete |
| **Phases 26–30** | Edge Control, Matter & User Alerts | Multi-protocol connectivity (Wi-Fi/BLE/Thread/Matter), local-first LAN UDP control (`<15ms`), smart notification de-duplication. | ✅ Complete |
| **Phases 31–36** | Security Hardening & Runtime Auth | Device trust center, cryptographic attestation, role-gated admin console, hardcoded breaker elimination, Flutter lifecycle convergence. | ✅ Complete |
| **Phases 37–46** | Database Scale, Manufacturing & Acceptance | 37 symmetric database migrations, MinIO S3 remote storage, bench flasher, automated thermal label printing, dual-scan packing station. | ✅ Complete |
| **Phases 47–48** | ESP32 Hardware Integration & RBAC | Physical ESP32 target verification, non-EM/EM switch variants, home ownership & membership RBAC (`OWNER`, `ADMIN`, `MEMBER`, `GUEST`). | ✅ Complete |
| **Phase 49** | Edge Routine Engine & Zero-Touch LAN | FreeRTOS on-chip timer routine engine, zero-touch UDP LAN switchover, dual-scan factory packing station, Windows PDF printing subsystem. | ✅ Complete |
| **Phase 50** | Resilience, Dark Theme & Master Flows | Offline stale-while-revalidate, dark-theme contrast tokens, routine notification filtering, truthful MQTT standby reporting, home owner admin access control. | ✅ Complete |

---

## 3. Core Architectural Principles

1. **Hardware is the Authority:** Physical switch toggles execute immediately at the hardware relay. Backend derives `actualState` from `reportedState`; conflicting in-flight cloud commands converge to `OVERRIDDEN`.
2. **Local-First & Edge-Autonomous:** Smart switches and sockets store routines in on-chip non-volatile storage (NVS). Routines execute via FreeRTOS hardware timers even if Wi-Fi or cloud connections are down.
3. **Zero-Touch LAN Control:** When the mobile app is on the local Wi-Fi network, commands travel directly over private LAN HTTP/UDP with `<15ms` latency. When outside, the app automatically transitions to TLS MQTT via the cloud backend.
4. **Role-Based Home Access Control (RBAC):**
   - **`OWNER`**: Full administrative authority over home, disaster recovery snapshots, device trust certificates, members, and billing.
   - **`ADMIN`**: Household management, rooms, device pairing, and routine scheduling.
   - **`MEMBER` / `GUEST`**: Day-to-day actuator controls and scene triggering with strict exclusion from system-level administrative pages.
5. **Deterministic Energy Telemetry:** All electrical measurements are fixed-point unsigned integers on wire (`v_mv`, `i_ma`, `p_mw`, `e_tot_wh`, `pf_x1000`) ensuring exact financial and consumption precision.
6. **Stale-While-Revalidate UX:** Settings, home details, dashboards, and routines display instantly from persistent local storage during offline cold starts or screenshot events, refreshing quietly in the background without blanking screens.

---

## 4. Local Development & Verification

### Prerequisites
- **Node.js**: `v20.x` or later (pnpm recommended)
- **Flutter SDK**: `3.12.x` or later (Dart 3.x)
- **Docker & Docker Compose** (for PostgreSQL, Redis, EMQX 5.8.0, MinIO)
- **Rust Toolchain**: `1.75+` (for Desktop Tauri suite)

### Quick Start
1. Copy the environment configuration:
   ```bash
   cp .env.example .env
   ```
2. Start local infrastructure services:
   ```bash
   docker compose up -d
   ```
3. Run the full pre-push validation suite (all 80 suites):
   ```bash
   node scripts/validate-repo.js
   ```
4. Run Flutter mobile application analyzer and tests:
   ```bash
   cd smart_home_application_v1
   flutter analyze
   flutter test
   ```

---

## 5. Master Validation Suite Overview

The monorepo includes an automated pre-push gate (`scripts/validate-repo.js`) executing **80 comprehensive test suites** covering all platform layers:

```
===============================================================
       EH HOME MONOREPO — PRE-PUSH FULL VALIDATION SUITE       
===============================================================
  [PASS]  1. Canonical Contract Hardening Tests
  [PASS]  2. Product Catalog Definition Validation
  [PASS]  3. Device Simulator Contract Compliance
  [PASS]  4. SQL Migration Lifecycle & Capability Sync (37 Migrations)
  [PASS]  5. Backend DB & Repository Integration Tests
  [PASS]  6. Backend Hardening Test Suite (Auth, State, Idempotency)
  [PASS]  7. Product Catalog Service & API Router Tests
  [PASS]  8. Phase 4 Backend Domain Model & Service Tests
  [PASS]  9. Phase 5 Backend Secure Onboarding & Claiming Tests
  [PASS] 10. Phase 6 MQTT Transport Unit/Mock Tests
  [PASS] 11. Phase 6 Low-Level MQTT Protocol Harness Tests
  [PASS] 12. Phase 6 Real EMQX 5.8.0 Integration Tests
  [PASS] 13. Phase 7A Backend Auth & Authorization Tests
  [PASS] 14. Phase 7B Realtime SSE & Worker Integration Tests
  [PASS] 15. Flutter Analyzer (smart_home_application_v1)
  [PASS] 16. Flutter Test Suite (smart_home_application_v1)
  ...
  [PASS] 72. Part 15 Desktop E2E & Cross-Layer Integration Tests
  [PASS] 73. Part 16 Storage Contracts Hardening
  [PASS] 74. Part 16 S3-Compatible Storage Provider Tests
  [PASS] 75. Part 16 Database Backup, Restore & Recovery Tests
  [PASS] 76. Part 16 Storage & Backup HTTP API Route Tests
===============================================================
  80 SUITES ATTEMPTED: 80 PASSED, 0 SKIPPED, 0 FAILED.
  ALL ATTEMPTED TEST SUITES COMPLETED WITHOUT FAILURE.
===============================================================
```

---

## 6. Security, Governance & Compliance

- **Zero Committed Secrets:** All certificates (`.pem`, `.crt`), keys (`.key`), and tokens are injected via environment variables or generated ephemerally during manufacturing bench flows.
- **Strict Lint & Contract Guard:** Any modification to schemas in `packages/contracts/` must pass Draft-07 validation and maintain bidirectional compatibility across mobile, backend, and firmware.
- **Git Housekeeping:** Test assets and scratch images (`prompt_images/`) are explicitly excluded from repository history via `.gitignore`.
