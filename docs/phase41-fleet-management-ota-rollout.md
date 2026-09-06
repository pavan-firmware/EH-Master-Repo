# Phase 41 — Production Device Fleet Management & Safe OTA Rollout

**Author:** EH Platform Engineering  
**Revision:** 1.0.0 (Phase 41 Release)  
**Status:** IMPLEMENTED & VALIDATED  

---

## 1. Overview & Architecture

Phase 41 delivers an enterprise-grade production device fleet management and controlled firmware Over-The-Air (OTA) rollout engine. It builds directly upon the Phase 35 device OTA foundation, Phase 34 operational readiness, Phase 33 recovery, Phase 32 device identity trust, Phase 31 audit, Phase 30 notifications, Phase 39 product catalog, and Phase 40 manufacturing/provisioning subsystems without duplicating or replacing existing OTA infrastructure.

### Architecture Flow

```
┌─────────────────────────┐
│ Firmware Release Engine │ (DRAFT -> PUBLISHED -> REVOKED)
│  - Ed25519 & SHA256     │
│  - Partition bounds     │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│ Eligibility & Safety    │ (Compatibility, Trust, Health Deferral,
│      Gate Engine        │  Anti-Rollback, Minimum Version)
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│ Controlled Rollout      │ (Deterministic Hash Cohorts, Max Concurrency,
│      State Machine      │  Batch Slicing, Auto-Pause Thresholds)
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│ Post-OTA Lifecycle      │ (REQUESTED -> DOWNLOADING -> INSTALLED ->
│  & Health Verification  │  BOOT_VERIFIED -> HEALTH_VERIFIED)
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│ Authorized Rollback     │ (Known-Good Resolution, Cryptographic Verification,
│  & Failure Recovery     │  Revocation Guard, Zero Downgrade Bypass)
└─────────────────────────┘
```

---

## 2. Canonical Persistence Schema (Migration 028)

To maintain database schema consistency, Migration 028 extends existing migration 011 tables (`firmware_releases`, `ota_rollouts`, `ota_operations`, `device_maintenance_logs`) and introduces canonical persistence for:

1. **`fleet_device_firmware_state`**: Authoritative per-device current firmware version, target version, rollout tracking, health verification state, boot verification, download progress, and maintenance windows.
2. **`ota_attempts`**: Immutable attempt logs tracking attempt numbers, failure codes, stack traces, latency, and operational health metrics.
3. **`ota_rollouts` extensions**: Rollout percentage, batch size, concurrency limits, failure percentage thresholds, and state machine transitions.

---

## 3. Firmware Release Lifecycle & Cryptographic Validation

Firmware artifacts undergo strict validation before entering the repository:
- **Mandatory HTTPS:** Firmware URLs must use secure HTTPS endpoints (`https://...`). Insecure HTTP is strictly rejected.
- **SHA-256 Digest Verification:** 64-character hexadecimal checksum of the binary.
- **Ed25519 Signature Verification:** 128-character hexadecimal cryptographic signature validated against release keys.
- **Flash Partition Bounds Check:** Binary artifact size must be $\le$ max partition capacity (e.g. 1,792 KB for `ota_0`/`ota_1`).
- **Lifecycle States:** `DRAFT` $\rightarrow$ `PUBLISHED` $\rightarrow$ `REVOKED`. Revoked releases can never be targeted for rollout or rollback.

---

## 4. Deterministic Eligibility & Safety Gates

Prior to dispatching an OTA command, devices are evaluated through deterministic safety gates (`OtaEligibilityService`):

| Check | Failure Code | Action |
|---|---|---|
| Target version already installed | `ALREADY_CURRENT` | Skipped |
| Device offline / disconnected | `DEVICE_OFFLINE` | Deferred (`isDeferred: true`) |
| Device health degraded / recovering | `DEVICE_UNHEALTHY` | Deferred (`isDeferred: true`) |
| Incompatible product variant | `INCOMPATIBLE_PRODUCT` | Rejected |
| Incompatible hardware revision | `INCOMPATIBLE_HARDWARE_REVISION` | Rejected |
| Untrusted / revoked identity | `TRUST_DENIED` | Rejected (Phase 32 Trust Gate) |
| Firmware downgrade attempt | `ANTI_ROLLBACK_VIOLATION` | Rejected unless authorized rollback |
| Bridge version prerequisites | `MIN_VERSION_NOT_MET` | Rejected |

---

## 5. Controlled Rollout Engine & State Machine

Rollouts progress deterministically through bounded percentage stages (e.g., 1% canary $\rightarrow$ 10% pilot $\rightarrow$ 25% $\rightarrow$ 50% $\rightarrow$ 100% full fleet).

### State Transitions
- `DRAFT` $\rightarrow$ `SCHEDULED` $\rightarrow$ `RUNNING` $\rightarrow$ `COMPLETED`
- `RUNNING` $\leftrightarrow$ `PAUSED`
- `RUNNING` $\rightarrow$ `FAILED_THRESHOLD_PAUSED` (automatic circuit-breaker triggered on error count or percentage)
- `RUNNING` / `PAUSED` $\rightarrow$ `ROLLING_BACK` $\rightarrow$ `ROLLED_BACK`
- Any active state $\rightarrow$ `CANCELLED`

### Batch Execution & Concurrency Limits
`executeBatch()` enforces:
- Rollout active state (`RUNNING` or `ROLLING_BACK`).
- Cohort selection using SHA-256 hash modulo on `rolloutId:deviceId`.
- Batch slicing strictly bounded by `batchSize`.
- Maximum in-flight updates bounded by `maxConcurrency`.

---

## 6. Post-OTA Lifecycle & Health Verification

Devices transition through a rigorous post-flash verification protocol:
1. `REQUESTED`: Command queued and dispatched via MQTT/Transport.
2. `DOWNLOADING`: Device acknowledges download with real-time percentage progress.
3. `INSTALLED`: Flash write complete; partition marked for boot.
4. `BOOT_VERIFIED`: Device restarts and reports runtime self-test and hardware version.
5. `HEALTH_VERIFIED`: Device passes operational health window (MQTT connectivity, state sync, telemetry freshness).
6. `FAILED`: Failed at any point; triggers retry policy or threshold evaluation.

---

## 7. Authorized Rollback Protocol

Rollback is **NOT** a generic downgrade. Target rollbacks must be:
- Explicitly authorized by an operator (`ADMIN` role with `canManageFirmware` permission).
- Cryptographically signed and verified (Ed25519 + SHA-256).
- Compatible with device product variant and hardware revision.
- In `PUBLISHED` status (cannot rollback to `REVOKED` or `DRAFT` releases).
- Validated against security policies.

---

## 8. Flutter Fleet Management Interface

The Flutter application provides administrative screens:
- **`FirmwareReleasesPage`**: Release catalog, channel filters, publishing, revocation, and cryptographic signatures.
- **`OtaRolloutsPage`**: Active campaigns, cohort percentages, health metrics, and failure alerts.
- **`RolloutDetailsPage`**: Detailed batch execution, pause/resume, failure-threshold monitoring, and authorized rollback initiation.
- **`FleetFirmwareStatusPage`**: Device-level firmware inventory, verification status, and retry controls.
