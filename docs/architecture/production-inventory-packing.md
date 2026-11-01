# EH Home — Production Inventory, Dual-Scan Verification & Packing Architecture (Part 11)

## 1. Overview & Objectives

Part 11 establishes the manufacturing floor inventory, dual-scan verification, packing, and immutable traceability architecture for EH Home devices.

This workflow guarantees the strict canonical relationship connecting:

$$\text{Product} \longrightarrow \text{Hardware Revision} \longrightarrow \text{Verified Firmware Artifact} \longrightarrow \text{Provisioned Device} \longrightarrow \text{QR Identity} \longrightarrow \text{Inventory State} \longrightarrow \text{Dual-Scan Verification} \longrightarrow \text{Packing Record} \longrightarrow \text{Traceability}$$

The system strictly prevents the wrong device, wrong label, wrong product, wrong firmware family, wrong hardware revision, or wrong carton assignment from entering a completed packing state.

```
+----------------------------------------------------------------------------------------------------+
|                                    MANUFACTURING BENCH & FLOOR                                     |
+----------------------------------------------------------------------------------------------------+
                                                  │
                                                  ▼
+───────────────────────────────────+                           +────────────────────────────────────+
|   SCAN A: Physical Unit Laser     |                           |   SCAN B: 2D Box / Label QR Code   |
|   (Barcode / Serial Number)       |                           |   (eh://p/v1?t=<OPAQUE_TOKEN>)     |
+───────────────────────────────────+                           +────────────────────────────────────+
                  │                                                               │
                  └───────────────────────────────┬───────────────────────────────┘
                                                  │
                                                  ▼
                                 +─────────────────────────────────+
                                 |  Dual-Scan Verification Engine  |
                                 |  (Fastify API & Contracts)      |
                                 +─────────────────────────────────+
                                                  │
                  ┌───────────────────────────────┴───────────────────────────────┐
                  │                                                               │
                  ▼                                                               ▼
        [ MATCH APPROVED (PASS) ]                                       [ REJECTED (MISMATCH) ]
                  │                                                               │
                  ▼                                                               ▼
    +───────────────────────────+                                   +───────────────────────────+
    | Carton Capacity Check     |                                   | Rejection Reason Display  |
    | (1 Unit / Retail Box)     |                                   | (PRODUCT_MISMATCH, etc.)  |
    +───────────────────────────+                                   +───────────────────────────+
                  │                                                               │
                  ▼                                                               ▼
    +───────────────────────────+                                   +───────────────────────────+
    | Atomic Packing Completion |                                   | Unit Quarantined / Alert  |
    | (status = 'PACKED')       |                                   +───────────────────────────+
    +───────────────────────────+
                  │
                  ▼
    +───────────────────────────+
    | Immutable Packaging Audit |
    | (Zero-Secret Traceability)|
    +───────────────────────────+
```

---

## 2. Inventory Domain & Deterministic State Machine

### State Machine Lifecycle

Manufacturing inventory units transition through deterministic states:

* `PROVISIONED`: Device has successfully completed bench flashing and provisioning (from Part 09).
* `VERIFIED`: Device serial and opaque QR label have passed dual-scan matching.
* `PACKING`: Device is verified and actively assigned to an open carton target.
* `PACKED`: Device is sealed in carton; immutable packaging record committed. Terminal state.
* `QUARANTINED`: Device or label failed inspection and is quarantined for engineering review.

### State Transition Matrix

| From State | Allowed Target States | Disallowed Transitions (Rejected) |
|---|---|---|
| `PROVISIONED` | `VERIFIED`, `PACKING`, `QUARANTINED` | `PACKED` (cannot bypass dual-scan) |
| `VERIFIED` | `PACKING`, `PACKED`, `QUARANTINED` | `PROVISIONED` (cannot un-verify) |
| `PACKING` | `PACKED`, `VERIFIED`, `QUARANTINED` | `PROVISIONED` |
| `PACKED` | *None* (Terminal) | `PROVISIONED`, `VERIFIED`, `PACKING` |
| `QUARANTINED` | `PROVISIONED`, `VERIFIED` | `PACKED` |

---

## 3. Device Traceability & Ingestion Flow

The inventory identity is anchored to the provisioned unit's single source of truth:
* `deviceId`: UUID v4
* `serialNumber`: Canonical serial (e.g. `EH-SW1X-2026W12-00001`)
* `productVariantId`: Canonical variant ID (e.g. `eh-smart-switch-1x`)
* `hardwareRevision`: Canonical revision code (`HW_1_0`, `HW_1_1`)
* `firmwareFamily`: Canonical platform identifier (`esp32c6-switch-platform`)
* `firmwareReleaseId`: Authoritative release record ID
* `traceId`: UUID v4 tying back to the manufacturing bench provisioning event

Devices with failed provisioning (`overallResult !== 'PASS'`) are strictly rejected at ingestion with `PROVISIONING_NOT_PASSED`.

---

## 4. Dual-Scan Verification Workflow

### Protocol & Format
* **SCAN A (Device Identity)**: Laser barcode scan of unit serial number or serial payload.
* **SCAN B (Label / Packaging QR)**: 2D barcode scan of printed label using canonical URI:
  `eh://p/v1?t=<OPAQUE_TOKEN>` (16–64 chars, regex `^[A-Za-z0-9_-]{16,64}$`).

### Validation Rules
The verification engine compares the resolved identities and rejects mismatches:

1. **Device Existence**: Must exist in inventory database (`DEVICE_NOT_FOUND`).
2. **Current State**: Must NOT already be packed (`DEVICE_ALREADY_PACKED`).
3. **QC/Provisioning State**: Must have passed QC verification (`PROVISIONING_NOT_PASSED`).
4. **QR Token Format**: Must match canonical opaque token schema (`INVALID_QR`).
5. **QR Token Association**: If QR token is pre-assigned to device, tokens must match (`QR_DEVICE_MISMATCH`).
6. **Product Variant Compatibility**: Must match canonical product variant (`PRODUCT_MISMATCH`).
7. **Hardware Revision Compatibility**: Must be valid for product variant (`HARDWARE_REVISION_MISMATCH`).
8. **Firmware Family Compatibility**: Must match canonical product firmware family (`FIRMWARE_FAMILY_MISMATCH`).
9. **Carton Assignment Compatibility**: Target carton variant and revision must match unit (`VARIANT_MISMATCH`).

---

## 5. Carton & Packing Identity Model

* **Carton Identifier**: `cartonId` (UUID/slug) and human-readable `cartonCode` (e.g. `CARTON-2026-SW1X-001`).
* **Capacity Rule**: 1 Unit / Retail Unit Box (or explicit typed multi-unit batch cartons).
* **Carton Status**: `OPEN` (accepts units) $\rightarrow$ `FULL` (target capacity reached) $\rightarrow$ `SEALED`.

---

## 6. Concurrency, Race-Safety & Idempotency

* **Database Level**: Atomic packing completions execute inside a database transaction (`packDeviceAtomic`).
* **Conditional Lock**: Uses PostgreSQL `WHERE status IN ('VERIFIED', 'PACKING')` update constraints to ensure that if two operator stations attempt to complete packing on the same unit concurrently, exactly one succeeds and the second receives a deterministic `DEVICE_ALREADY_PACKED` error.
* **Idempotency**: Repeated identical dual-scan requests return the existing verification result without creating duplicate records or altering carton counts.

---

## 7. Packaging Audit Trail & Zero-Secret Guarantee

Every successful packing operation creates an immutable row in `packaging_records`:
* `id`: Unique record ID (`pack_<serial>_<timestamp>`)
* `traceId`: Bench provisioning trace ID
* `deviceId`, `serialNumber`, `productVariantId`, `hardwareRevision`, `firmwareFamily`, `firmwareVersion`
* `cartonId`, `verificationId`, `stationId`, `operatorUserId`, `packedAt`

### Zero-Secret Invariant
The packaging record and all inventory APIs strictly enforce zero secrets:
* No commissioning secrets
* No Wi-Fi passwords / SSIDs
* No private keys (RSA/ECC)
* No CA or intermediate keys
Any object violating this schema throws an immediate security assertion.

---

## 8. Desktop UI Operator Workflow

1. Operator navigates to **Packing & Dual-Scan** tab on the Tauri Desktop app.
2. Station ID is auto-assigned (`STATION-PACK-01`) and scanner listener is active (`LISTENING`).
3. Operator scans unit serial (Scan A).
4. Operator scans product packaging QR label (Scan B).
5. UI displays instantaneous visual feedback:
   * **GREEN BANNER**: PASS — `DUAL-SCAN VERIFIED`, details matrix shown, "Confirm & Pack Unit" button enabled.
   * **RED BANNER**: REJECTED — mismatch reason clearly visible (e.g. `FIRMWARE_FAMILY_MISMATCH`).
6. Operator clicks **Confirm & Pack Unit**:
   * Unit is marked `PACKED` in database.
   * Carton capacity counter increments.
   * Immutable audit record appears in Recent Packing Trail.
   * Scan inputs auto-reset for the next unit.

---

## 9. Physical Scanner Smoke-Test Procedure

When connecting a physical 1D/2D USB HID Barcode Scanner:
1. Connect scanner via USB port.
2. Verify scanner status indicator reads **LISTENING**.
3. Scan a sample 1D Code-128 serial barcode $\rightarrow$ Scan A field populates automatically.
4. Scan a sample 2D DataMatrix/QR code containing `eh://p/v1?t=...` $\rightarrow$ Scan B field populates.
5. Verification runs automatically.
