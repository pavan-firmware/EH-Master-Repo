# EH Home — Firmware, Git & Binary Management Architecture

## 1. Overview & Objectives

The Firmware, Git & Binary Management domain (Part 07) establishes the traceable software engineering and release lifecycle foundation for EH Home smart-home devices.

It bridges:
1. Physical electronics (**Hardware Revisions** from Part 06)
2. Commercial products (**Product Variants** from Part 05)
3. Source control (**Git Commit Identity & Repository References**)
4. Compilation and artifacts (**Build Metadata, Binary Images & SHA-256 Digests**)
5. Runtime delivery (**Existing OTA Manifest & Device Fleet Management**)

```text
┌────────────────────────────────────────────────────────┐
│                    Product Variant                     │
│               (e.g., eh-smart-switch-1x)               │
└──────────────────────────┬─────────────────────────────┘
                           │ references firmwareFamily
                           ▼
┌────────────────────────────────────────────────────────┐
│                    Firmware Family                     │
│             (e.g., esp32c6-switch-platform)            │
└──────────────────────────┬─────────────────────────────┘
                           │ 1 : N
                           ▼
┌────────────────────────────────────────────────────────┐
│                    Firmware Release                    │
│                 (e.g., v1.4.0, RELEASED)               │
└────────────┬─────────────────────────────┬─────────────┘
             │ 1 : N                       │ 1 : N
             ▼                             ▼
┌──────────────────────────┐       ┌─────────────────────────────────────┐
│      Firmware Build      │       │   Firmware Hardware Compatibility   │
│  (Git Commit, IDF 5.4.1) │       │   (e.g., HW_1_0, HW_1_1 verified)   │
└────────────┬─────────────┘       └──────────────────┬──────────────────┘
             │ 1 : N                                  │
             ▼                                        ▼
┌──────────────────────────┐               ┌───────────────────────┐
│    Firmware Artifact     │               │   Hardware Revision   │
│ (APP_BIN, BOOTLOADER,    │               │ (hw_rev_switch_1x_1_0)│
│  PARTITION, SHA-256)     │               └───────────────────────┘
└──────────────────────────┘
```

---

## 2. Critical Source-of-Truth Boundaries

To ensure absolute traceability and avoid conflation, EH Home enforces strict storage boundaries:

| Concern | Authoritative Source of Truth | Storage Mechanism | Non-Negotiable Invariants |
| :--- | :--- | :--- | :--- |
| **Source Code** | Git Version Control | Git Repository (`firmware/`) | Pinned commit SHAs; branches are mutable pointers and never permanent IDs |
| **Release Metadata** | PostgreSQL (Migrations 011 + 031) | `firmware_releases`, `firmware_builds` | Release semver, lifecycle status, commit link, toolchain info |
| **Binary Artifacts** | Object Storage (Abstracted) | Storage Key Reference (`s3Key`/`storagePath`) | **No binary blobs in PostgreSQL**; deterministic SHA-256 checksums |
| **Runtime Execution**| ESP32 Hardware Target | ESP-IDF 5.4.1 Flash Partitions | Executable app on device boot |

---

## 3. Firmware Platform Lineages (Families)

EH Home defines 6 canonical firmware platform lineages corresponding to device categories:

| Firmware Family ID | Display Name | Target MCU | Pinned IDF | Target Products |
| :--- | :--- | :--- | :--- | :--- |
| `esp32c6-switch-platform` | ESP32-C6 Smart Switch Platform | `esp32-c6` | `v5.4.1` | `eh-smart-switch-1x`, `2x`, `3x`, `4x` |
| `esp32c6-socket-platform` | ESP32-C6 Smart Socket Platform | `esp32-c6` | `v5.4.1` | `eh-smart-socket-1x`, `2x`, `3x` |
| `esp32c6-fan-platform` | ESP32-C6 Smart Fan Controller Platform | `esp32-c6` | `v5.4.1` | `eh-smart-fan-1x` |
| `esp32c6-light-platform` | ESP32-C6 Smart Lighting Platform | `esp32-c6` | `v5.4.1` | `eh-smart-light-cct` |
| `esp32s3-hub-platform` | ESP32-S3 Smart Controller / Hub Platform | `esp32-s3` | `v5.4.1` | `eh-smart-hub-v1` |
| `esp32c6-sensor-platform` | ESP32-C6 Sensor Node Platform | `esp32-c6` | `v5.4.1` | `eh-sensor-node-v1` |

---

## 4. Git Traceability & Source Identity

Every build and release is permanently anchored to an immutable Git commit SHA:

```text
Firmware Release (v1.4.0)
     ↓
Firmware Build (bld_1740000000_a1b2c3d)
     ↓
Git Commit SHA (40-hex: a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2)
     ↓
Git Tag (v1.4.0) & Branch ('main')
     ↓
Toolchain Environment (ESP-IDF 5.4.1, compiler xtensa-esp-elf-14.2.0)
```

- **Branch names are advisory:** Release identity never relies solely on a mutable branch name.
- **Commit SHA verification:** The database enforces format validation `git_commit_sha ~ '^[0-9a-fA-F]{40}$'`.
- **Answering the operator question:** Given any production device running version `v1.4.0`, an engineer can query the API to determine the exact Git commit SHA and build configuration that produced the running image.

---

## 5. Binary Artifacts & SHA-256 Integrity

### Multi-Artifact Composition
An ESP32-C6 compilation produces multiple binary and debug artifacts:
1. `APP_BIN`: Main application binary flashed to partition `ota_0` or `ota_1`.
2. `BOOTLOADER`: Second-stage bootloader binary.
3. `PARTITION_TABLE`: Binary partition table mapping flash memory layout.
4. `ELF`: Executable and Linkable Format debug binary with full debug symbols.
5. `MAP`: Linker memory map detailing RAM/Flash section allocations.
6. `FACTORY_NVS`: Binary NVS partition containing manufacturing credentials and provisioning keys.

### Integrity & Checksum Verification
- Every artifact row records:
  - `file_size_bytes`: Strictly positive integer (`file_size_bytes > 0`).
  - `sha256`: 64-character hexadecimal SHA-256 digest (`sha256 ~ '^[0-9a-fA-F]{64}$'`).
- The storage abstraction (`IFirmwareArtifactStore`) performs cryptographic SHA-256 hashing directly on the raw binary buffer:
  ```typescript
  const computed = crypto.createHash('sha256').update(data).digest('hex');
  if (computed.toLowerCase() !== expectedSha256.toLowerCase()) {
    throw new Error('Artifact integrity violation: SHA-256 mismatch');
  }
  ```

---

## 6. Cryptographic Signing Boundary

EH Home distinguishes between an **artifact digest** and an **artifact cryptographic signature**:
- **Artifact SHA-256:** Computed content hash representing file integrity.
- **Ed25519 Signature:** Cryptographic signature generated by the EH Home Manufacturing PKI private signing key.
- **Zero Secret Exposure:**
  - Private keys are **never stored** in PostgreSQL, Git, source code, or API responses.
  - Verification uses public keys embedded in the bootloader or verified by OTA services.
  - The database records only the resulting signature string (e.g. 128-hex Ed25519 signature) and verification status.

---

## 7. Storage Abstraction (`IFirmwareArtifactStore`)

Binary files are stored externally, not in the transactional database. Part 07 establishes the interface boundary:

```typescript
export interface IFirmwareArtifactStore {
  storeArtifact(key: string, data: Buffer, contentType?: string): Promise<{ storagePath: string; sha256: string; size: number }>;
  getArtifactUrl(key: string): Promise<string>;
  verifyIntegrity(data: Buffer, expectedSha256: string): boolean;
}
```

- **Default Implementation:** `InMemoryArtifactStore` for tests and local development.
- **Future Production Implementation:** S3/MinIO compatible object store (to be wired in its dedicated infrastructure phase).

---

## 8. Release Lifecycle & Immutability

### Finite State Machine
```text
┌───────────┐
│   DRAFT   │
└─────┬─────┘
      │ Build initiated
      ▼
┌───────────┐
│ BUILDING  │◄────┐
└─────┬─────┘     │ Re-build
      │ Compilation complete
      ▼           │
┌───────────┐     │
│VALIDATION │─────┘
└─────┬─────┘
      │ Testing passes
      ▼
┌───────────┐
│ APPROVED  │ (Locked: Builds/artifacts become immutable)
└─────┬─────┴─────────────────────────┐
      │ Rollout approved               │
      ▼                                │
┌───────────┐                          │ Emergency
│ RELEASED  │ (Active in OTA)          │ Security
└─────┬─────┴────────────┐             │ Revocation
      │ Replaced by      │             │
      │ newer semver     │             │
      ▼                  ▼             │
┌───────────┐     ┌───────────┐        │
│DEPRECATED │────►│  REVOKED  │◄───────┘
└─────┬─────┘     │(Terminal) │
      │ EOL       └─────▲─────┘
      ▼                 │
┌───────────┐           │
│  RETIRED  │───────────┘
│(Terminal) │ (Post-retirement CVE revocation)
└───────────┘
```

### Semantic Distinction: `RETIRED` vs. `REVOKED`

| Aspect | `RETIRED` | `REVOKED` |
| :--- | :--- | :--- |
| **Domain Trigger** | Natural end-of-life, hardware obsolescence, phased-out model | Emergency security disclosure (CVE), compromised cryptographic signing key, catastrophic bricking defect |
| **Operational Impact** | No longer manufactured or actively updated. Existing fielded devices may continue operating. | Immediately blocked by OTA eligibility and rollout engines. No devices may download, install, or rollback to this release. |
| **Valid Transitions In** | `DRAFT`, `BUILDING`, `VALIDATION`, `APPROVED`, `RELEASED`, `DEPRECATED` | `APPROVED`, `RELEASED`, `DEPRECATED`, `RETIRED` |
| **Terminal Property** | Terminal (can only transition to `REVOKED` if subsequent critical vulnerability is discovered) | **Strictly Terminal** (`REVOKED: []`). A revoked release can never be reactivated, re-published, or reverted. |
| **Relationship** | Planned lifecycle phase-out | Emergency administrative kill-switch |

### Immutability Rules:
1. Once a release transitions to `APPROVED` or `RELEASED`, its identity (`firmwareFamily`, `version`, `productVariantId`, `gitCommitSha`) is permanently locked.
2. New builds or artifacts cannot be attached to locked or terminal releases (`APPROVED`, `RELEASED`, `DEPRECATED`, `RETIRED`, `REVOKED`). Any code fixes require generating a new semantic version (e.g. `1.0.1`).
3. Backward transitions from `RELEASED` to `DRAFT` or `BUILDING` are rejected with `INVALID_LIFECYCLE_TRANSITION`.
4. Transitions out of `REVOKED` to any other state are strictly rejected (`REVOKED` is permanent and irreversible).
5. Compatibility definitions cannot be added or mutated for releases in `RETIRED` or `REVOKED` status.

---

## 9. Firmware-to-Hardware Compatibility Matrix

A release is validated against specific physical hardware revisions:
```text
Firmware Release (v1.0.0, esp32c6-switch-platform)
     ↓
firmware_hardware_compatibility
     ↓
Hardware Revision: hw_rev_switch_1x_1_0 (Rev 1.0) -> Verified: true
Hardware Revision: hw_rev_switch_1x_1_1 (Rev 1.1) -> Verified: true
```

- When manufacturing flashes a device or an OTA rollout evaluates target devices, compatibility checks prevent flashing firmware onto an incompatible hardware revision.

---

## 10. Forward Database Migration 031

Migration `031_firmware_git_binary_management.sql` establishes 4 new engineering tables while reusing existing `firmware_releases` (from Migration 011):

1. `firmware_families`: Lineage metadata and MCU targets.
2. `firmware_builds`: Build execution records, Git commit SHA, branch, tag, and toolchain info.
3. `firmware_artifacts`: Multi-artifact binaries with unique `(build_id, artifact_type)` and SHA-256 checks.
4. `firmware_hardware_compatibility`: Mapping connecting firmware releases to hardware revisions.

### Rollback Reversibility (DOWN Migration)
Tables are dropped in strict reverse-dependency order without `CASCADE`:
```sql
DROP TABLE IF EXISTS firmware_hardware_compatibility;
DROP TABLE IF EXISTS firmware_artifacts;
DROP TABLE IF EXISTS firmware_builds;
DROP TABLE IF EXISTS firmware_families;
```

---

## 11. Boundary with PART 08 (Automated Build, Test & Release)

Part 07 strictly establishes the **data model, API, Git traceability metadata, and storage abstraction**.
Part 08 will introduce:
- Automated compilation via `idf.py build`
- CI/CD build runners
- Packaging pipeline
- Automated binary signing via manufacturing PKI
- Upload to MinIO/S3 object storage
