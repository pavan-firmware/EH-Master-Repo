# EH Home — Product & Design Management Architecture

## 1. Domain Overview

The Product & Design Management domain establishes the core catalog, product engineering metadata, variant hierarchy, and capabilities model for EH Home products.

It links business and customer-facing catalog representations to underlying hardware definitions and firmware platforms while maintaining a clean boundary between commercial identity, physical electronics, and executable software.

```text
┌────────────────────────────────────────────────────────┐
│                   Product Family                       │
│        (e.g., smart_switch, smart_socket)              │
└──────────────────────────┬─────────────────────────────┘
                           │ 1 : N
                           ▼
┌────────────────────────────────────────────────────────┐
│                       Product                          │
│     (Commercial entity: e.g., "EH Smart Switch")       │
└──────────────────────────┬─────────────────────────────┘
                           │ 1 : N
                           ▼
┌────────────────────────────────────────────────────────┐
│                   Product Variant                      │
│   (SKU/Physical variant: e.g., "eh-smart-switch-2x")   │
└──────┬───────────────────┼──────────────────────┬──────┘
       │                   │                      │
       ▼                   ▼                      ▼
┌──────────────┐   ┌──────────────┐       ┌──────────────┐
│ Capabilities │   │   Hardware   │       │ ProductMedia │
│  (relays,    │   │   Profile    │       │   (Hero,     │
│   energy)    │   │  (MCU, GPIO) │       │   Diagrams)  │
└──────────────┘   └───────┬──────┘       └──────────────┘
                           │
                           ▼
                   ┌──────────────┐
                   │   Firmware   │
                   │    Family    │
                   └──────────────┘
```

---

## 2. Product Hierarchy & Domain Model

1. **Product Family (`product_families`):**
   - High-level categorization grouping related hardware types (e.g. `smart_switch`, `smart_socket`, `smart_fan`, `smart_light`, `smart_hub`, `sensor_node`).
   - Defines standard UX conventions, taxonomies, and default feature groupings.
2. **Product (`products`):**
   - The commercial product concept marketed to consumers and distributors.
   - Identified by stable technical ID (e.g. `eh-smart-switch`) and display name (e.g. "EH Smart Switch").
   - Governed by product lifecycle status (`DRAFT`, `STAGED`, `PUBLISHED`, `DEPRECATED`, `RETIRED`).
3. **Product Variant (`product_variants`):**
   - Specific physical configurations, channel counts, or form factors.
   - Examples: `eh-smart-switch-1x`, `eh-smart-switch-2x`, `eh-smart-switch-4x`.
   - Embeds channel mappings, electrical ratings, hardware profiles, and connectivity profiles.
4. **Product Model (`product_models`):**
   - Marketing model number, brand, generation, and commercial revision.
5. **Product Assets (`product_images` / `ProductAsset`):**
   - Structured visual assets (hero renders, front views, wiring diagrams, dimensional drawings) referenced by URL/key.
6. **Capabilities (`capabilities`, `product_capabilities`):**
   - Standard capability bindings (e.g. `switch`, `relay`, `energy`, `voltage`, `current`, `power`, `ota`, `automation`, `scene`, `schedule`).

---

## 3. Product Identifier Strategy

| Category | Identifiers | Scope & Mutability | Example |
| :--- | :--- | :--- | :--- |
| **Stable Technical IDs** | `productId`<br>`productVariantId`<br>`familyId`<br>`capabilityId` | **Immutable.** Used in APIs, database keys, firmware compatibility checks, provisioning, and QR payloads. | `eh-smart-switch`<br>`eh-smart-switch-2x`<br>`smart_switch`<br>`energy` |
| **Human / Catalog Identifiers**| `displayName`<br>`marketingName`<br>`variantSlug`<br>`sku` | **Mutable.** Used in customer app display, e-commerce catalog, packaging, and marketing materials. | "EH Smart Switch 2X"<br>"Dual-Relay Wall Switch"<br>`2x`<br>`EH-SW-2X-IN` |

---

## 4. Boundaries: Product vs. Hardware vs. Firmware

A strict architectural separation is maintained:

```text
┌─────────────────────────┐
│     Product Domain      │  Commercial & catalog identity:
│ (Product / Variant)     │  Display names, channels, UX hints, assets
└────────────┬────────────┘
             │ references
             ▼
┌─────────────────────────┐
│     Hardware Domain     │  Physical electrical design:
│  (Hardware Revision)    │  PCB revisions (HW_1_0, HW_1_1), BOM, schematics, MCU
└────────────┬────────────┘
             │ targets
             ▼
┌─────────────────────────┐
│     Firmware Domain     │  Compiled executable binary:
│  (Firmware Release)     │  Target MCU, partition tables, OTA manifests
└─────────────────────────┘
```

- **Product / Variant:** Belongs to business, catalog, and provisioning workflows.
- **Hardware Revision (`supportedHardwareRevisions`):** Tracks physical board versions (e.g. `HW_1_0`, `HW_1_1`). A single product variant may support multiple hardware revisions over its lifecycle.
- **Firmware Family (`firmwareFamily`):** Designates the codebase platform (e.g. `esp32c6-switch-platform`). Multiple product variants may share a single firmware family.

---

## 5. Media & Asset Abstraction

Binary assets (PNG, SVG, CAD files) are **never** stored directly in PostgreSQL or base64-encoded into JSON API responses.

The `ProductAsset` model represents structured asset references:
- **`assetId`:** Stable unique identifier.
- **`productVariantId`:** Owning variant.
- **`kind`:** Semantic placement (`hero`, `front`, `rear`, `installed`, `packaging`, `diagram`, `render`, `thumbnail`).
- **`purpose`:** Functional category (`marketing`, `technical`, `wiring`, `dimensions`, `catalog`).
- **`url`:** CDN / S3-compatible object storage key or relative asset path.
- **`mimeType`:** `image/png`, `image/svg+xml`, `image/jpeg`.
- **`sortOrder`:** Display ordering for UI carousels.

---

## 6. Static Definition Compatibility & Migration Strategy

Existing static product definitions under `product-definitions/` are preserved as the initial migration source of truth:

```text
product-definitions/*.json
            │
            │ deterministic parsing
            ▼
    product.adapter.ts
            │
            ▼
   ProductRepository / Drizzle
            │
            ▼
   apps/api /api/v1/products
```

### Field Ownership Rules
- **Static Definition Owned:**
  - `variantSlug`, `channelCount`, `channels`
  - `hardwareProfile`, `connectivityProfile`
  - `capabilities`, `electricalSpecifications`
  - `firmwareFamily`, `supportedHardwareRevisions`
- **Database / API Owned:**
  - `status` (publication lifecycle: `DRAFT`, `PUBLISHED`, `DEPRECATED`)
  - `createdAt`, `updatedAt`
  - Catalog enrichment, dynamic marketing tags, category promotions

---

## 7. Product Catalog API Endpoints

The API is exposed under `/api/v1/products`:

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/api/v1/products` | `GET` | List catalog products with pagination and filters (`familyId`, `capability`, `connectivity`, `status`). |
| `/api/v1/products/families` | `GET` | List available product families. |
| `/api/v1/products/:productId` | `GET` | Retrieve complete product details with all associated variants, capabilities, and assets. |
| `/api/v1/products/variants/:variantId` | `GET` | Retrieve single variant specifications, channel configurations, and hardware profiles. |

---

## 8. Capability Relationship to Customer UI

Capabilities directly drive dynamic client behavior in the customer Flutter mobile app and internal desktop app:
1. When a device is provisioned, its `productVariantId` resolves supported capabilities.
2. The client application inspects `capabilities` (e.g. `switch`, `energy`) and `channels` to dynamically render controls (toggles, sliders, energy graphs) without hardcoding per-product UI screens.
