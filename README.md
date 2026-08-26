# EH Home — Production Smart-Home Platform Monorepo

Welcome to the **EH Home** ecosystem repository. EH Home is an end-to-end, capability-driven smart-home platform supporting smart switches (1X/2X/3X/4X), sockets, fan regulators, CCT/dimmable lighting, deterministic energy monitoring, local automation, and multi-protocol hardware abstraction (Wi-Fi, BLE, Thread, Matter).

---

## 1. Monorepo Architecture Overview

The workspace is organized as a structured monorepo designed for high reliability, strict contract safety, and metadata-driven extensibility:

```
SMART_HOME_V1/
├── assets/                  # Brand and visual design assets
│   └── branding/
├── backend/                 # Backend services, migrations, and repositories
│   ├── migrations/          # Symmetric UP/DOWN PostgreSQL migrations & seed
│   ├── src/                 # Repositories, catalog services, API routers
│   └── tests/               # Database integration, hardening & catalog test suites
├── docs/                    # Architecture documentation, ADRs, planning
│   ├── adr/                 # Architecture Decision Records
│   ├── architecture/        # Architecture specifications & repository governance
│   ├── contracts/           # Contract documentation & deterministic energy protocol
│   ├── planning/            # Implementation plans and master prompt documentation
│   └── screens_implement/   # UI specification reference guides
├── firmware/                # Device firmware platforms
│   └── legacy-v1/           # Preserved legacy node/hub reference implementation
├── packages/
│   └── contracts/           # Canonical Draft-07 JSON Schemas, TypeScript contracts & validators
├── product-definitions/     # Metadata-driven product catalog definitions (SKUs)
│   └── smart-switch/3x/     # EH Smart Switch 3X metadata & hardware profiles
├── smart_home_application_v1/ # Production Flutter mobile & tablet application
│   ├── lib/                 # App logic, capability engine, theme tokens, screens
│   └── test/                # Unit, widget, theme & capability engine test suites
├── tools/
│   └── device-simulator/    # Contract-compliant device hardware simulator
├── .env.example             # Local development configuration template
└── docker-compose.yml       # Development PostgreSQL, Redis, and EMQX services
```

---

## 2. Implemented Architecture Phases

| Phase | Description | Status |
|---|---|---|
| **Phase 1** | **Canonical Contracts & Schema Freeze** (19 JSON Schemas, validator engine, 14 canonical capabilities, simulator, initial SQL) | ✅ Complete & Hardened |
| **Phase 2** | **PostgreSQL Persistence Foundation** (22 relational tables, 11 repository modules, migration verification, audit & outbox) | ✅ Complete & Hardened |
| **Phase 3** | **Product Metadata + Capability Engine** (Catalog service, read-only router, Flutter capability resolver & dynamic UI renderers) | ✅ Complete & Hardened |
| **Phase 4** | **Home / Floor / Room / Device Domain Model** (DeviceRepository, DeviceStateRepository, CommandRepository, home-device router, domain service) | ✅ Complete & Merged |
| **Phase 5A** | **Secure Device Onboarding Foundation** (EH1 QR payload parsing, provisioning session lifecycle, claim service, audit) | ✅ Complete & Merged |
| **Phase 5B** | **Secure BLE Commissioning & Provisioning** (EH-PROV/1 crypto: HMAC-SHA256, HKDF-SHA256, AES-256-GCM, canonical transcript, mTLS confirmation boundary, firmware BLE GATT layer, Flutter BLE channel) | ✅ Complete & Merged |
| **Phase 6** | **Secure MQTT Device Transport & Cloud Device Control** (MqttDeviceTransport, canonical topic builder/parser, command lifecycle, physical switch authority, LWT availability, telemetry ingestion, real EMQX 5.8.0 mTLS + per-device ACL) | ✅ Complete & Merged |
| **Phase 7A** | **Backend Production API + Auth + Authorization** (RS256 JWT access tokens, PBKDF2 password hashing, single-use refresh token rotation, rate limiting, multi-tenant home membership isolation, route protection) | ✅ Complete & Merged |
| **Phase 7B** | **Realtime SSE + Background Workers** (SSE event stream, backend event bus, stale detector, command timeout worker, outbox retry worker, worker lifecycle runner) | ✅ Complete & Merged |
| **Phase 7C** | **Flutter Cloud Integration + Real Device Control** (ApiClient, AuthRepository, FlutterSecureStorage, SseClient, RealtimeEventService, HomeController cloud convergence) | ✅ Complete & Merged |

> **Hardware Validation:** Physical ESP32 hardware not connected in this environment. `HARDWARE VALIDATION: PENDING` — `MANUFACTURING PKI VALIDATION: PENDING`.


---

## 3. Core Architectural Principles

1. **Device is the Hardware Authority:** The physical hardware is the single source of truth for its physical state. Backend derives `actualState` from `reportedState`; `desiredState` represents in-flight intent only.
2. **Physical Switch Override:** Manual switch toggles take immediate hardware precedence; conflicting in-flight cloud commands converge to `OVERRIDDEN`.
3. **Transport Neutrality:** `IDeviceTransport` decouples business logic from communication protocols (MQTT, HTTP, BLE, Thread, Matter).
4. **Metadata-Driven Capability UI:** Flutter UI dynamically generates controls from resolved product capabilities rather than creating hardcoded screens per SKU.
5. **Deterministic Energy Telemetry:** All electrical measurements are fixed-point unsigned integers on wire (`v_mv`, `i_ma`, `p_mw`, `e_tot_wh`, `pf_x1000`).

---

## 4. Local Development Setup

### Prerequisites
- **Node.js**: `v20.x` or later
- **Flutter SDK**: `3.12.x` or later (Dart 3.x)
- **Docker & Docker Compose** (for PostgreSQL, Redis, EMQX)

### Quick Start
1. Copy the environment configuration:
   ```bash
   cp .env.example .env
   ```
2. Start local infrastructure services:
   ```bash
   docker compose up -d
   ```
3. Run monorepo validation test suites:
   ```bash
   node scripts/validate-repo.js
   ```
4. Run Flutter mobile application tests:
   ```bash
   cd smart_home_application_v1
   flutter test
   ```

---

## 5. Security & Governance

- **Zero Secret Commits:** Production secrets, private keys (`.pem`, `.key`), certificates, and live credentials must never be committed.
- **Protected Flutter Application:** `smart_home_application_v1/` is maintained under strict regression testing (`flutter analyze` and `flutter test` must pass 100%).
- **Canonical Contracts:** Any breaking change to `packages/contracts/` or `product-definitions/` requires an Architecture Decision Record (ADR). See [docs/architecture/repository-governance.md](docs/architecture/repository-governance.md).
