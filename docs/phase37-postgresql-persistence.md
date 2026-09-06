# Phase 37 — Real PostgreSQL Persistence & Migration Runner

## Overview & Architecture

Phase 37 replaces the backend's in-memory storage path with a real, production-ready PostgreSQL persistence architecture while preserving complete backward compatibility with all 50+ domain repositories, transaction boundaries, and the in-memory testing strategy.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Backend Repositories                            │
│ (User, Home, Device, Command, Telemetry, OTA, Security, Recovery, ...)  │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
                   ┌───────────────────────────────┐
                   │        DatabaseClient         │
                   └───────────────┬───────────────┘
                                   │
          ┌────────────────────────┴────────────────────────┐
          ▼                                                 ▼
┌───────────────────────────┐                     ┌───────────────────────────┐
│  InMemoryDatabaseAdapter  │                     │ PostgreSQLDatabaseAdapter │
│   (Testing, Dev Mocks)    │                     │  (Production, Cloud Node) │
└───────────────────────────┘                     └─────────────┬─────────────┘
                                                                │
                                                  ┌─────────────┴─────────────┐
                                                  │       pg.Pool Driver      │
                                                  │ (Parameterized SQL, SSL)  │
                                                  └───────────────────────────┘
```

---

## Key Components

### 1. Unified Persistence Adapter Hierarchy (`backend/src/shared/`)

- `database-adapter.js`: Abstract base class defining the persistence protocol (`connect`, `close`, `query`, `insert`, `findById`, `find`, `update`, `delete`, `withTransaction`, `checkHealth`).
- `postgres-db-adapter.js`: Concrete adapter backed by `pg.Pool`. Handles connection pooling, identifier escaping, parameterized SQL (`$1, $2, ...`), JSONB serialization/deserialization, and PostgreSQL transaction wrappers (`BEGIN`/`COMMIT`/`ROLLBACK`).
- `in-memory-db-adapter.js`: Deterministic, in-memory collection map adapter with isolation, deep copying, snapshot-based transaction rollback, and health checking.
- `db-client.js`: Thin, ergonomic client and factory (`createDatabaseClient`) that provides query routing and explicit mode selection.

### 2. Explicit, Deterministic Mode Selection

Unit tests must never accidentally connect to a live database just because `DATABASE_URL` is set in the host environment. The persistence mode selection is deterministic:

| Mode | Target Adapter | Rationale |
|---|---|---|
| `TEST` | `InMemoryDatabaseAdapter` | Fast, isolated, zero-dependency unit testing. |
| `INTEGRATION` | `PostgreSQLDatabaseAdapter` (or in-memory if not configured) | Validates SQL dialect, indexing, and foreign keys. |
| `PRODUCTION` | `PostgreSQLDatabaseAdapter` | Enforces real PostgreSQL connection with pooled sockets and SSL. |

### 3. Programmatic & CLI Migration Runner (`backend/migrations/migrate.js`)

Provides schema versioning with transactional consistency and drift detection:
- **Discovered Migrations**: Automatically detects and sorts SQL migrations `001` through `026`.
- **Advisory Locks**: Secures concurrent migrations using `pg_advisory_lock(2026090637)`.
- **Drift Detection**: Calculates SHA-256 checksums of SQL migration files and compares against the `schema_migrations` catalog table.
- **Production Guardrails**:
  - `up`: Applies pending migrations sequentially within an atomic transaction.
  - `status`: Displays applied vs pending migration inventory with execution timestamps.
  - `validate`: Confirms existing migrations have not been altered out-of-band.
  - `down`: Strictly prohibited in `production`. Requires `--force-dev-downgrade` flag in non-production environments.

---

## Migration Catalog (001–026)

All 26 migrations maintain symmetric UP (`.sql`) and DOWN (`.down.sql`) scripts covering 98 managed tables across all phases:
1. `001_initial_schema.sql` (Users, Homes, Devices, Commands, Events)
2. `002_capabilities_network_audit_outbox.sql`
3. `003_seed_dev_catalog.sql`
4. `004_seed_missing_capabilities.sql`
5. `005_create_provisioning_sessions.sql`
6. `006_automations_scenes_schedules.sql`
7. `007_device_management_health_observability.sql`
8. `008_notifications_alerts.sql`
9. `009_account_home_access_control.sql`
10. `010_cloud_sync_data_lifecycle.sql`
11. `011_device_fleet_ota.sql`
12. `012_energy_intelligence.sql`
13. `013_smart_energy_automation.sql`
14. `014_energy_cost_tariffs.sql`
15. `015_energy_forecasting_predictive.sql`
16. `016_presence_context_intelligence.sql`
17. `017_smart_home_intelligence.sql`
18. `018_proactive_device_reliability.sql`
19. `019_multi_protocol_connectivity.sql`
20. `020_product_discovery_catalog.sql`
21. `021_local_first_edge_control.sql`
22. `022_matter_ecosystem_interoperability.sql`
23. `023_intelligent_notifications.sql`
24. `024_secure_operations_observability.sql`
25. `025_device_trust_security.sql`
26. `026_disaster_recovery_state_resilience.sql`

---

## Operational Safeguards & Security

1. **SQL Injection Immunity**: All database queries constructed via `PostgreSQLDatabaseAdapter` use parameterized placeholders (`$1`, `$2`, ...). Identifiers (table names and column names) are strictly whitelisted against `^[a-zA-Z_][a-zA-Z0-9_]*$`.
2. **Safe Credential Masking**: Database connection strings mask password credentials in error and logging outputs.
3. **Transaction Safety**: `withTransaction()` encapsulates atomic operations with guaranteed rollback upon errors.
4. **Health Check Probes**: `OperationalReadinessService.checkDatabase()` verifies active database ping within SLA limits.
