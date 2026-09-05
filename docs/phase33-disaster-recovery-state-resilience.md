# Phase 33: Disaster Recovery, Backup & State Resilience

## Overview
Phase 33 establishes a production-grade disaster recovery, backup, restore, integrity verification, and state-resilience layer for the EH Home smart home platform. It ensures deterministic state recovery, strict secret sanitization, pre-flight restore planning, non-destructive cryptographic integrity verification, and post-restore security reconciliation while preserving Phase 32 device trust and revocation authority.

---

## 1. Data Authority & Recovery Classification

All persistent states across the EH Home platform are audited and classified into 5 strict tiers:

| Table / Entity | Classification | Authoritative Source | Recovery Behavior & Dependency |
|---|---|---|---|
| `users`, `user_profiles` | `CRITICAL_STATE` | Primary DB | Backed up with password hashes redacted; email & identity preserved |
| `refresh_tokens` | `EPHEMERAL` | Primary DB | Excluded from backups; users re-authenticate post-restore |
| `homes`, `floors`, `rooms` | `CRITICAL_STATE` | Primary DB | Backed up; top of topology hierarchy |
| `home_memberships` | `CRITICAL_STATE` | Primary DB | Backed up; depends on `users` + `homes` |
| `devices` | `CRITICAL_STATE` | Primary DB / Hardware Factory | Backed up; depends on `homes` & `product_variants` |
| `device_authorizations` | `CRITICAL_STATE` | Primary DB | Backed up; represents active home claiming |
| `device_credentials` | `SECURITY_STATE` / `EXTERNAL_AUTHORITY` | Device Trust Engine | Passwords/keys excluded; references/fingerprints backed up |
| `device_trust_states` | `SECURITY_STATE` | Phase 32 Trust Service | Backed up; re-evaluated post-restore against current evidence |
| `device_credential_lifecycle`| `SECURITY_STATE` | Phase 32 Ledger | Backed up; rotation history preserved, expired credentials kept expired |
| `device_revocations` | `SECURITY_STATE` | Phase 32 Revocation Store | Backed up; revoked devices remain permanently revoked post-restore |
| `device_provisioning_records`| `HISTORICAL_STATE` | Primary DB | Backed up; factory provisioning provenance |
| `matter_fabrics`, `matter_devices`, `matter_endpoints` | `CRITICAL_STATE` | Primary DB / Matter Fabric | Backed up; fabric operational state reconciled with Matter node |
| `automations`, `scenes`, `schedules` | `CONFIGURATION_STATE` | Primary DB | Backed up; depends on `devices` & `capabilities` |
| `user_notification_preferences` | `CONFIGURATION_STATE` | Primary DB | User alert and notification preferences backed up |
| `energy_tariffs`, `tariff_periods`, `energy_budgets` | `CONFIGURATION_STATE` | Primary DB | Backed up; user energy billing configuration |
| `recovery_checkpoints`, `security_audit_records` | `HISTORICAL_STATE` | Platform Engine | Backed up as audit trail; cryptographic hash-chains verified |

---

## 2. Core Security & State Invariants

### 1. Zero Plaintext Secrets in Recovery Artifacts
- Backups **never** contain plaintext passwords, password hashes, access tokens, refresh tokens, private keys, Wi-Fi credentials, MQTT passwords, or Matter private key material.
- Redacted fields are stripped at the backup boundary (`SecretSanitizer`) and verified by scanning generated filesystem artifact files directly.

### 2. Phase 32 Trust & Revocation Authority Preservation
- A database restore **never** silently resurrects a revoked device to `TRUSTED`.
- Decommissioned devices remain `DECOMMISSIONED` post-restore.
- Expired credentials remain `EXPIRED` post-restore and are not promoted to `CONFIRMED`.
- Physically factory-reset devices do not regain automatic trust upon restore.
- Post-restore device trust state is re-evaluated via Phase 32 `DeviceTrustService`.

### 3. Mutual Exclusion & Concurrency Control
- Only **one** active restore operation may run across the platform at any given time.
- Single active restore lock prevents conflicting concurrent restores and database race conditions.

### 4. Non-Destructive Integrity Verification
- Integrity checks calculate SHA-256 digests on all stored objects and compare against the manifest checksum.
- Corrupted or truncated objects are flagged as `INVALID`.
- Schema or migration incompatibilities are flagged as `INCOMPATIBLE`.
- Verification never alters active production database state.

### 5. Multi-Stage Restore Lifecycle
```
VALIDATE → PRECHECK → PLAN → APPLY → VERIFY → COMPLETE / FAILED
```
- Restores require pre-flight dry-run planning and explicit administrative authorization before execution.
- Restores are executed in strict dependency order:
  `identity → topology → device registry → device trust → integrations → configuration → checkpoints`

---

## 3. Canonical Contracts (`packages/contracts/recovery/`)
- `backup-manifest.schema.json`
- `backup-record.schema.json`
- `restore-operation.schema.json`
- `recovery-checkpoint.schema.json`
- `recovery-integrity.schema.json`
- `recovery-event.schema.json`
- `index.ts`

---

## 4. Database Schema (Migration 026)
- `backup_records`
- `backup_objects`
- `restore_operations`
- `recovery_checkpoints`
- `recovery_integrity_results`
