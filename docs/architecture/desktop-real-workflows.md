# EH Home Desktop Application — Architecture & Real Management Workflows

## 1. Overview & Architectural Principles

The **EH Home Desktop Workbench** (`apps/desktop`) is an engineering workstation designed with a VS Code-inspired dark UI theme for hardware engineering, bench provisioning, production testing, label printing, dual-scan packaging, and warehouse inventory management.

### Key Invariants & Guarantees:
1. **Zero Dummy Runtime Data**: Production UI renders zero hardcoded runtime records, simulated COM ports, fake chip responses, or mock telemetry arrays.
2. **Canonical Contract Alignment**: All product variants, hardware revisions, firmware lifecycle states, and serial/QR formats are single-sourced from `@eh-home/contracts`.
3. **Real Native Hardware Boundaries**: Hardware peripherals (ESP32 serial flashing via Tauri `commands.rs`, USB thermal label printing via TSPL/ESC-POS, HID barcode scanners) interact exclusively with real system devices and drivers.
4. **Virtual Document Support**: `Microsoft Print to PDF` generates authentic binary PDF-1.4 documents client-side with automatic download and saving for paperless testing and validation.
5. **Full API CRUD & Persistence**: Product catalog, BOM specifications, firmware releases, device registrations, QC station logs, carton allocations, and inventory stock adjustments communicate directly with `apps/api`.
6. **Graceful Empty & Error States**: An empty database or disconnected backend produces clear, informative empty states and retry controls rather than placeholder mock data.

---

## 2. Workbench Visual Design & Layout

Inspired by modern developer IDEs (VS Code):
- **Title Bar (`Header.tsx`)**: 32px compact header with breadcrumb hierarchy (`workbench > domain > view`), live backend connectivity pill (`ONLINE` / `OFFLINE`), active COM port indicator, and quick API echo probe.
- **Activity Sidebar (`Sidebar.tsx`)**: 220px collapsible explorer sidebar with domain category badges (`Part 05`, `Part 06`, `Part 07`, `Part 09`, `Part 10`, `Part 11`), section groupings (Core Catalog, Bench Engineering, Production & Logistics, System), and real-time status badges.
- **Status Bar (`StatusFooter.tsx`)**: 22px footer displaying serial baud rate, active label printer engine, scanner status, current API base URL, and workspace environment.
- **Theme Palette**: Deep dark background (`#1E1E1E`, `#252526`), neutral borders (`#3C3C3C`), VS Code Blue (`#007ACC`, `#0E639C`), mint accents (`#4EC9B0`), warning yellow (`#CCA700`), and error red (`#F14C4C`).

---

## 3. Implemented Workflows & View Domains

| Domain | Part | Purpose & Workflows |
|---|---|---|
| **System Dashboard** | All | Live backend health checks, round-trip API echo latency probe, database entity summary counters, quick navigation. |
| **Products & Variants** | Part 05 | Split-pane catalog explorer, product family filtering, Create Product modal, Create Variant modal, Edit Variant modal, capability badges. |
| **Hardware & BOM** | Part 06 | PCB revision management, Gerber SHA-256 integrity verification, interactive Bill of Materials (BOM) table, Add BOM Component modal, status transitions (`DRAFT` &rarr; `APPROVED` &rarr; `ACTIVE` &rarr; `OBSOLETE`). |
| **Firmware & Releases** | Part 07/08 | 7-stage canonical firmware lifecycle management (`DRAFT` &rarr; `BUILDING` &rarr; `VALIDATION` &rarr; `APPROVED` &rarr; `RELEASED` &rarr; `DEPRECATED` &rarr; `REVOKED`), cryptographic SHA-256 payload verification, Create Release Draft modal. |
| **Bench Provisioner** | Part 09 | Host serial port discovery (zero fake COM ports), ESP32 chip identification (`identify_esp32_device`), 8-gate bench pre-flash validation, live flash execution, audit log capture. |
| **Label & QR Printer** | Part 10 | Provisioned device selection, 8-gate print validation, TSPL / ESC-POS deterministic command rendering, `Microsoft Print to PDF` virtual PDF document creation. |
| **Device Fleet** | Part 07/09/11 | Fleet identity explorer, search by serial / variant / UUID, lifecycle transitions (`Mark QC Passed`, `Mark Packed`, `Quarantine Device`, `Release Quarantine`). |
| **Production & QC** | Part 09/11 | Station verification logs (`FLASHING_BENCH`, `DUAL_SCAN_PACKING`), dynamic First-Pass Yield (FPY) computation, Record QC Operation modal. |
| **Packing & Dual-Scan** | Part 11 | Two-stage physical packaging verification (Scan A serial + Scan B box QR token), active master carton management, zero simulation controls in production UI. |
| **Finished Goods Inventory** | Part 11 | Warehouse stock registry, master carton allocations, Manual Stock Adjustment modal, live inventory query. |
| **Workbench Settings** | System | Persistent configuration via browser local storage (API base URL, default COM port, baud rate, default printer, HID scanner auto-commit). |

---

## 4. Test Verification Summary

The desktop application is covered by 7 comprehensive test suites:
1. `tests/desktop-client.test.js`: ApiClient envelope normalization, error handling, correlation IDs.
2. `tests/bench-provisioner.test.js`: 8-gate flashing safety validation, serial port integration.
3. `tests/label-printer.test.js`: 34 tests for canonical QR generation, TSPL/ESC-POS rendering, 8-gate print safety.
4. `tests/dual-scan-packing.test.js`: Dual-scan match enforcement, state transitions, zero-secret verification.
5. `tests/ui-reconciliation.test.js`: Route resolution across all 11 domains, non-placeholder UI verification, static data audit.
6. `tests/desktop-e2e.test.js`: 19 end-to-end tests against a live Fastify backend server.
7. TypeScript Compilation & Vite Build: 100% strict type safety check with `tsc && vite build`.
