# EH Home Desktop UI Reconciliation — Parts 05–11

## 1. Overview & Purpose

This document details the reconciliation of the EH Home desktop presentation layer (`apps/desktop`) with the previously completed and approved Parts 05 through 11:
- **Part 04**: Desktop Foundation & Tauri v2 Shell
- **Part 05**: Product & Design Management Catalog
- **Part 06**: Hardware & BOM Management
- **Part 07 & 08**: Firmware, Git, Binary & Automated Release Management
- **Part 09**: Device Flashing & ESP32 Bench Provisioner
- **Part 10**: QR, Label & Thermal Printer Service
- **Part 11**: Production QC, Dual-Scan Verification, Master Cartons & Finished Goods Inventory

All placeholder/deferred screens for completed Parts 05–11 have been completely replaced with dedicated, production-grade presentation workspaces wired to the existing `apps/api` REST endpoints, `@eh-home/contracts` schemas, and Tauri v2 native command boundaries.

---

## 2. Complete Sidebar Domain Reconciliation Matrix

| Domain | Navigation ID | Part Alignment | Route / View Component | Backend API Source (`apps/api`) | Native Service Boundary (Tauri / Rust) | Reconciled Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Dashboard** | `dashboard` | Part 04 | `DashboardView.tsx` | `GET /health`, `GET /ready`, `GET /api/v1/system/info`, `POST /api/v1/system/echo` | `commands::check_native_service_status` | **Active / Connected** |
| **Products** | `products` | Part 05 | `ProductsView.tsx` | `GET /api/v1/products`, `GET /api/v1/products/families`, `GET /api/v1/products/variants/:id` | N/A (Data Mediated) | **Active / Reconciled** |
| **Hardware & BOM** | `hardware` | Part 06 | `HardwareBomView.tsx` | `GET /api/v1/hardware/revisions`, `GET /api/v1/hardware/revisions/:id/bom` | N/A (Data Mediated) | **Active / Reconciled** |
| **Firmware & Releases** | `firmware` | Part 07 & 08 | `FirmwareReleasesView.tsx` | `GET /api/v1/firmware/families`, `GET /api/v1/firmware/releases`, `GET /api/v1/firmware/releases/:id` | N/A (Data Mediated) | **Active / Reconciled** |
| **Bench Provisioner** | `provisioner` | Part 09 | `ProvisionerView.tsx` | `POST /api/v1/inventory/register` | `commands::list_serial_ports`, `commands::identify_esp32_device`, `commands::flash_device_sidecar`, `commands::verify_device_sidecar` | **Active / Reconciled** |
| **Label & QR Printer** | `labels` | Part 10 | `LabelPrinterView.tsx` | `GET /api/v1/inventory/device/:id` | `commands::print_label_native` (TSPL & ESC/POS 8-Gate Security) | **Active / Reconciled** |
| **Device Fleet** | `devices` | Parts 07/09/11 | `DeviceFleetView.tsx` | `GET /api/v1/inventory/device/:id`, `GET /api/v1/inventory/history` | `commands::list_serial_ports` | **Active / Reconciled** |
| **Production & QC** | `production` | Parts 09 & 11 | `ProductionQcView.tsx` | `GET /api/v1/inventory/history` | Flashing & Calibration Station Logging | **Active / Reconciled** |
| **Packing & Dual-Scan** | `packing` | Part 11 | `ProductionPackingView.tsx` | `POST /api/v1/inventory/dual-scan`, `POST /api/v1/inventory/pack`, `POST /api/v1/inventory/cartons` | `IScannerService` (Keyboard HID Barcode Scanner) | **Active / Reconciled** |
| **Inventory** | `inventory` | Part 11 | `InventoryView.tsx` | `GET /api/v1/inventory/history`, `GET /api/v1/inventory/cartons/:id` | N/A (Data Mediated) | **Active / Reconciled** |
| **Settings** | `settings` | Foundation | `SettingsView.tsx` | `GET /api/v1/system/info` | Host OS, Serial & Thermal Printer Preferences | **Active / Reconciled** |

---

## 3. Domain Architectures & Integrations

### 3.1 Products Workspace (Part 05)
- **Component**: [`apps/desktop/src/features/products/ProductsView.tsx`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/apps/desktop/src/features/products/ProductsView.tsx)
- **API Endpoints**: `GET /api/v1/products`, `GET /api/v1/products/families`
- **Single Source of Truth**: Consumes `@eh-home/contracts` `CANONICAL_PRODUCT_DEFINITIONS` across all 11 canonical smart-home variants.
- **Capabilities**: Interactive family filter, full text search across variants/SKUs, live channel count, hardware compatibility list (`HW_1_0`, `HW_1_1`), target MCU, and capability chips.

### 3.2 Hardware & BOM Workspace (Part 06)
- **Component**: [`apps/desktop/src/features/hardware/HardwareBomView.tsx`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/apps/desktop/src/features/hardware/HardwareBomView.tsx)
- **API Endpoints**: `GET /api/v1/hardware/revisions`, `GET /api/v1/hardware/revisions/:id/bom`
- **Capabilities**: Tabbed hardware revision inspector (`HW_1_0`, `HW_1_1`), full Bill of Materials (BOM) data table with MPNs, manufacturers, designators, quantities, package footprints, and cryptographic Gerber integrity verification.

### 3.3 Firmware & Releases Workspace (Part 07 & 08)
- **Component**: [`apps/desktop/src/features/firmware/FirmwareReleasesView.tsx`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/apps/desktop/src/features/firmware/FirmwareReleasesView.tsx)
- **API Endpoints**: `GET /api/v1/firmware/families`, `GET /api/v1/firmware/releases`
- **Canonical Lifecycle**: Strictly displays 7 canonical states (`DRAFT` → `BUILDING` → `VALIDATION` → `APPROVED` → `RELEASED` → `DEPRECATED` → `RETIRED`) plus the emergency `REVOKED` terminal state.
- **Capabilities**: Git branch/commit hash traceability, build number indexing, target MCU verification, and artifact SHA-256 integrity inspection.

### 3.4 Bench Provisioner Workspace (Part 09)
- **Component**: [`apps/desktop/src/features/provisioner/ProvisionerView.tsx`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/apps/desktop/src/features/provisioner/ProvisionerView.tsx)
- **Native Security Boundary**: Privileged Rust commands enforce 8 validation gates in native layer before launching sidecar flashing processes.
- **Capabilities**: COM port autodetection, ESP32-C6 chip identification, flashing progress tracker, factory NVS injection, post-flash verify, and structured traceability generation.

### 3.5 QR & Thermal Label Printer Workspace (Part 10)
- **Component**: [`apps/desktop/src/features/label-printer/LabelPrinterView.tsx`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/apps/desktop/src/features/label-printer/LabelPrinterView.tsx)
- **Native Boundary**: Privileged `print_label_native` command generating TSPL (50x30mm, 40x20mm) and ESC/POS (80mm) traveler slips with zero secrets in structured fields.
- **Canonical QR Schema**: Strictly enforces `eh://p/v1?t=<OPAQUE_TOKEN>`.

### 3.6 Device Fleet Workspace (Parts 07/09/11)
- **Component**: [`apps/desktop/src/features/devices/DeviceFleetView.tsx`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/apps/desktop/src/features/devices/DeviceFleetView.tsx)
- **API Endpoints**: `GET /api/v1/inventory/devices/:identifier`, `GET /api/v1/inventory/history`
- **Scope Invariant**: Focuses exclusively on provisioned device records, hardware revisions, firmware versions, and manufacturing identity state. Telemetry & MQTT rollout are explicitly demarcated as Part 13+.

### 3.7 Production Batches & QC Station Logs (Parts 09 & 11)
- **Component**: [`apps/desktop/src/features/production/ProductionQcView.tsx`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/apps/desktop/src/features/production/ProductionQcView.tsx)
- **Capabilities**: Multi-station log filtering (`FLASHING_BENCH`, `RELAY_CYCLE`, `DUAL_SCAN_PACKING`), First-Pass Yield (FPY) metrics, and append-only audit trail.

### 3.8 Packing & Dual-Scan Verification (Part 11)
- **Component**: [`apps/desktop/src/features/packing/ProductionPackingView.tsx`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/apps/desktop/src/features/packing/ProductionPackingView.tsx)
- **API Endpoints**: `POST /api/v1/inventory/dual-scan`, `POST /api/v1/inventory/pack`, `POST /api/v1/inventory/cartons`
- **Dual-Scan Workflow**: Enforces Scan A (Device Serial) + Scan B (Box QR Token), verifying device status (`QC_PASSED`), carton capacity, and atomic state transitions.

### 3.9 Finished Goods Inventory (Part 11)
- **Component**: [`apps/desktop/src/features/inventory/InventoryView.tsx`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/apps/desktop/src/features/inventory/InventoryView.tsx)
- **API Endpoints**: `GET /api/v1/inventory/history`, `GET /api/v1/inventory/cartons/:id`
- **Capabilities**: Finished goods stock summary, master carton allocation, status filtering (`PACKED`, `UNPACKED`, `QUARANTINED`), and shipment staging logs.

### 3.10 Workbench Settings
- **Component**: [`apps/desktop/src/features/settings/SettingsView.tsx`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/apps/desktop/src/features/settings/SettingsView.tsx)
- **Capabilities**: Local API endpoint configuration, COM port bridge preferences, thermal printer selection, and explicit visual boundary for future Part 13 cloud synchronization.

---

## 4. Test Coverage & Verification

- **Automated Desktop Tests**: 119 / 119 tests passing (`apps/desktop/tests/`)
  - `desktop.test.js`: 7 tests (Bundle integrity, security, config redaction)
  - `bench-provisioner.test.js`: 24 tests (Serial bridge, flashing, 8-gate validation)
  - `native-boundary-security.test.js`: 33 tests (Renderer bypass prevention, SHA-256 FIPS)
  - `label-printer.test.js`: 34 tests (TSPL/ESC-POS generation, zero-secret scanning)
  - `packing.test.js`: 8 tests (Dual-scan scanner HID, matching, carton validation)
  - `ui-reconciliation.test.js`: 13 tests (Route resolution, domain rendering, zero placeholders)
- **Backend API Tests**: 215 / 215 tests passing (`apps/api/tests/`)
- **Contracts Tests**: 81 / 81 Zod contract tests passing (`packages/contracts/tests/`)
- **TypeScript & Vite Production Build**: `✓ built in 7.58s` with 0 errors.

---

## 5. Explicit Hard Scope Invariants

1. **Part 13 Not Started**: MQTT, EMQX telemetry, and OTA rollout are strictly excluded from this desktop reconciliation.
2. **Flutter Customer App Unmodified**: `smart_home_application_v1/` remains untouched.
3. **Database Immutability**: Frozen database migrations `001–029` remain untouched.
4. **Direct DB Forbidden**: React frontend never accesses PostgreSQL directly; all domain operations are mediated via `apps/api` or Tauri native commands.
