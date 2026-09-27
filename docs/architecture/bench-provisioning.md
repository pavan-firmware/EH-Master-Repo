# EH Home Architecture — ESP32 Device & Bench Provisioner (Part 09)

## 1. Executive Summary & Objective

Part 09 establishes the production-grade bench provisioning workflow for ESP32 devices within the EH Home desktop application (`apps/desktop`), integrating with existing Python manufacturing tools (`tools/manufacturing/flash_device.py`, `factory_provisioner.py`, `ca_manager.py`) while preserving the existing PKI/CA system, product definitions, firmware domain models, and frozen database migrations 001–031.

```text
┌─────────────────────────────────────────────────────────────┐
│                 Desktop UI (React / Vite)                   │
│   - Step 1: Serial Device Discovery                         │
│   - Step 2: ESP32 Chip Identification                       │
│   - Step 3: Product Variant & HW Revision Selection         │
│   - Step 4: 6-Gate Firmware Artifact & Integrity Validation │
│   - Step 5: Controlled Flashing & Provisioning Trigger      │
└──────────────────────────────┬──────────────────────────────┘
                               │ Typed Tauri Invocation
                               ▼
┌─────────────────────────────────────────────────────────────┐
│            Tauri v2 Native Layer (src-tauri)                │
│   - Strict parameter validation (regex port, allowlist SKU) │
│   - ZERO arbitrary shell execution                          │
│   - Explicit argument vector creation                       │
└──────────────────────────────┬──────────────────────────────┘
                               │ Controlled Process Spawn
                               ▼
┌─────────────────────────────────────────────────────────────┐
│       Python Manufacturing Sidecar (tools/manufacturing/)   │
│   - flash_device.py: detect, flash, verify                  │
│   - factory_provisioner.py: UUID v4, serial, mTLS cert      │
│   - ca_manager.py: Root CA -> Device CA -> Client Cert      │
│   - Writes NVS fact_v2 partition at 0x12000                 │
└──────────────────────────────┬──────────────────────────────┘
                               │ Post-Flash Verification
                               ▼
┌─────────────────────────────────────────────────────────────┐
│       Structured Traceability & Audit Record                │
│   - Device ID, Serial Number, TLS Cert Fingerprint (SHA-256)│
│   - Zero secrets leaked (Keys/Secrets isolated in NVS/PKI)  │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Core Architectural Decisions

1. **Python Flasher Sidecar Boundary**:
   - The established, battle-tested Python toolchain (`flash_device.py`) is preserved as a controlled sidecar. It is NOT rewritten in Rust in this phase.
   - The desktop frontend (`apps/desktop`) communicates with the sidecar through strictly allowlisted Tauri commands.

2. **Security & Shell Isolation**:
   - Arbitrary shell execution (`cmd.exe /c`, `sh -c`, `execute_shell`) is strictly prohibited and architecturally blocked.
   - The Tauri commands validate all arguments with strict regexes:
     - Serial Port: `^COM[1-9][0-9]?$` (Windows) or `^/dev/tty(USB|ACM|S)[0-9]+$` / `^/dev/cu\.[a-zA-Z0-9_-]+$` (Unix/macOS). Characters such as `;`, `&`, `|`, `` ` ``, `$`, spaces, and quotes are immediately rejected.
     - Product Variant: Checked against the canonical allowlist of products (`eh-smart-switch-1x` through `4x`, `eh-smart-socket-1x` through `3x`, `eh-smart-light-cct`, `eh-sensor-node-v1`, `eh-smart-switch-dev`, `eh-smart-socket-dev`).
     - Binary Paths: Must end with `.bin` or `.csv` and cannot begin with `-` or contain shell injection characters.

3. **Secret Material Boundary & Zero Leakage**:
   - The 256-bit commissioning secret and the private key (`.key`) are generated locally within the secure manufacturing boundary (`tools/manufacturing/.local_pki` and the device's internal `fact_v2` NVS binary partition).
   - Neither the private key nor the commissioning secret is ever returned to the renderer, displayed in desktop UI consoles, or recorded in public audit/traceability records.
   - Only the public `deviceId`, `serialNumber`, and `tlsCertFingerprint` (SHA-256 hash) are exposed for tracking.

4. **Zero Migration Invariance**:
   - Database migrations 001–031 remain frozen and untouched.
   - Existing schema tables (`devices`, `device_credentials`, `device_credential_lifecycle`, `device_provisioning_records`) fully support device identities, credential states, and bench provisioning records via `evidenceJson`. Therefore, no migration 032 is necessary.

---

## 3. Canonical 8-Gate Firmware Validation Model

Before any device can be flashed on the manufacturing bench, it must satisfy all 8 canonical verification gates across both the TypeScript contracts layer and the privileged Tauri native boundary:

| Canonical Gate | Name | Validation Rule | Error on Failure |
| :---: | :--- | :--- | :--- |
| **Gate 1** | **Binary & Manifest Integrity** | Safe binary file path, valid serial port format, manifest presence on disk, and valid JSON syntax. | `ARTIFACT_NOT_FOUND` / `SECURITY_VALIDATION_FAILED` |
| **Gate 2** | **Cryptographic SHA-256 Digest** | Computed file SHA-256 matches manifest `artifacts.APP_BIN.sha256` byte-for-byte. | `ARTIFACT_HASH_MISMATCH` |
| **Gate 3** | **Firmware Family Release Eligibility** | Family must have `releaseEligibility === 'PRODUCTION'` (`esp32c6-switch-platform` or `esp32c6-socket-platform`). | `ARTIFACT_NOT_RELEASE_ELIGIBLE` |
| **Gate 4** | **Artifact Release Lifecycle State** | Artifact `lifecycleStatus` must be `RELEASED` (or legacy `PUBLISHED`). Rejects `DRAFT`, `BUILDING`, `VALIDATION`, `APPROVED`, `DEPRECATED`, `RETIRED`, `REVOKED`. | `ARTIFACT_LIFECYCLE_NOT_RELEASED` |
| **Gate 5** | **Firmware Family Identity Match** | Requested firmware family must strictly match `manifest.firmwareFamily`. | `FAMILY_MISMATCH` |
| **Gate 6** | **Product Variant Compatibility** | Target `productVariantId` must belong to `FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP[family]`. | `FAMILY_MISMATCH` |
| **Gate 7** | **Target MCU Architecture Match** | Connected device silicon target MCU must match `manifest.targetMcu` (e.g. `esp32-c6`). | `TARGET_MISMATCH` |
| **Gate 8** | **Hardware Revision Certification** | Target `hardwareRevision` must be listed in `manifest.compatibleHardwareRevisions`. | `HARDWARE_INCOMPATIBLE` |

### Authoritative Canonical Firmware Lifecycle (PART 07 Model)

```text
DRAFT
  ↓
BUILDING
  ↓
VALIDATION
  ↓
APPROVED (Release candidate approved, unreleased)
  ↓
RELEASED (Authorized for production bench flashing)
  ↓
DEPRECATED (Superseded; blocked from new production flashing)
  ↓
RETIRED (End-of-life; blocked from production flashing)

[Emergency / Security Revocation from any state]:
  ↓
REVOKED (Terminal; permanently invalid & blocked from flashing)
```

Only artifacts in the **`RELEASED`** (or legacy fleet **`PUBLISHED`**) state are authorized for manufacturing bench flashing. Artifacts in `DRAFT`, `BUILDING`, `VALIDATION`, `APPROVED`, `DEPRECATED`, `RETIRED`, or `REVOKED` states are strictly rejected at the privileged native boundary before any sidecar process can be launched.

---

## 4. Provisioning Lifecycle State Machine

The bench provisioner coordinates through an explicit 9-state machine:

```text
NO_DEVICE_DETECTED
        ↓ (Serial port connected)
 DEVICE_DETECTED
        ↓ (Read chip family, MAC, target)
DEVICE_IDENTIFIED
        ↓ (Pass 6-Gate Artifact Validation)
DEVICE_READY_FOR_FLASHING
        ↓ (Operator confirms Flash)
     FLASHING (CONNECTING -> ERASING -> WRITING)
        ↓ (Post-flash serial banner capture)
   VERIFICATION
        ↓ (Inject mTLS cert & fact_v2 NVS)
   PROVISIONING
        ↓ (All checks pass)
    COMPLETED
        ↓ (Any failure during sequence)
      FAILED (Emits typed ProvisioningErrorCode)
```

### Typed Error Codes
- `DEVICE_NOT_FOUND`: Target COM port no longer exists.
- `DEVICE_BUSY`: Port locked by another process (e.g. serial monitor).
- `DEVICE_DISCONNECTED`: Device removed during handshake or flashing.
- `DEVICE_IDENTIFICATION_FAILED`: esptool / bootloader communication timeout.
- `ARTIFACT_NOT_FOUND`: Application binary or manifest missing on disk.
- `ARTIFACT_HASH_MISMATCH`: File SHA-256 does not match manifest.
- `FAMILY_MISMATCH`: Firmware family does not support the product variant.
- `TARGET_MISMATCH`: Connected MCU does not match binary target.
- `HARDWARE_INCOMPATIBLE`: Hardware revision not certified for this build.
- `ARTIFACT_NOT_RELEASE_ELIGIBLE`: Planned or prototype family selected for production.
- `FLASH_FAILED`: esptool packet write timeout or sync error.
- `FLASH_VERIFY_FAILED`: Boot banner validation or MD5 checksum mismatch.
- `PROVISIONING_FAILED`: NVS partition creation or cert generation error.
- `SECURITY_VALIDATION_FAILED`: Command parameter violated regex or allowlist.

---

## 5. Structured Traceability Record

Upon successful completion of the provisioning workflow, a `BenchProvisioningTraceabilityRecord` is produced:

```json
{
  "schemaVersion": 1,
  "traceId": "0194fe23-7a1b-7890-a123-456789abcd99",
  "deviceId": "0194fe23-7a1b-7890-a123-456789abcdef",
  "serialNumber": "EH-SW3X-2026W39-00001",
  "productVariantId": "eh-smart-switch-3x",
  "hardwareRevision": "HW_1_0",
  "firmwareFamily": "esp32c6-switch-platform",
  "firmwareReleaseId": "rel-1-0-0-prod",
  "firmwareVersion": "1.0.0",
  "targetMcu": "esp32-c6",
  "idfTarget": "esp32c6",
  "artifactSha256": "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90",
  "tlsCertFingerprint": "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
  "port": "COM3",
  "flashStatus": "PASS",
  "verificationStatus": "PASS",
  "provisioningStatus": "PASS",
  "provisionedAt": "2026-03-01T15:30:00.000Z",
  "durationMs": 4200
}
```

---

## 6. Privileged Native Boundary Security & Enforcement

The desktop application does NOT rely exclusively on the React / TypeScript layer for security:
- In `apps/desktop/src-tauri/src/commands.rs`, `validate_flash_request_native` independently parses the manifest from disk, verifies the true cryptographic SHA-256 of the binary payload using a pure FIPS 180-4 SHA-256 routine, checks the family allowlist, checks the product variant mapping, checks the target MCU, and checks the hardware revision.
- If any check fails, `flash_device_sidecar` immediately returns a typed error response with `success: false` and **never invokes `Command::new("python")`**.
- Deterministic tests in `apps/desktop/tests/native-boundary-security.test.js` (15 tests) prove that bypassing the React frontend cannot trigger flashing with invalid or mismatched binaries.

---

## 7. Authoritative Manufacturing Provisioning Execution Path

The complete bench execution pipeline flows as follows:

1. **Silicon Identification**: `flash_device.py detect --port <PORT> --json` invokes `detect_connected_chip()` to query MAC, chip type (`esp32c6`), and flash size.
2. **Privileged Native Validation**: Tauri native handler validates port regex, safe binary paths, manifest existence, binary SHA-256 match, family match, variant compatibility, MCU match, and revision compatibility.
3. **Flashing & Factory Provisioning**:
   - `flash_device.py flash` invokes `FactoryNVSManager.generate_factory_identity()`.
   - `FactoryNVSManager` delegates to `FactoryProvisioner.provision_device()` (`tools/manufacturing/factory_provisioner.py`).
   - `FactoryProvisioner` invokes `ManufacturingCAManager.issue_device_certificate(device_id)` (`tools/manufacturing/ca_manager.py`) to sign the device mTLS certificate using the Device Intermediate CA (`.local_pki/intermediate/device_ca.key`).
   - A 256-bit cryptographic commissioning secret and canonical serial number (`EH-<PREFIX>-<YEAR>W<WEEK>-<SEQ>`) are generated.
   - NVS CSV partition is created and compiled into `fact_v2.bin` via `nvs_partition_gen.py`.
   - `esptool.py` flashes bootloader, partition table, `fact_v2.bin` at offset `0x12000`, and application binary.
4. **Post-Flash Verification**: Device resets and `PostFlashVerifier` captures boot logs to confirm successful startup and identity emission.
5. **Traceability Result**: Public identity metadata (`deviceId`, `serialNumber`, `tlsCertFingerprint`) is returned in structured JSON. Private keys and commissioning secrets are never leaked to the renderer.

---

## 8. Traceability Persistence Status

- In **Part 09**, the bench provisioning traceability record is an **in-memory and local desktop JSON artifact** exported by the desktop provisioner workstation.
- **Database Schema Compatibility**: The existing PostgreSQL database schema (`devices`, `device_credentials`, `device_credential_lifecycle`, `device_provisioning_records`) already contains the exact columns and JSONB `evidenceJson` structures necessary to persist this record without schema changes or new migrations.
- **Factory Isolation Rationale**: Standalone bench workstations on the factory floor often operate offline without a direct network connection to the cloud/production database. Local JSON traceability generation is therefore strictly required for manufacturing resilience before batch synchronization in later stages.

---

## 9. Python Sidecar Deployment Limitation

- **Host Runtime Dependency**: The current Part 09 desktop implementation executes `Command::new("python")` with `tools/manufacturing/flash_device.py`.
- **Operator Requirement**: The manufacturing operator workstation must have Python 3 (3.10–3.14) installed on the system PATH along with the dependencies listed in `tools/manufacturing/requirements.txt` (`cryptography`, `esptool`, `pyserial`).
- The desktop application is therefore **not fully self-contained** regarding its flashing toolchain in Part 09. A packaged PyInstaller sidecar binary or Rust-native flasher will be evaluated in subsequent production distribution phases.

---

## 10. Testing Strategy & Verification Summary

1. **Hardware Independence**:
   - The automated CI/test suites do NOT require a connected physical ESP32.
   - `MockSerialService` and `MockFlasherService` provide deterministic simulation of port status, ESP32-C6 identification, multi-stage flashing, verification pass/fail, and traceability generation.
2. **Native Boundary Security Tests**:
   - `apps/desktop/tests/native-boundary-security.test.js` (15 tests) verifies that all 6 validation gates reject invalid requests before any sidecar execution.
3. **Desktop Foundation & Workflow Tests**:
   - `apps/desktop/tests/desktop.test.js` (9 tests) validates frontend bundle, security CSP, and native abstractions.
   - `apps/desktop/tests/bench-provisioner.test.js` (21 tests) validates serial discovery, device identification, 6-gate validation, argument security, error handling, and secret redaction.
   - Total Desktop Tests: **45/45 passed**.
4. **Shared Contracts Tests**:
   - `packages/contracts/tests/contracts.test.js` (287 tests) + `zod-contract.test.js` (44 tests) = **331/331 passed**.
5. **Database Schema Tests**:
   - `packages/db-schema/tests/` (27 tests) = **27/27 passed**.
6. **Canonical API Tests**:
   - `apps/api/tests/` (116 tests) = **116/116 passed**.
7. **Manufacturing Sidecar Tests**:
   - `tools/manufacturing/test_manufacturing.py` (5 tests) + `tests/test_flash_device.py` (13 tests) = **18/18 passed**.
8. **Monorepo Pre-Push Validator**:
   - `scripts/validate-repo.js` = **64/64 suites passed**.

