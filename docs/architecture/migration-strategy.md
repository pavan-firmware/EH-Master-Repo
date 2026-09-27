# EH Home — Monorepo Migration Strategy

**Status:** APPROVED (Part 00 Baseline)  
**Strategy:** Side-by-Side Coexistence & Controlled Transition  

---

## 1. Migration Overview

To preserve existing functionality, maintain 100% test pass rates across all 64 automated suites, and avoid breaking the working Flutter application or ESP32 firmware, we follow a strict **Side-by-Side Migration Strategy**.

```text
SMART_HOME_V1/
├── apps/
│   ├── api/                     # [NEW] Fastify + TypeScript + Drizzle ORM
│   └── desktop/                 # [NEW] Tauri v2 + React 19 + TypeScript
├── packages/
│   ├── contracts/               # [EXPANDING] Shared Zod schemas & TypeScript types
│   ├── db-schema/               # [NEW] Drizzle ORM schema definitions (001-029 + 030+)
│   └── config/                  # [NEW] Shared tsconfig, eslint, prettier presets
├── backend/                     # [PRESERVED INTACT] Current working Node.js API
├── smart_home_application_v1/   # [PRESERVED INTACT] Current Flutter mobile application
├── firmware/                    # [PRESERVED INTACT] ESP-IDF v5.4.1 firmware projects
├── hardware/                    # [PRESERVED INTACT] KiCad PCB and schematic designs
├── tools/manufacturing/         # [PRESERVED INTACT] Python PKI CA & flashing engine
└── product-definitions/         # [PRESERVED INTACT] Static JSON catalog (migrates in Part 05)
```

---

## 2. Component Migration Policies

### A. Backend (`backend/` → `apps/api/`)
1. `backend/` remains active and untouched until `apps/api/` reaches full feature and API contract parity.
2. `apps/api/` connects to the same PostgreSQL database using Drizzle ORM models reflected from existing tables (001–029) and extended with 030+ migrations.
3. Tests in `backend/tests/` continue to validate the existing system as a permanent regression guard.

### B. Flashing Engine (`tools/manufacturing/flash_device.py`)
1. In the first phase, `apps/desktop` invokes `tools/manufacturing/flash_device.py` via a controlled local process/sidecar.
2. The flashing interface in the desktop app is abstracted behind an interface (`IFlasherService`), allowing a future Rust/`espflash` implementation to be swapped in without modifying UI screens or backend contracts.

### C. Product Catalog (`product-definitions/` → PostgreSQL)
1. Static JSON files in `product-definitions/` are preserved initially.
2. In Part 05, an automated ingestion script will parse these JSON files and seed them into PostgreSQL tables (`products`, `product_variants`, `hardware_revisions`).
3. Only after the mobile app and backend verify the database-driven catalog will the static files be deprecated.

### D. Customer Mobile App (`smart_home_application_v1`)
1. The Flutter app directory remains at the root level (`smart_home_application_v1/`) to avoid breaking IDE path references, pub caches, or CI build scripts.
2. In Part 12, dynamic catalog fetching and APK per-ABI bundle optimization will be introduced incrementally with offline fallback caching.
