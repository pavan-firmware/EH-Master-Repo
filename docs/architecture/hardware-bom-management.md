# EH Home — Hardware & BOM Management Architecture

## 1. Overview & Purpose

The Hardware & Bill of Materials (BOM) Management domain governs the physical electronics, PCB layouts, electrical component compositions, and design lifecycle of EH Home devices.

It bridges the commercial **Product & Variant** catalog (established in Part 05) with physical **KiCad PCB projects**, component supply chains, and upcoming **Firmware Compatibility** (Part 07) and **Manufacturing Flashing** (Part 08).

```text
┌────────────────────────────────────────────────────────┐
│                    Product Variant                     │
│               (e.g., eh-smart-switch-1x)               │
└──────────────────────────┬─────────────────────────────┘
                           │ 1 : N (supportedHardwareRevisions)
                           ▼
┌────────────────────────────────────────────────────────┐
│                   Hardware Revision                    │
│             (e.g., HW_1_0, smart_switch_3x)            │
└────────────┬─────────────────────────────┬─────────────┘
             │ 1 : N                       │
             ▼                             ▼
┌──────────────────────────┐       ┌──────────────┐
│     BOM Specification    │       │ KiCad Design │
│   (e.g., v1.0.0, ACTIVE) │       │ (Schematic / │
└────────────┬─────────────┘       │   Layout)    │
             │ 1 : N               └──────────────┘
             ▼
┌──────────────────────────┐
│        BOM Items         │
│ (ESP32-C6, HLK-PM01, etc)│
└────────────┬─────────────┘
             │ 0 : N
             ▼
┌──────────────────────────┐
│ Component Substitutions  │
│ (Alternate Part Numbers) │
└──────────────────────────┘
```

---

## 2. Critical Identity Boundary

To maintain operational integrity across manufacturing and OTA lifecycles, identities must never be conflated:

| Domain | Entity | Example Identifier | Immutability | Scope |
| :--- | :--- | :--- | :--- | :--- |
| **Commercial** | Product | `eh-smart-switch` | Stable | Catalog & marketing grouping |
| **Catalog** | Product Variant | `eh-smart-switch-1x` | Stable | Specific channel count & form factor |
| **Electronics**| Hardware Revision | `HW_1_0` (`hw_rev_switch_1x_1_0`) | **Immutable** | Physical PCB revision & schematic |
| **Materials** | BOM Specification | `bom_switch_1x_v1_0_0` (v1.0.0)| Immutable | Bill of components for a hardware rev |
| **Software** | Firmware Release | `v1.2.0-esp32c6-switch` | Immutable | Compiled binary targeting hardware |

---

## 3. Hardware Revision Lifecycle

Hardware revisions follow a controlled state machine to prevent unvalidated PCB designs from entering factory production:

```text
       ┌───────────┐
       │   DRAFT   │
       └─────┬─────┘
             │ Review & Prototyping
             ▼
       ┌───────────┐
 ┌────►│VALIDATION │◄────┐
 │     └─────┬─────┘     │
 │ Re-work   │ Validation passes
 │           ▼           │
 │     ┌───────────┐     │
 │     │ APPROVED  │─────┘
 │     └─────┬─────┘
 │           │ Production release
 │           ▼
 │     ┌───────────┐
 │     │  ACTIVE   │
 │     └─────┬─────┘
 │           │ Superseded by next rev
 │           ▼
 │     ┌───────────┐
 └─────┤DEPRECATED │
       └─────┬─────┘
             │ End of life
             ▼
       ┌───────────┐
       │  RETIRED  │ (Terminal)
       └───────────┘
```

### Transition Governance:
- **`DRAFT`:** Engineering prototype. Schematic and routing are in active modification.
- **`VALIDATION`:** Prototype boards assembled. Electrical rules check (ERC), design rules check (DRC), and thermal testing underway.
- **`APPROVED`:** Design verified and locked. Ready for pilot batch production.
- **`ACTIVE`:** Currently in volume factory manufacturing.
- **`DEPRECATED`:** Superseded by a newer revision (e.g. `HW_1_0` superseded by `HW_1_1`). Still supported for warranty and field repairs.
- **`RETIRED`:** Obsolete design. No longer manufactured or flashable with new hardware builds.

---

## 4. Bill of Materials (BOM) & Component Architecture

### 4.1 BOM Specifications (`bom_specifications`)
A BOM represents the complete component assembly for a specific hardware revision:
- Bound to an immutable `hardwareRevisionId`.
- Semantic versioning (`1.0.0`, `1.1.0`).
- Managed through lifecycle states: `DRAFT`, `ACTIVE`, `DEPRECATED`, `SUPERSEDED`.
- Tracks total unique component line items.

### 4.2 BOM Items (`bom_items`)
Each row represents a physical component line item:
- **`referenceDesignator`:** Circuit schematic designator (e.g. `U1`, `U2`, `MOV1`, `K1`, `C1`). Guaranteed unique within a BOM via `UNIQUE (bom_id, reference_designator)`.
- **`mpn`:** Manufacturer Part Number (e.g. `ESP32-C6-WROOM-1-N4`, `HLK-PM01`, `BL0942`, `HF32F-G`). Note: A given MPN can appear on multiple lines if used for distinct circuit functions with distinct reference designators.
- **`manufacturer`:** Approved component maker (e.g. `Espressif Systems`, `Hi-Link`, `Shanghai Belling`, `Hongfa`).
- **`componentCategory`:** Functional type (`IC`, `POWER`, `RELAY`, `PASSIVE`, `PROTECTION`, `DISCRETE`).
- **`footprint`:** KiCad physical package footprint (e.g. `Package_SO:SOP-14`, `Module:ESP32-C6-WROOM-1`).
- **`quantity`:** Positive integer count of components required per board (`quantity > 0` DB constraint).
- **`isDnf`:** Flag indicating "Do Not Fit" / "Do Not Populate" for optional assembly variants.

### 4.3 Component Substitutions (`component_substitutions`)
Factory component shortages often require approved secondary sources:
- Substitutions are linked to specific `bom_item_id`.
- Must have explicit `approvalStatus`: `PENDING`, `APPROVED`, `REJECTED`.
- Qualification notes record pin-compatibility and thermal/electrical verification.

---

## 5. Source of Truth & Traceability Boundaries

| Artifact | Authoritative Source of Truth | Storage Location |
| :--- | :--- | :--- |
| **Schematics & PCB Layout** | KiCad 7 / 8 Git Repository | `hardware/kicad/` |
| **Hardware Revision Metadata** | PostgreSQL Database (Migration 030) | `hardware_revisions` table |
| **Component Specifications** | PostgreSQL Database (Migration 030) | `bom_specifications`, `bom_items` |
| **Static Compatibility** | Static Product Definitions | `product-definitions/*/*/metadata.json` |
| **Firmware Platform Source** | Git Repository & ESP-IDF (Pinned v5.4.1) | `firmware/` (target ESP32-C6 / ESP32-S3) |

---

## 6. Forward Database Migration 030

Migration `030_hardware_bom_management.sql` establishes the schema for this domain:
- `hardware_revisions`: Core revision table with composite unique constraint `(product_variant_id, revision_code)`.
- `bom_specifications`: BOM headers with unique constraint `(hardware_revision_id, version)`.
- `bom_items`: Line items with foreign key cascade from BOM specification, strictly positive quantity (`quantity > 0`), and unique constraints on `(bom_id, item_index)` and `(bom_id, reference_designator)`.
- `component_substitutions`: Qualified alternate parts with status constraints.
- `product_variant_hardware_compatibility`: Relational mapping connecting product variants to supported hardware revisions.

### Rollback Safety (DOWN Migration)
The rollback migration `030_hardware_bom_management.down.sql` strictly avoids `CASCADE` to prevent accidental deletion of future dependent tables:
Tables are dropped in exact reverse dependency order:
1. `product_variant_hardware_compatibility` (references `product_variants` and `hardware_revisions`)
2. `component_substitutions` (references `bom_items`)
3. `bom_items` (references `bom_specifications`)
4. `bom_specifications` (references `hardware_revisions`)
5. `hardware_revisions` (references `product_variants`)

Historical migrations `001–029` remain strictly frozen and unmodified.

---

## 7. Product Compatibility & `supportedHardwareRevisions`

All 11 existing static product definitions in `product-definitions/` define `supportedHardwareRevisions`:
- **Smart Switch (4 variants):** `eh-smart-switch-1x`, `eh-smart-switch-2x`, `eh-smart-switch-3x`, `eh-smart-switch-4x` -> `["HW_1_0", "HW_1_1"]`
- **Smart Socket (3 variants):** `eh-smart-socket-1x`, `eh-smart-socket-2x`, `eh-smart-socket-3x` -> `["HW_1_0", "HW_1_1"]`
- **Smart Fan (1 variant):** `eh-smart-fan-1x` -> `["HW_1_0", "HW_1_1"]`
- **Smart Light (1 variant):** `eh-smart-light-cct` -> `["HW_1_0"]`
- **Smart Hub (1 variant):** `eh-smart-hub-v1` -> `["HW_1_0"]`
- **Sensor Node (1 variant):** `eh-sensor-node-v1` -> `["HW_1_0"]`

### Deterministic ID Derivation
For every product variant and revision code, the immutable hardware revision ID is derived deterministically:
```text
hw_${productVariantId}_${revisionCode.toLowerCase().replace(/[^a-z0-9]/g, '_')}
```
Example: `productVariantId: "eh-smart-switch-1x"`, `revisionCode: "HW_1_0"` maps to `hw_eh-smart-switch-1x_hw_1_0`.

---

## 8. Hardware & BOM API Endpoints

The domain routes are exposed under `/api/v1/hardware`:

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/hardware/revisions` | List hardware revisions with filters (`productVariantId`, `status`, `revisionCode`, `mcuFamily`). |
| `GET` | `/api/v1/hardware/revisions/:id` | Retrieve complete hardware revision specifications and pin map. |
| `GET` | `/api/v1/hardware/revisions/:id/bom` | Retrieve BOM specification and line items for a hardware revision. |
| `POST` | `/api/v1/hardware/revisions` | Register a new hardware revision (enforces unique revisionCode per variant). |
| `PATCH` | `/api/v1/hardware/revisions/:id/status`| Update hardware lifecycle status with state machine enforcement. |
| `POST` | `/api/v1/hardware/revisions/:id/bom` | Create a new BOM specification with items and validation. |
