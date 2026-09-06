# Phase 43 — Production Observability, Monitoring & Incident Response

## Overview

Phase 43 establishes a comprehensive, production-grade observability, telemetry, and incident-response architecture across the EH Home platform. It unifies structured application logging, bounded multi-category metrics collection, deterministic alert evaluation with deduplication, and a robust platform incident response state machine with timeline aggregation referencing existing operational, security, and OTA event records.

---

## Key Architecture Pillars

```
+-------------------------------------------------------------------------+
|                           EH HOME BACKEND                               |
|                                                                         |
|  +--------------------+   +-------------------+   +------------------+  |
|  |  StructuredLogger  |   |  MetricsService   |   | AlertRulesService|  |
|  |  (JSON + Redact)   |   | (Bounded Buckets) |   | (Deduplication)  |  |
|  +--------------------+   +-------------------+   +------------------+  |
|            |                        |                       |           |
|            v                        v                       v           |
|    [Correlation ID]      [Snapshots / Histograms]    [Platform Alerts]  |
|                                                             |           |
|                                                             v           |
|  +-------------------------------------------------------------------+  |
|  |                          IncidentService                          |  |
|  |  OPEN -> ACKNOWLEDGED -> INVESTIGATING -> MITIGATING -> RESOLVED  |  |
|  +-------------------------------------------------------------------+  |
|                                     |                                   |
|                                     v                                   |
|  +-------------------------------------------------------------------+  |
|  |                    Federated Timeline Aggregator                  |  |
|  |   • References: operational_events, security_audit_records,       |  |
|  |                 ota_operations, platform_alerts                   |  |
|  |   • Invariant: Zero duplication of raw event records              |  |
|  +-------------------------------------------------------------------+  |
+-------------------------------------------------------------------------+
```

---

## 1. Structured Logging (`StructuredLogger`)

- **Format**: Structured JSON output for downstream log ingestors (Elasticsearch, OpenSearch, CloudWatch, Datadog).
- **Correlation ID Tracking**: Automatically extracts or generates `X-Correlation-ID` and includes it in all formatted logs and HTTP response headers.
- **Sensitive Key Redaction**: Recursively identifies and redacts sensitive keys (`password`, `secret`, `token`, `key`, `authorization`, `credential`, `pin`, `cert`, `cookie`, `session`) with `[REDACTED]`.
- **Safe Serialization**: Handles circular references safely without throwing runtime errors.

---

## 2. Bounded Multi-Category Metrics (`MetricsService`)

- **Primitives**: Counters, gauges, and bounded histograms (fixed-sample retention per bucket to eliminate memory leaks).
- **Categories Covered**:
  - `api`: Request rate, durations (p50/p90/p95/p99), 4xx client errors, 5xx server errors, route breakdowns.
  - `auth`: Authentication success/failure rates, rate-limit triggers.
  - `device`: Heartbeats, disconnection frequency, command response latency.
  - `ota` / `fleet`: Firmware rollout attempt success/failure, download/verification errors.
  - `database`: Query latency histograms, error counts.
  - `notification`: Delivery queue latency, channel dispatches, failure rates.
  - `backup`: Backup/restore durations and outcomes.
- **RBAC-Gated Snapshots**: `GET /api/v1/admin/observability/metrics` provides sanitized aggregated metric summaries strictly to authorized operators.

---

## 3. Deterministic Alert Rules & Deduplication (`AlertRulesService`)

- **Built-in Rules**:
  - `RULE_API_5XX_SPIKE`: Alerts when 5xx server errors exceed threshold.
  - `RULE_AUTH_BRUTE_FORCE_SPIKE`: Alerts on sudden bursts of auth failures or rate-limit hits.
  - `RULE_FLEET_OTA_FAILURE_SPIKE`: Detects fleet OTA rollout failure rates.
  - `RULE_DEVICE_MASS_DISCONNECT`: Flags anomalous spikes in device disconnections.
  - `RULE_DATABASE_DEGRADATION`: Detects database query degradation or errors.
- **Deduplication Key**: `SHA256("${ruleId}:${targetComponent}:${discriminator}")`
  - Prevents alert storms by updating `occurrence_count` and `last_triggered_at` on active alerts instead of creating duplicate records.

---

## 4. Incident Management Lifecycle (`IncidentService`)

- **State Machine**:
  ```
  OPEN ───────> ACKNOWLEDGED ───────> INVESTIGATING ───────> MITIGATING ───────> RESOLVED ───────> CLOSED
    │                 │                      │                     │                 │
    └─────────────────┴──────────────────────┴─────────────────────┴─────────────────┘
                                       (Can transition to CLOSED directly on false alarm)
  ```
- **Milestones**: Automatic recording of `opened_at`, `acknowledged_at`, `mitigated_at`, `resolved_at`, and `closed_at`.
- **Incident Commander**: Explicit assignment and re-assignment of lead operator.
- **Severity Escalation**: Supports `SEV1`, `SEV2`, `SEV3`, `SEV4` with full historical tracking.
- **Federated Timeline Aggregation (Invariant Enforcement)**:
  - Aggregates lifecycle milestones, linked alerts, operational events, and security audit records into a unified chronological timeline on query.
  - **Does NOT replicate raw data** into new incident tables; all entries reference existing canonical tables.

---

## 5. Database Schema (Migration 029)

### Tables Added:
1. `platform_incidents`:
   - Primary key: `id` (VARCHAR(64))
   - Fields: `title`, `description`, `severity`, `status`, `affected_component`, `affected_homes` (JSONB), `affected_devices` (JSONB), `commander_user_id`, `correlated_event_ids` (JSONB), `correlated_audit_record_ids` (JSONB), `correlated_rollout_ids` (JSONB), `root_cause`, `mitigation_summary`, `opened_at`, `acknowledged_at`, `mitigated_at`, `resolved_at`, `closed_at`, `metadata` (JSONB), `created_at`, `updated_at`.
2. `platform_alerts`:
   - Primary key: `id` (VARCHAR(64))
   - Fields: `rule_id`, `title`, `description`, `severity`, `status`, `deduplication_key` (VARCHAR(64) UNIQUE/INDEXED), `occurrence_count`, `first_triggered_at`, `last_triggered_at`, `resolved_at`, `incident_id` (FOREIGN KEY REFERENCES `platform_incidents(id)`), `context` (JSONB), `created_at`, `updated_at`.

---

## 6. Observability REST Endpoints

| Method | Path | Role | Description |
|---|---|---|---|
| `GET` | `/api/v1/admin/observability/metrics` | Admin / Operator | Aggregated metrics snapshot (optional `?category=`) |
| `GET` | `/api/v1/admin/observability/alerts` | Admin / Operator | List platform alerts with filters |
| `POST` | `/api/v1/admin/observability/alerts/evaluate` | Admin / Operator | Trigger evaluation of alert rules |
| `POST` | `/api/v1/admin/observability/alerts/:id/resolve` | Admin / Operator | Mark an alert as resolved |
| `GET` | `/api/v1/admin/observability/incidents` | Admin / Operator | List incidents with status/severity filters |
| `POST` | `/api/v1/admin/observability/incidents` | Admin / Operator | Open a new platform incident |
| `GET` | `/api/v1/admin/observability/incidents/:id` | Admin / Operator | Get incident details |
| `PATCH` | `/api/v1/admin/observability/incidents/:id/status` | Admin / Operator | Advance incident lifecycle status |
| `PATCH` | `/api/v1/admin/observability/incidents/:id/commander` | Admin / Operator | Assign/reassign incident commander |
| `PATCH` | `/api/v1/admin/observability/incidents/:id/severity` | Admin / Operator | Escalate/update severity |
| `POST` | `/api/v1/admin/observability/incidents/:id/alerts` | Admin / Operator | Associate alert with incident |
| `GET` | `/api/v1/admin/observability/incidents/:id/timeline` | Admin / Operator | Fetch federated incident timeline |

---

## 7. Flutter Operator View

- **Location**: `lib/features/operations/presentation/platform_incidents_page.dart`
- **Features**:
  - Filter chips for status selection (`ALL`, `OPEN`, `INVESTIGATING`, `RESOLVED`).
  - Severity-coded badges (`SEV1` Red, `SEV2` Orange, `SEV3` Amber, `SEV4` Blue).
  - Modal bottom sheet displaying detailed root-cause, mitigation summary, and chronologically sorted federated timeline.
  - One-tap quick status resolution actions for operators.
