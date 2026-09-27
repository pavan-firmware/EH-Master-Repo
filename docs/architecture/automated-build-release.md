# EH Home — Automated Build, Test & Release Architecture (Part 08)

## 1. Overview & Objective

This document establishes the architecture for automated firmware building, testing, artifact discovery, cryptographic integrity verification, target architecture consistency, and release validation for the EH Home platform.

The system connects source code to verified release artifacts following this deterministic pipeline:

```text
Git Commit SHA (40-char Hex)
      ↓
Reproducible Multi-Target Build (ESP-IDF 5.4.1)
      ↓
Firmware Tests (Host & Hardware-Integration Suites)
      ↓
Binary Artifact Discovery (APP, BOOTLOADER, PARTITION, ELF, MAP)
      ↓
Cryptographic SHA-256 Digest Computation (Byte-level)
      ↓
Target Architecture & Toolchain Consistency Validation
      ↓
Artifact Manifest Generation (UUID Build ID + Full Commit SHA)
      ↓
Hardware Revision & Product Variant Compatibility Gate
      ↓
Automated Release-Readiness Gate Evaluation (7 Explicit Gates)
      ↓
Release Registration / Lifecycle Transition
```

---

## 2. Target Architecture Reconciliation & Toolchain Mapping

### 2.1 Multi-Target Architecture
The EH Home firmware repository supports multiple silicon targets within a unified codebase ([firmware/platforms/esp32/smart-switch-app](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/firmware/platforms/esp32/smart-switch-app)):

1. **Development & Bench Testing Target (`esp32`)**:
   - **Hardware**: ESP32 DevKit / ESP32-WROOM-32 (ESP32-D0WD dual-core).
   - **Architecture**: Xtensa 32-bit LX6.
   - **Compiler**: `xtensa-esp-elf-gcc (14.2.0)`.
   - **Pin Mapping**: GPIO 18, 19, 21 for relays; GPIO 4, 5, 13 for switches (conditioned by `#if defined(CONFIG_IDF_TARGET_ESP32)`).
   - **Role**: Prototyping, bench validation, and CI emulation.

2. **Production Smart Switch / Socket / Fan / Light Target (`esp32-c6`)**:
   - **Hardware**: ESP32-C6 (Wi-Fi 6, 802.15.4 / Thread / BLE 5.0).
   - **Architecture**: RISC-V 32-bit (RV32IMAC).
   - **Compiler**: `riscv32-esp-elf-gcc (14.2.0)`.
   - **Pin Mapping**: GPIO 18, 19, 20 for relays; GPIO 4, 5, 6 for switches (conditioned by `#elif defined(CONFIG_IDF_TARGET_ESP32C6)`).
   - **Canonical Families**: `esp32c6-switch-platform`, `esp32c6-socket-platform`, `esp32c6-fan-platform`, `esp32c6-light-platform`, `esp32c6-sensor-platform`.
   - **Role**: Mass-production smart device line.

3. **Production Smart Hub Target (`esp32-s3`)**:
   - **Hardware**: ESP32-S3 (Dual-core LX7, AI/Vector acceleration, PSRAM).
   - **Architecture**: Xtensa 32-bit LX7.
   - **Compiler**: `xtensa-esp-elf-gcc (14.2.0)`.
   - **Canonical Family**: `esp32s3-hub-platform`.
   - **Role**: Edge hub, Matter controller, and local gateway.

### 2.2 Canonical Product Inventory Reconciliation (Authoritative `product-definitions/`)

The repository contains exactly **11 canonical product definitions** across **6 product family directories** under `product-definitions/`:

| Product Variant ID (`productVariantId`) | Product Family Directory | Firmware Family (`firmwareFamily`) | MCU Family (`mcuFamily`) | Target MCU | ESP-IDF Target | Toolchain | Supported Hardware Revisions |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `eh-smart-switch-1x` | `smart-switch/1x` | `esp32c6-switch-platform` | `esp32-c6` | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | `["HW_1_0", "HW_1_1"]` |
| `eh-smart-switch-2x` | `smart-switch/2x` | `esp32c6-switch-platform` | `esp32-c6` | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | `["HW_1_0", "HW_1_1"]` |
| `eh-smart-switch-3x` | `smart-switch/3x` | `esp32c6-switch-platform` | `esp32-c6` | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | `["HW_1_0", "HW_1_1"]` |
| `eh-smart-switch-4x` | `smart-switch/4x` | `esp32c6-switch-platform` | `esp32-c6` | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | `["HW_1_0", "HW_1_1"]` |
| `eh-smart-socket-1x` | `smart-socket/1x` | `esp32c6-socket-platform` | `esp32-c6` | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | `["HW_1_0", "HW_1_1"]` |
| `eh-smart-socket-2x` | `smart-socket/2x` | `esp32c6-socket-platform` | `esp32-c6` | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | `["HW_1_0", "HW_1_1"]` |
| `eh-smart-socket-3x` | `smart-socket/3x` | `esp32c6-socket-platform` | `esp32-c6` | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | `["HW_1_0", "HW_1_1"]` |
| `eh-smart-fan-1x` | `smart-fan/1x` | `esp32c6-fan-platform` | `esp32-c6` | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | `["HW_1_0", "HW_1_1"]` |
| `eh-smart-light-cct` | `smart-light/cct` | `esp32c6-light-platform` | `esp32-c6` | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | `["HW_1_0"]` |
| `eh-smart-hub-v1` | `smart-hub/v1` | `esp32s3-hub-platform` | `esp32-s3` | `esp32-s3` | `esp32s3` | `xtensa-esp-elf` | `["HW_1_0"]` |
| `eh-sensor-node-v1` | `sensor-node/v1` | `esp32c6-sensor-platform` | `esp32-c6` | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | `["HW_1_0"]` |

### 2.3 Naming Discrepancies Reconciliation

* **`eh-smart-light-rgbw` does NOT exist**: In earlier speculative architecture proposals, an RGBW variant was envisioned. However, inspecting `product-definitions/smart-light/` confirms only `cct/metadata.json` exists with `productVariantId: "eh-smart-light-cct"`. The RGBW variant is neither defined nor implemented.
* **`eh-sensor-node-env` does NOT exist**: Earlier build matrix text referred to `eh-sensor-node-env`. The authoritative file is `product-definitions/sensor-node/v1/metadata.json`, which defines `productVariantId: "eh-sensor-node-v1"` (with `displayName: "EH Environmental Sensor Node V1"`). `eh-sensor-node-env` was a report shorthand; the authoritative variant ID is `eh-sensor-node-v1`.

### 2.4 Firmware Implementation Status Matrix

| Firmware Family | Product Variants | Firmware Project Path | Target MCU | ESP-IDF Target | Toolchain | Implementation Status | Production Release Eligible |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `esp32c6-switch-platform` | `eh-smart-switch-1x` .. `4x` | `firmware/platforms/esp32/smart-switch-app` | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | **IMPLEMENTED** | **YES** |
| `esp32c6-socket-platform` | `eh-smart-socket-1x` .. `3x` | `firmware/platforms/esp32/smart-switch-app` (shared base + BL0942) | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | **IMPLEMENTED** | **YES** |
| `esp32-dev-platform` | `eh-smart-switch-dev`, `eh-smart-socket-dev` | `firmware/platforms/esp32/smart-switch-app` | `esp32` | `esp32` | `xtensa-esp-elf` | **IMPLEMENTED** | **NO** (Prototype Only) |
| `esp32c6-fan-platform` | `eh-smart-fan-1x` | `firmware/platforms/esp32/smart-fan-app` *(planned)* | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | **PLANNED** | **NO** |
| `esp32c6-light-platform` | `eh-smart-light-cct` | `firmware/platforms/esp32/smart-light-app` *(planned)* | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | **PLANNED** | **NO** |
| `esp32s3-hub-platform` | `eh-smart-hub-v1` | `firmware/platforms/esp32/smart-hub-app` *(planned)* | `esp32-s3` | `esp32s3` | `xtensa-esp-elf` | **PLANNED** | **NO** |
| `esp32c6-sensor-platform` | `eh-sensor-node-v1` | `firmware/platforms/esp32/sensor-node-app` *(planned)* | `esp32-c6` | `esp32c6` | `riscv32-esp-elf` | **PLANNED** | **NO** |

### 2.5 Release Tag Model (Model A: Family-Specific Release)

The repository explicitly implements **Model A (Family-Specific Release)**:

1. **Repository & Database Evidence**:
   - In Migration 031 (`packages/db-schema/migrations/031_firmware_git_binary_management.sql`), the database enforces:
     ```sql
     CONSTRAINT uq_firmware_releases_family_version UNIQUE (firmware_family, version)
     ```
     This proves release identity is fundamentally compound: a version string only has meaning within a specific `firmware_family`.
   - Firmware families represent different hardware platforms and silicon architectures (ESP32-C6 RISC-V vs ESP32-S3 Xtensa). A single build artifact cannot represent multiple firmware families.
2. **Release Tag Semantics**:
   - **Family-Scoped Tag**: `<family>@v<semver>` (e.g., `esp32c6-switch-platform@v1.0.0`). The CI release workflow extracts `TARGET_FAMILY` and `TAG_VER` directly from the tag.
   - **Generic Tag Fallback**: `v<semver>` (e.g., `v1.0.0`) defaults unambiguously to the primary active production family `esp32c6-switch-platform`. Generic tags do **NOT** mean "all families".
3. **Pre-Compilation Release Guard (Validation Order)**:
   The production release workflow strictly validates family eligibility **BEFORE** compilation:
   ```text
   Release Tag
       ↓
   Parse Family + Version
       ↓
   Validate Family Exists (CANONICAL_FIRMWARE_FAMILIES)
       ↓
   Validate Family Is Implemented (IMPLEMENTED vs PLANNED)
       ↓
   Validate Family Is Production-Eligible (PRODUCTION vs PROTOTYPE_ONLY)
       ↓
   Resolve Target Configuration (targetMcu, idfTarget, toolchain)
       ↓
   Build (Clean + Compile)
       ↓
   Artifact Discovery & Integrity (SHA-256)
       ↓
   Manifest Generation (UUID buildId + Git SHA)
   ```
   If a planned family (e.g. `esp32c6-fan-platform@v1.0.0`) or prototype family (`esp32-dev-platform@v1.0.0`) is supplied, execution halts immediately with:
   `Firmware family '<family>' is not currently eligible for production release.`
4. **Traceability Guarantee**:
   Every generated manifest (`FirmwareBuildManifest`) explicitly binds:
   `firmwareFamily`, `productVariants`, `targetMcu`, `idfTarget`, `gitCommitSha`, `buildId`, and `version`.

### 2.6 Cross-Architecture Contamination Rejection
Cross-architecture contamination is strictly prevented:
* An `esp32` (Xtensa) binary cannot be registered or bundled into an `esp32-c6` (RISC-V) release.
* When discovering artifacts, `flasher_args.json` is inspected: if the binary chip field does not match the requested target, the pipeline throws an explicit `Target Architecture Mismatch` error.
* Release readiness gate 7 (`TARGET_CONSISTENCY_VERIFIED`) rejects any release where target MCU, IDF target, toolchain, or firmware family fail to align.

---

## 3. Toolchain & Environment Pinning

### 3.1 Pinned ESP-IDF Version
* **Active Toolchain Version**: `ESP-IDF v5.4.1`
* **Target Microcontroller**: Explicitly specified per build (`esp32`, `esp32-c6`, `esp32-s3`).
* **Flash Configuration**: 4 MB SPI Flash (DIO, 40MHz), custom dual-OTA partition table (`partitions.csv` / `partitions_two_ota.csv`).
* **Application Binary Budget**: 1,835,008 bytes (1,792 KB) allocated to app partitions `ota_0` and `ota_1`.

### 3.2 Strict Toolchain Enforcement
The pipeline strictly rejects any build executed against drifting toolchains:
* In CI: GitHub Actions runner utilizes `espressif/esp-idf-ci-action@v1` with `esp-idf-version: 'v5.4.1'`.
* In scripts: `verifyToolchainEnvironment()` verifies `IDF_VERSION` environment variable or inspects `idf.py --version`. Any version drift halts execution immediately.

---

## 4. Git Source Traceability & Build Identity

### 4.1 Authoritative Commit SHA
* **Source Identity**: The 40-character hexadecimal Git commit SHA (`git rev-parse HEAD`) is the sole authoritative identity of the firmware source.
* **No Mutable Branch Names**: Mutable branch names (`main`, `develop`) cannot serve as release identity.
* **Release Tag Anchoring**: On tagged release runs (`v*.*.*`), the CI pipeline verifies that the tag resolves directly to the checked-out 40-character commit SHA.

### 4.2 Authoritative Build Identity (UUID)
* **Authoritative Build ID**: Every automated build is assigned an immutable UUID (`crypto.randomUUID()`).
* **Rejection of Truncated SHA as Identity**: Truncated 8-character prefixes are strictly rejected as authoritative build IDs, preventing prefix collision risks. An 8-character prefix may only be used as a UI display convenience.
* **Correlated Metadata**: Each build record and manifest retains:
  - `buildId`: UUID (36-character string)
  - `gitCommitSha`: Full 40-character hex string
  - `firmwareFamily`: Canonical family ID
  - `version`: Semantic version
  - `targetMcu`: Silicon MCU target
  - `idfTarget`: ESP-IDF chip target
  - `toolchain`: Compiler toolchain
  - `idfVersion`: Pinned framework version (`v5.4.1`)
  - `buildProfile`: Compilation profile (`release`, `debug`)

---

## 5. Build Artifact Discovery & SHA-256 Integrity

### 5.1 Standard Artifact Set
The pipeline discovers and validates the 5 canonical ESP-IDF build artifacts:

| Artifact Type | Filename | Role | Required |
| :--- | :--- | :--- | :--- |
| `APP_BIN` | `eh-smart-switch-app.bin` | Main application firmware binary flashed to `ota_0` | Yes |
| `BOOTLOADER` | `bootloader.bin` | 2nd stage bootloader flashed to offset `0x1000` | Yes |
| `PARTITION_TABLE` | `partition-table.bin` | Partition table binary flashed to offset `0x8000` | Yes |
| `ELF` | `eh-smart-switch-app.elf` | ELF binary with debug symbols for GDB/core-dumps | Yes |
| `MAP` | `eh-smart-switch-app.map` | Memory linkage map for flash/RAM layout analysis | Yes |

### 5.2 Cryptographic Integrity (SHA-256)
* Every artifact is read byte-by-byte from disk and its SHA-256 digest is computed using `crypto.createHash('sha256')`.
* SHA-256 digests are verified against pre-existing manifests or regenerated afresh.
* Binary tampering detection: Any byte modification (e.g. bit-flip) results in immediate validation failure.

---

## 6. Build Manifest Specification

The pipeline outputs a machine-readable, Zod-validated `FirmwareBuildManifest` (`firmware-build-manifest.json`):
```json
{
  "schemaVersion": 1,
  "buildId": "c73bcdcc-3523-4e96-9fbc-b31e779719ab",
  "firmwareFamily": "esp32c6-switch-platform",
  "productVariants": [
    "eh-smart-switch-1x",
    "eh-smart-switch-2x",
    "eh-smart-switch-3x",
    "eh-smart-switch-4x"
  ],
  "version": "1.0.0",
  "gitCommitSha": "38435d8e76a6e2e50529d4c7a6fc74301beffab3",
  "gitBranch": "main",
  "gitTag": "v1.0.0",
  "targetMcu": "esp32-c6",
  "idfTarget": "esp32c6",
  "toolchain": "riscv32-esp-elf",
  "idfVersion": "v5.4.1",
  "buildProfile": "release",
  "compatibleHardwareRevisions": ["HW_1_0", "HW_1_1"],
  "artifacts": [
    {
      "artifactType": "APP_BIN",
      "fileName": "eh-smart-switch-app.bin",
      "fileSizeBytes": 1096080,
      "sha256": "4b27b409749177114b306e987c2b6be068ff66c3a2f7d3a0429188bf0a01a357",
      "storagePath": "firmware/builds/smart-switch-app/eh-smart-switch-app.bin",
      "targetMcu": "esp32-c6",
      "idfTarget": "esp32c6"
    }
  ],
  "generatedAt": "2026-09-25T19:00:00.000Z"
}
```

---

## 7. Automated Release-Readiness Gates

Before a firmware release can transition to `APPROVED` or `RELEASED`, the release readiness engine (`evaluateReleaseReadiness`) evaluates 7 explicit gates:

1. **`SOURCE_GIT_SHA_VALID`**: Git commit SHA is a valid 40-character hex string.
2. **`ESP_IDF_PINNED_VERSION`**: ESP-IDF is strictly pinned to `v5.4.1`.
3. **`FIRMWARE_HOST_TESTS`**: All host unit tests and hardware integration tests passed (100% green).
4. **`REQUIRED_ARTIFACTS_PRESENT`**: Required binaries (`APP_BIN`, `BOOTLOADER`, `PARTITION_TABLE`) exist and have positive sizes within budget.
5. **`SHA256_INTEGRITY_VERIFIED`**: Cryptographic SHA-256 digests match actual binary contents.
6. **`HARDWARE_COMPATIBILITY_VERIFIED`**: Declared hardware revisions exist and match the product/firmware family.
7. **`TARGET_CONSISTENCY_VERIFIED`**: Target MCU, IDF target, compiler toolchain, and firmware family align without contradiction.

Exposed via API endpoint:
```http
GET /api/v1/firmware/releases/:releaseId/readiness
```

---

## 8. Continuous Integration Workflows

### 8.1 `firmware-ci.yml` (Multi-Target Verification CI)
* **Triggers**: Pull requests and pushes affecting `firmware/**`, `packages/contracts/**`, or `.github/workflows/firmware-*.yml`.
* **Job Structure**:
  1. `verify-toolchain-and-tests`: Runs toolchain drift guards, firmware host tests, and hardware integration tests.
  2. `build-production-esp32c6`: Compiles `esp32c6` with ESP-IDF 5.4.1 (RISC-V architecture), executes pipeline with `--target-mcu esp32-c6 --idf-target esp32c6 --family esp32c6-switch-platform`, verifies manifest, and stores 30-day CI artifacts.
  3. `build-prototype-esp32`: Compiles `esp32` with ESP-IDF 5.4.1 (Xtensa architecture), executes pipeline with `--target-mcu esp32 --idf-target esp32 --family esp32-dev-platform`, verifies manifest, and stores 14-day prototype verification artifacts.

### 8.2 `firmware-release.yml` (Production Release CI)
* **Triggers**: Tag pushes matching `v*.*.*` or `*@v*.*.*`, or manual `workflow_dispatch`.
* **Pre-Compilation Family Guard**:
  - Executes BEFORE compilation using `validateProductionReleaseFamily()`.
  - Rejects planned families (`esp32c6-fan-platform`, `esp32c6-light-platform`, `esp32s3-hub-platform`, `esp32c6-sensor-platform`) with immediate exit code 1.
  - Rejects prototype families (`esp32-dev-platform`) from production releases.
  - Resolves generic `v<semver>` to the default production family `esp32c6-switch-platform`.
* **Dynamic Target Resolution**:
  - Binds `TARGET_MCU`, `IDF_TARGET`, and `TOOLCHAIN` dynamically from canonical family metadata.
  - Passes `${{ env.IDF_TARGET }}` to the compilation step (`espressif/esp-idf-ci-action@v1`).
* **Execution**: Performs clean build, compiles with ESP-IDF 5.4.1 for the resolved target, executes pipeline with `--target-mcu "${TARGET_MCU}" --idf-target "${IDF_TARGET}" --toolchain "${TOOLCHAIN}" --family "${TARGET_FAMILY}" --version "${TARGET_VERSION}" --profile release`, asserts manifest target identity (`targetMcu`, `idfTarget`, `toolchain`, `firmwareFamily`), and bundles release artifacts with 90-day retention.
* **Prohibition**: Prototype `esp32` builds are strictly prohibited in the official production release workflow.

---

## 9. Local Reproduction Guide

```bash
# 1. Activate pinned ESP-IDF 5.4.1 environment (PowerShell)
. .\scripts\activate_idf5.4.ps1

# 2. Build for production ESP32-C6 target:
cd firmware/platforms/esp32/smart-switch-app
idf.py set-target esp32c6
idf.py build

# 3. Or build for bench-testing ESP32 Dev Board target:
idf.py set-target esp32
idf.py build

# 4. Run automated pipeline orchestrator from repository root:
cd ../../..
node scripts/firmware_pipeline.js --target-mcu esp32-c6 --idf-target esp32c6 --family esp32c6-switch-platform --version 1.0.0
```

---

## 10. Boundaries & Deferred Scope

* **Storage Boundary**: `IFirmwareArtifactStore` continues to abstract permanent artifact storage. Production S3/MinIO infrastructure is deferred to later cloud deployment phases.
* **Cryptographic Signing Boundary**: Part 08 establishes **SHA-256 integrity**, not digital signatures. Ed25519/RSA-3072 signing and HSM key management are explicitly deferred to later PKI/OTA phases.
* **OTA & Manufacturing Boundary**: No OTA rollout orchestration, and no bench serial flashing or QR generation are implemented here (assigned to Part 09).
