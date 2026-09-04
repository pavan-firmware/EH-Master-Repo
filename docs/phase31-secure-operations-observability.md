# Phase 31 — Secure Operations, Audit & Platform Observability

## Overview
Phase 31 implements an authoritative operations observability and tamper-evident security audit infrastructure for the EH Home smart home ecosystem. It bridges the gap between low-level subsystem telemetry and unified platform observability, answering with certainty:
- **What operation happened?**
- **To which resource?**
- **When did it occur?**
- **Initiated by which subsystem and actor?**
- **What was the outcome (Success, Failure, Partial, Timeout, Deferred)?**
- **Was it authorized?**
- **Was execution performed locally on the edge or routed to the cloud?**
- **What failure code was produced?**
- **Can the entire multi-hop causation chain be faithfully reconstructed?**

---

## Architecture & Core Invariants

### 1. Separation of Concerns: General Audit vs Security Audit (FIX 1)
- **General Domain Audit (`audit_logs`)**: Remains the authoritative source for domain entity modifications (room rename, device assignment, scene triggers, member invitations).
- **Tamper-Evident Security Audit (`security_audit_records`)**: Restricted strictly to security-critical transitions (authentication bursts, role elevation, policy changes, factory reset, tamper detection) that mandate sequential cryptographic hash chaining.
- **Zero Double-Writing**: No event is duplicated across both stores. Every audit category has exactly one authoritative record.

### 2. Cryptographic Hash-Chained Integrity & Multi-Process Concurrency (FIX 2)
- **Genesis Block**: Sequence 1 chains from a deterministic zero parent (`'0000000000000000000000000000000000000000000000000000000000000000'`).
- **Deterministic SHA-256 Chaining**: Each record hash is computed over canonical ordered fields: `sequenceNumber | prevRecordHash | timestamp | actorUserId | homeId | deviceId | action | resourceType | resourceId | outcome | canonicalPayload`.
- **Concurrency Safety**: Sequence assignment and previous hash link generation are enforced at the database transaction / atomic locking level, safe across multiple backend processes and server instances.

### 3. Derived Operational Metrics & Statistical Insignificance (FIX 3)
- **Restart Resilience**: Metrics are derived aggregates computed directly from persistent `operational_events`, surviving server restarts.
- **Insignificance Guard**: When sample size is small ($N < 5$), success rates are flagged as statistically insignificant (`isStatisticallySignificant: false`) with an explanatory note to avoid misleading percentages.

### 4. Bounded Observational Health Checks (FIX 4)
- **Strictly Observational**: Health checks never execute business logic, never fire device commands, never generate notification storms, and never emit operational events on every poll.
- **Strictly Bounded**: All subsystem checks timeout gracefully within 1500ms.
- **Evidence Threshold**: A single timeout or check failure alone is reported as a `DEGRADED` observation error, NOT definitive proof of total subsystem failure. Only repeated consecutive failures meeting or exceeding the threshold classify a subsystem as `UNAVAILABLE`.

### 5. Server-Side Security & Scoping (FIX 5)
- All operational routes (`/events`, `/metrics`, `/traces/:id`, `/audit`, `/audit/integrity`, `/errors`) enforce 401/403 authorization server-side.
- Scoped home and device queries require verified home membership.
- Cross-home and integrity verification APIs require platform `ADMIN` or `DIAGNOSTIC` roles. Flutter role checks serve exclusively for UX presentation.

### 6. Recursive Secret Redaction
- `AuditRedactionService` recursively redacts sensitive credentials (passwords, tokens, PINs, WiFi PSKs, private keys) with `[REDACTED]` before persistence into operational events, traces, and audit logs. Non-sensitive payload attributes are strictly preserved.
