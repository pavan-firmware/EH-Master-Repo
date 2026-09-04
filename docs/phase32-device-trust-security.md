# Phase 32: Secure Device Identity, Trust & Credential Lifecycle

## Overview
Phase 32 establishes a unified, production-grade device identity, trust state engine, credential lifecycle, and revocation architecture for the EH Home smart home platform. It ensures continuous cryptographic verification of device identity, deterministic trust scoring, concurrency-safe credential rotation, robust defense-in-depth isolation, and explicit factory reset reconciliation without opening trust recovery backdoors.

---

## Core Security Invariants & Guarantees

### 1. Authoritative Store vs. Lifecycle Ledger Boundary (Fix 1)
- `device_credentials` remains the authoritative database store for all currently usable device communication credentials (MQTT username, password hash, local session key hash, TLS client cert fingerprint, credential state).
- `device_credential_lifecycle` is strictly a historical lifecycle/rotation ledger. It **never** acts as a second source of truth for whether a credential is valid.
- Every credential lifecycle record references the corresponding authoritative credential generation.
- No conflicting states can exist: if a device is revoked, its authoritative credential state is atomically set to `REVOKED`.

### 2. Zero Secrets in Lifecycle Metadata (Fix 2)
- `device_credential_lifecycle.metadata` **must not** contain raw passwords, tokens, private keys, session secrets, Wi-Fi credentials, MQTT passwords, or Matter secrets.
- Only non-secret operational metadata is permitted: key identifier, fingerprint, algorithm, provider, generation counter, timestamps, status, rotation rationale.
- Centralized Phase 31 `AuditRedactionService.redact` is applied automatically as defense-in-depth sanitization prior to persistence.

### 3. Concurrency-Safe & Idempotent Credential Rotation (Fix 3)
- For a given `(device_id, credential_type)`:
  - Only **one** `ROTATION_PENDING` generation may exist at any given time.
  - Duplicate rotation requests reuse/return the existing pending operation without incrementing generations or creating parallel operations.
  - Generation numbers ($N+1$) are allocated monotonically and atomically.
  - Stale confirmation requests (for expired or non-pending generations) are rejected.
  - Active credentials in `device_credentials` remain usable until the new credential generation is confirmed.

### 4. Factory Reset Reconciliation Boundary (Fix 4)
- `FACTORY_RESET` is a lifecycle/reconciliation state, **not** an automatic trust-recovery state.
- A factory reset:
  - Preserves immutable hardware identity (UUID, serial number, product variant, hardware revision, firmware family).
  - Clears/resets applicable home authorization claims (`device_authorizations`).
  - Invalidates applicable temporary credentials (sets authoritative state to `RESET`).
  - Forces trust re-evaluation.
- `FACTORY_RESET` **must not** transition `REVOKED -> TRUSTED` or `DECOMMISSIONED -> TRUSTED`.
- Devices in `REVOKED` or `DECOMMISSIONED` state remain revoked after a factory reset; restoration requires explicit authorized remediation with cryptographic attestation verification.

### 5. OTA Quarantine & Recovery Policy (Fix 5)
- **Normal OTA**: Permitted **only** for `TRUSTED` or appropriately `DEGRADED` devices.
- **Recovery / Security OTA**: Permitted for `QUARANTINED` devices only when explicitly authorized as a recovery update and when cryptographic firmware signature verification succeeds.
- **Revoked / Decommissioned Devices**: OTA denied unconditionally unless an explicit device-recovery authority is defined.
- Quarantine **never** bypasses firmware signature verification.

---

## Architecture Components

### Canonical Contract Schemas (`packages/contracts/device-trust/`)
1. `device-identity-verification.schema.json`
2. `device-trust-state.schema.json`
3. `device-credential-lifecycle.schema.json`
4. `device-revocation.schema.json`
5. `device-provisioning-record.schema.json`
6. `device-security-event.schema.json`

### Database Schema (Migration 025)
- `device_trust_states`
- `device_credential_lifecycle`
- `device_revocations`
- `device_provisioning_records`

### Backend Services & Routers
- `DeviceTrustRepository`: Database layer for device trust states, lifecycle ledger, revocations, and provisioning records.
- `DeviceTrustService`: Deterministic trust engine, continuous scoring, safe rotation, factory reset reconciliation, offline HMAC validation, and OTA policy enforcement.
- `DeviceCommandService` Hook: Intercepts command dispatch to reject execution on quarantined or revoked devices while preserving local physical switch safety.
- `OtaService` Hook: Enforces normal vs. recovery OTA policy and prevents quarantine signature bypass.
- `DataRetentionService` Integration: Automated pruning of historical rotated credentials (>180 days) and completed provisioning records (>90 days).
- `DeviceTrustApiRouter`: REST API routes for querying trust, initiating/confirming key rotations, quarantine, revocation, and remediation.

### Flutter Client (`smart_home_application_v1`)
- Domain Models: `DeviceTrustStateModel`, `DeviceCredentialLifecycleModel`, `DeviceRevocationModel`, `DeviceSecurityHistoryModel`.
- Repositories: `DeviceTrustRepository`, `CloudDeviceTrustRepository`.
- Presentation UI: `DeviceSecurityStatusPage` showing trust status badge, continuous trust score meter, action buttons (Rotate, Quarantine, Restore Trust), credential lifecycle ledger, and revocation audit log.
