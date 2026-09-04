# Phase 27: Product Discovery, Catalog, Product Detail, Compatibility & Consumer Device Add Platform

## 1. Executive Summary

Phase 27 establishes a production-grade Product Discovery, Canonical Product Catalog, Compatibility Resolver, and Consumer Device Add platform for the EH Home smart-home ecosystem. It provides metadata-driven device exploration, real-time deterministic compatibility checks, and a seamless 5-stage onboarding wizard from product exploration to commissioned device control.

---

## 2. Architectural Overview

```
                      ┌───────────────────────────────────────────────┐
                      │              Flutter Consumer App             │
                      │  - ProductDiscoveryPage   - ProductDetailPage │
                      │  - ProductCard            - CompatibilityView │
                      │  - ConsumerDeviceAddFlowPage (Wizard UI)      │
                      └───────────────────────┬───────────────────────┘
                                              │ HTTP / JSON REST
                                              ▼
                      ┌───────────────────────────────────────────────┐
                      │            Product Catalog Router             │
                      │  /api/v1/products/discovery                   │
                      │  /api/v1/products/search                      │
                      │  /api/v1/products/compatibility               │
                      │  /api/v1/device-add/sessions                  │
                      └───────────────┬───────────────┬───────────────┘
                                      │               │
                     ┌────────────────┴────┐     ┌────┴────────────────┐
                     ▼                     ▼     ▼                     ▼
        ┌─────────────────────────┐   ┌─────────────────────────────────────────┐
        │  ProductCatalogService  │   │            DeviceAddService             │
        │  - In-Memory Cache      │   │  - Wizard Session State Machine         │
        │  - Faceted Filtering    │   │  - Claiming Orchestration               │
        │  - Deterministic Search │   │  - Channel Labeling & Room Binding      │
        │  - Compatibility Matrix │   └────────────────────┬────────────────────┘
        └────────────┬────────────┘                        │
                     │                                     ▼
        ┌────────────┴────────────┐           ┌─────────────────────────┐
        │   product-definitions/  │           │ SQLite / Postgres DB    │
        │   smart-switch (1x-4x)  │           │ - product_families      │
        │   smart-socket (1x-3x)  │           │ - product_models        │
        └─────────────────────────┘           │ - product_variants      │
                                              │ - product_assets        │
                                              │ - device_add_sessions   │
                                              └─────────────────────────┘
```

---

## 3. Product Hierarchy & Canonical Models

The product architecture follows a 4-tier model:

1. **Family (`ProductFamily`)**: Broad classification (e.g., `smart_switch`, `smart_socket`).
2. **Model (`ProductModel`)**: Product line sharing form factor or capabilities (e.g., `eh_smart_switch`, `eh_smart_socket`).
3. **Variant (`ProductVariant`)**: Specific SKU / channel configuration (e.g., `eh-smart-switch-1x`, `eh-smart-switch-2x`, `eh-smart-switch-3x`, `eh-smart-switch-4x`, `eh-smart-socket-1x`, `eh-smart-socket-2x`, `eh-smart-socket-3x`).
4. **Asset (`ProductAsset`)**: Image URLs for hero, front, rear, packaging, technical diagrams, and UI icons.

---

## 4. Product Catalog & Definitions

Standardized JSON metadata definitions are located under `product-definitions/`:

| Product Family | Variant ID | SKU | Channels | Form Factor | Energy Monitoring | Default Transports |
|---|---|---|:---:|---|:---:|---|
| Smart Switch | `eh-smart-switch-1x` | `EH-SWITCH1X-001` | 1 | 1-Module Modular | Yes | Wi-Fi, BLE |
| Smart Switch | `eh-smart-switch-2x` | `EH-SWITCH2X-001` | 2 | 2-Module Modular | Yes | Wi-Fi, BLE |
| Smart Switch | `eh-smart-switch-3x` | `EH-SWITCH3X-001` | 3 | 3-Module Modular | Yes | Wi-Fi, BLE |
| Smart Switch | `eh-smart-switch-4x` | `EH-SWITCH4X-001` | 4 | 4-Module Modular | Yes | Wi-Fi, BLE |
| Smart Socket | `eh-smart-socket-1x` | `EH-SOCKET1X-001` | 1 | Single Socket Modular | Yes | Wi-Fi, BLE |
| Smart Socket | `eh-smart-socket-2x` | `EH-SOCKET2X-001` | 2 | Dual Socket Modular | Yes | Wi-Fi, BLE |
| Smart Socket | `eh-smart-socket-3x` | `EH-SOCKET3X-001` | 3 | Triple Socket Modular | Yes | Wi-Fi, BLE |

---

## 5. Compatibility Matrix & Resolver

The `ProductCatalogService.evaluateCompatibility` engine assesses hardware revisions, firmware versions, and home networking prerequisites:

- **`COMPATIBLE`**: All required connectivity, hardware revs, and minimum firmware criteria are met.
- **`PARTIALLY_COMPATIBLE`**: Functionality works with warnings (e.g., Bluetooth offline fallback or firmware update recommended).
- **`INCOMPATIBLE`**: Critical prerequisite missing (e.g., unsupported hardware revision or missing 2.4 GHz Wi-Fi).

---

## 6. Consumer Device Add Wizard Lifecycle

```
[ ENTRY_SELECTION ] ──► [ COMPATIBILITY_CHECK ] ──► [ COMMISSIONING ] ──► [ DEVICE_CONFIG ] ──► [ COMPLETED ]
  - QR Code Scan           - Prerequisite Eval       - Multi-Protocol      - Custom Naming       - Ready to Use
  - Nearby Discovery       - Diagnostic Reasons        Provisioning        - Room Assignment
  - Manual Catalog                                   - State Sync          - Channel Labels
```

1. **Stage 1 (Entry)**: Consumer selects entry route (QR Scan, Nearby Discovery, Product Catalog, or Re-add).
2. **Stage 2 (Compatibility)**: Automated verification against home network environment and phone capabilities.
3. **Stage 3 (Commissioning)**: Secure BLE / Wi-Fi provisioning and pairing token exchange.
4. **Stage 4 (Configuration)**: Custom device naming, room assignment, and per-channel label customization.
5. **Stage 5 (Completion)**: Seamless transition to active control on the home dashboard.

---

## 7. Database Migration

Migration `020_product_discovery_catalog.sql` introduces 5 new tables:
- `product_families`: High-level product categories and taxonomy.
- `product_models`: Product model classifications.
- `product_variants`: Product SKUs, technical specs, relay channels, and rating parameters.
- `product_assets`: Multi-angle imagery, hero renders, and technical diagrams.
- `device_add_sessions`: Persistent onboarding wizard sessions with stage tracking and diagnostic metadata.

---

## 8. API Reference

| Method | Endpoint | Description | Auth |
|---|---|---|---|
| `GET` | `/api/v1/products/discovery` | Paginated product discovery with category/capability filtering | Public |
| `GET` | `/api/v1/products/search` | Multi-field weighted search matching names, SKUs, and tags | Public |
| `GET` | `/api/v1/products/categories` | List product categories with counts | Public |
| `GET` | `/api/v1/products/families` | List product families with metadata | Public |
| `GET` | `/api/v1/products/variants/:variantId` | Detailed variant metadata, specs, and controls | Public |
| `POST` | `/api/v1/products/compatibility` | Real-time compatibility verification engine | Public |
| `POST` | `/api/v1/device-add/sessions` | Initialize a new device add session | Authenticated |
| `GET` | `/api/v1/device-add/sessions/:sessionId` | Get device add session progress | Authenticated |
| `PATCH`| `/api/v1/device-add/sessions/:sessionId/stage` | Advance session stage | Authenticated |
| `POST` | `/api/v1/device-add/sessions/:sessionId/complete`| Complete onboarding and persist bindings | Authenticated |
| `POST` | `/api/v1/device-add/sessions/:sessionId/cancel`  | Cancel onboarding session | Authenticated |

---

## 9. Verification & Quality Assurance

- **Unit & Integration Tests**: 77 backend assertions (`backend/tests/phase27-product-discovery-catalog.test.js`).
- **Flutter Widget Tests**: 10 test suites covering all presentation widgets and user flows (`test/phase27_product_discovery_catalog_test.dart`).
- **Full Monorepo Regression Suite**: 37/37 suites passing cleanly with 0 failures (`scripts/validate-repo.js`).
- **Static Analysis**: Zero errors or warnings in `flutter analyze`.
