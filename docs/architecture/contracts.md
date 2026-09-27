# EH Home — Contracts Architecture & Shared Boundary Guide

## 1. Overview & Canonical Authority

The EH Home platform coordinates multiple heterogeneous runtimes:
- **`apps/api`**: Fastify + TypeScript + Drizzle ORM service layer.
- **`apps/desktop`**: Tauri (Rust backend + React frontend) factory & engineering workstation.
- **`smart_home_application_v1`**: Flutter / Dart cross-platform customer mobile application.
- **ESP32 Firmware**: C / ESP-IDF microcontroller firmware.
- **Manufacturing Tooling**: Python flashing and calibration scripts (`tools/manufacturing/`).

To prevent architectural drift and subtle serialization divergence, **contracts are governed by a dual-representation system**:
1. **Canonical JSON Schemas** (`packages/contracts/*.schema.json`): The historical, language-agnostic wire-level authority for telemetry, state, commands, and device identity.
2. **TypeScript + Zod Domain Contracts** (`packages/contracts/src/`): The strictly typed runtime validation layer and static type generator for all modern TypeScript/Node services and tooling.

---

## 2. Package Organization

Contracts are organized under `packages/contracts/src/` by architectural domain:

| Domain | Files | Description |
|---|---|---|
| **`common`** | `common/index.ts` | UUID, ISO timestamps, SemVer, MAC address, hardware revision format, EH serial format, pagination, and API response envelope. |
| **`product`** | `product/index.ts` | ProductMaster, ProductVariant, ChannelDef, HardwareProfile, ConnectivityProfile, and catalog entry contracts. |
| **`hardware`** | `hardware/index.ts` | HardwareRevision, Bill of Materials (BOM) specifications, BOM items, and hardware compatibility. |
| **`firmware`** | `firmware/index.ts` | FirmwareRelease, FirmwareArtifactMetadata, OtaManifest, and firmware compatibility matrix. |
| **`device`** | `device/index.ts` | DeviceLifecycleState, DeviceIdentity, DeviceHardwareRecord, DeviceCredential, and DeviceState. |
| **`production`** | `production/index.ts` | ProductionBatch, BatchDeviceAssociation, QcMeasurement, and QcTestLog. |
| **`qr`** | `qr/index.ts` | OpaqueQrToken, QrUri, QrPayload, and QrCodeRecord preserving the `eh://p/v1?t=<TOKEN>` invariant. |
| **`packing`** | `packing/index.ts` | DeviceScanPayload, BoxScanPayload, DualScanVerificationRequest, and DualScanVerificationResult. |

---

## 3. TypeScript & Zod Strategy

All runtime contracts follow the **single-source-of-truth** pattern:

```typescript
// Define Zod runtime validation schema
export const ProductVariantSchema = z.object({
  variantId: z.string().regex(/^[a-z0-9_-]+$/),
  sku: z.string().min(1),
  channelCount: z.number().int().min(1).max(16),
  // ...
});

// Infer static TypeScript type directly from schema
export type ProductVariant = z.infer<typeof ProductVariantSchema>;
```

### Benefits:
- **No Type/Schema Drift**: Modifying the Zod schema automatically propagates type updates to all consumers (`apps/api`, `apps/desktop`).
- **Runtime Invariant Validation**: Deep refinements enforce critical business logic (e.g., verifying that a `MATCH_APPROVED` verification result cannot have `isMatch === false`, or that a QR payload cannot contain secret Wi-Fi credentials).

---

## 4. Architectural Invariants

### 4.1. QR Code Invariant
- **Format**: `eh://p/v1?t=<TOKEN>`
- **Token Properties**: High-entropy, opaque cryptographic string (16–64 characters, Base64URL or Hex).
- **Prohibited Data**:
  - NO Wi-Fi SSIDs or passwords.
  - NO private keys or factory encryption secrets.
  - NO plaintext device identifiers that compromise device anonymity prior to provisioning.
- **Enforcement**: RegEx matching and custom Zod refinements reject any URI containing sensitive query parameters.

### 4.2. Dual-Scan Verification Invariant (Packaging Station)
- Before a device can be boxed, both the physical device's laser-etched serial/QR and the outer retail packaging barcode/QR must be scanned.
- If the serial resolved from the box does not match the serial resolved from the device:
  - The verification returns status `MISMATCH_REJECTED`.
  - The packaging station UI locks out box sealing.
  - The contract strictly forbids emitting a `MATCH_APPROVED` result when `isMatch` is false.

### 4.3. Preserved Canonical Wire Semantics
- Field names (e.g., `deviceId`, `serialNumber`, `hardwareRevision`, `firmwareFamily`) match existing schemas exactly.
- All enums (e.g., `DeviceLifecycleState`, `DeviceCredentialState`, `ChannelState`) preserve existing wire values.
- Database migrations `001–029` remain untouched and frozen.

---

## 5. Versioning & Evolution Policy

Contracts adhere to semantic compatibility rules:

1. **Current Version**: `v1` (explicitly declared via `schemaVersion: 1`).
2. **Backward Compatibility Policy**:
   - Fields may only be added as **optional** or with safe **defaults**.
   - Existing fields must NEVER be renamed, deleted, or have their primitive types altered within `v1`.
3. **When a Major Version Bump (`v2`) is Required**:
   - Breaking wire changes (removing fields, changing JSON types, modifying MQTT topic hierarchies).
   - In the event of a `v2` introduction, dual-support adapters must be maintained until all firmware in the field and apps are migrated.
4. **Deprecation Process**:
   - Fields marked as deprecated remain present in Zod schemas for a minimum of two minor releases with `.optional()` annotations.

---

## 6. Testing & Validation

Contract integrity is verified by dual automated test suites:
- **Existing Schema Tests** (`packages/contracts/tests/contract-test.js`): Validates 287 JSON schema test cases across identity, authorization, energy, state, matter, trust, and recovery.
- **Zod Contract Tests** (`packages/contracts/tests/zod-contract.test.js`): Validates 36 domain-specific test cases covering valid acceptance, invalid rejection, opaque QR constraints, canonical compatibility, and dual-scan logic.

Run tests:
```bash
npx pnpm --filter @eh-home/contracts test
```
Compile and verify static types:
```bash
npx pnpm --filter @eh-home/contracts typecheck
```
