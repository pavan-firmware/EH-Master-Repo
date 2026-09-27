# EH HOME ARCHITECTURE — PART 15: E2E VALIDATION & CI/CD PIPELINES

**Version**: 1.1.0  
**Status**: Authoritative / Approved  
**Domain**: Continuous Integration, Automated Build & Test Orchestration, Cross-Layer E2E Verification, Desktop E2E Validation  

---

## 1. Executive Summary

Part 15 implements the **Cross-Layer End-to-End (E2E) Validation Suite and Multi-Stage CI/CD Pipeline Orchestration** for the EH Home Platform. It connects and validates all approved subsystems across Parts 00–14:

```text
Shared Contracts (@eh-home/contracts)
       ↓
PostgreSQL Migrations (001–035) & DB Schema (@eh-home/db-schema)
       ↓
Fastify HTTP API & Security Middleware (apps/api)
       ↓
EMQX 5.8.0 MQTT Broker & Mutual TLS Transport (eh/{family}/{deviceId}/...)
       ↓
Device Simulation & Hardware Provisioning Harness (tools/manufacturing)
       ↓
Dynamic Capabilities & Channel Rendering Engine (smart_home_application_v1)
       ↓
Desktop Manufacturing & Provisioning Console (apps/desktop)
```

Every merge and release candidate is strictly governed by **fail-closed automated test gates**, ensuring zero schema drift, zero unverified state mutations, zero sensitive secret leakage, and zero desktop UI regressions.

---

## 2. Desktop Application E2E & Integration Architecture

The Desktop application ([apps/desktop](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/apps/desktop)) provides the factory and workbench control plane. The Part 15 Desktop E2E Suite ([apps/desktop/tests/desktop-e2e.test.js](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/apps/desktop/tests/desktop-e2e.test.js)) tests real application boundaries:

```text
Tauri Application
       ↓
React UI Component Hierarchy
       ↓
Desktop ApiClient (with x-request-id correlation)
       ↓
Real apps/api Fastify HTTP Server
```

and for privileged manufacturing operations:

```text
Desktop UI Workbench
       ↓
Tauri Native Command Boundary (commands.rs)
       ↓
Native Service Isolation (Python Sidecar / Thermal Printer / Serial HID)
```

### Verified Desktop Platform Domains (11 Domains)

| Domain | Navigation Tab | Verification Scope & API / Native Boundary | E2E Status |
| :--- | :--- | :--- | :--- |
| **Factory Dashboard** | `dashboard` | Factory overview metrics, connected services, station activity | **PASSED** |
| **Products (Part 05)** | `products` | `listProducts`, `listProductFamilies`, 11 variants catalog, hardware compatibility | **PASSED** |
| **Hardware & BOM (Part 06)** | `hardware` | `listHardwareRevisions`, `getBOM`, PCB layer specs, MPN audit, Gerber SHA-256 | **PASSED** |
| **Firmware & Releases (Part 07/08)** | `firmware` | `listFirmwareReleases`, `listFirmwareFamilies`, 7-stage lifecycle (`RELEASED` gate) | **PASSED** |
| **Bench Provisioner (Part 09)** | `provisioner` | Discovery, 8-gate artifact validation, flashing sidecar, traceability records | **PASSED** |
| **Label / QR Printer (Part 10)** | `labels` | Opaque QR URI (`eh://p/v1?t=...`), 8-gate print validation, deterministic TSPL/ESCPOS | **PASSED** |
| **Device Fleet (Parts 07/09/11)** | `devices` | Device records, MAC addresses, firmware versions, hardware revision binding | **PASSED** |
| **Production & QC (Parts 09/11)** | `production` | First-Pass Yield (FPY), station verification logs, flashing and dual-scan audit trails | **PASSED** |
| **Packing & Dual-Scan (Part 11)** | `packing` | Scan A device + Scan B box QR match (`MATCH_APPROVED`), mismatch rejection (`MISMATCH_REJECTED`) | **PASSED** |
| **Finished Goods Inventory (Part 11)** | `inventory` | `getPackingHistory`, `createCarton`, stock registry, master carton aggregation | **PASSED** |
| **Settings / Security & Audit (Part 14)** | `settings` | Local hardware bridge preferences, API endpoints, `SERVICE` least-privilege matrix | **PASSED** |

---

## 3. Mandatory Live EMQX CI Gating & Local vs CI Semantics

### Local Development Mode (Non-Docker Host)
* When running locally without Docker active, the live EMQX daemon suite exits with code 2.
* `scripts/validate-repo.js` logs: `[SKIPPED - PENDING DAEMON] Phase 6 Real EMQX 5.8.0 Integration Tests`.
* Mock MQTT transport and HTTP authorizer suites execute with 100% pass rate.

### Required CI Mode (`CI=true` / `--ci`)
* In GitHub Actions CI, an ephemeral `emqx/emqx:5.8.0` container is started with ephemeral mTLS certificates mounted from `.local-certs`.
* The runner polls port 1883 with explicit readiness checks before test execution.
* If EMQX is unreachable or startup fails, `backend/tests/phase6-emqx-integration.test.js` **exits with status 1 and immediately fails the CI pipeline**.
* **Silent skips are strictly disallowed in CI mode.**

---

## 4. Canonical E2E Integration Flows (API Layer)

The API Cross-Layer E2E Suite ([apps/api/tests/e2e-master-flows.test.js](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/apps/api/tests/e2e-master-flows.test.js)) executes Flows A through G:

* **Flow A — Product Definition & Dynamic Catalog**: Validates all 11 canonical product variants consumed symmetrically without hardcoded UI duplication.
* **Flow B — Device Registration & Provisioning Traceability**: Validates bench provisioning lineage, MAC/Serial binding, certificate fingerprint logging, and storage into `device_identities`.
* **Flow C — Device Claiming, Ownership & Cross-Owner Rejection**: Enforces user claiming into authorized homes and strictly rejects cross-owner mutations with `403 CROSS_OWNER_DENIED`.
* **Flow D — Device Command Dispatch & Receipt**: Validates authenticated command dispatch with `device:control` permission and acknowledgment receipt parsing.
* **Flow E — Telemetry Ingestion & Validation**: Validates fixed-point energy telemetry (`v_mv`, `i_ma`, `p_mw`, `e_tot_wh`, `pf_x1000`, `freq_mhz`) with physical range constraints.
* **Flow F — Manufacturing QC, Dual-Scan Packing & Inventory**: Validates QC testing logs, dual-scan verification matching physical device serials with carton box QR tokens (`MATCH_APPROVED`), and rejects mismatched tokens (`MISMATCH_REJECTED`).
* **Flow G — Firmware Release, Lifecycle Gating & OTA Deployment**: Validates the 8-state firmware lifecycle and enforces that only `RELEASED` (or legacy `PUBLISHED`) artifacts with matching MCU targets (`esp32-c6`, `esp32-s3`) can authorize production OTA rollout.

---

## 5. Testing Taxonomy & Level Classification

| Level | Description | Repository Scope |
| :--- | :--- | :--- |
| **UNIT TEST** | Isolated module logic with in-memory mocks | Fast, isolated unit tests across contracts, services, and repositories |
| **COMPONENT TEST** | React UI and Flutter widget rendering and interaction | Desktop views, Flutter widgets, dynamic channel controls |
| **INTEGRATION TEST** | Multi-component verification against real database/services | PostgreSQL migrations, Fastify plugin chains, MQTT mock transports |
| **DESKTOP E2E TEST** | Desktop UI → ApiClient → Live Fastify Server → Native commands | Full workbench navigation, dual-scan packing, 8-gate provisioning |
| **SIMULATED DEVICE** | Software TCP/MQTT device simulation | Mock device responding to commands and emitting telemetry |
| **HARDWARE TEST HARNESS** | Automated bench flasher and UART protocol test harness | Hardware loopback and serial verification fixtures |
| **PHYSICAL HARDWARE** | Real physical ESP32-C6 / ESP32-S3 boards | Physical bench flasher and hardware lab validation |

---

## 6. CI/CD Claim Accuracy

* **CI Workflow Configuration**: Implemented, syntax-verified, and locally validated across `.github/workflows/ci.yml`.
* **Local Validation Status**: 73 suites attempted, 72 passed, 1 skipped (real EMQX live daemon pending Docker in local Windows host), 0 failed.
* **Remote CI Execution Status**: No remote GitHub Actions execution was performed in this environment. Local validation is complete and fully reproducible.

---

## 7. Local Reproduction Commands

```bash
# 1. Compile all TypeScript packages
node node_modules/.pnpm/typescript@5.9.3/node_modules/typescript/lib/tsc.js --project packages/contracts/tsconfig.json
node node_modules/.pnpm/typescript@5.9.3/node_modules/typescript/lib/tsc.js --project packages/db-schema/tsconfig.json
node node_modules/.pnpm/typescript@5.9.3/node_modules/typescript/lib/tsc.js --project apps/api/tsconfig.json

# 2. Run Contracts & Zod hardening tests (99 tests)
node packages/contracts/tests/zod-contract.test.js

# 3. Verify PostgreSQL migration parity (001-035 across 121 tables)
node backend/migrations/verify-migrations.js

# 4. Run Part 14 Security, RBAC & Audit tests (40 tests)
node apps/api/tests/security-rbac-audit.test.js

# 5. Run Part 15 Cross-Layer E2E Master Flows (17 tests)
node apps/api/tests/e2e-master-flows.test.js

# 6. Run Part 15 Desktop E2E & Cross-Layer Integration Suite (19 tests)
node apps/desktop/tests/desktop-e2e.test.js

# 7. Run Full Repository Pre-Push Master Validation (73 suites)
node scripts/validate-repo.js
```
