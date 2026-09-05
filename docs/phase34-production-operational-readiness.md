# EH Home — Phase 34 Production Deployment & Operational Readiness Runbook

## Executive Overview
Phase 34 establishes the production-operable runtime operations, deterministic deployment, health probing, graceful lifecycle management, and administrative diagnostics layer for the EH Home platform (`pavan-firmware/EH-Master-Repo`).

---

## 1. Runtime Configuration Model

### Configuration Classification Matrix

| Key | Type | Requirement | Default (Dev/Test) | Production Invariant | Secret? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `NODE_ENV` | `string` | **REQUIRED** | `development` | Must be `production` | No |
| `PORT` | `number` | **REQUIRED** | `3000` | Range 1-65535 | No |
| `HOST` | `string` | **REQUIRED** | `127.0.0.1` | Must be `0.0.0.0` or explicit IP | No |
| `DATABASE_URL` | `string` | **REQUIRED** | Auto / Local | Must NOT be loopback/127.0.0.1/192.168.x.x | **YES** |
| `REDIS_URL` | `string` | **REQUIRED in Prod** | `null` | Must NOT be loopback/LAN IP | **YES** |
| `MQTT_BROKER_URL` | `string` | **REQUIRED in Prod** | `null` | Must NOT be loopback/LAN IP (`tls://`) | No |
| `MQTT_TLS_PORT` | `number` | **OPTIONAL** | `8883` | Range 1-65535 | No |
| `JWT_PRIVATE_KEY_PATH` | `string` | **REQUIRED in Prod** | `null` | Must point to mounted secret file | **YES** (Path) |
| `JWT_PUBLIC_KEY_PATH` | `string` | **REQUIRED in Prod** | `null` | Must point to mounted secret file | No |
| `MQTT_CA_PATH` | `string` | **REQUIRED in Prod** | `null` | Must point to valid CA cert | No |
| `SESSION_SECRET` | `string` | **OPTIONAL** | `dev_session_secret` | Weak secrets rejected in prod | **YES** |
| `JWT_SECRET` | `string` | **OPTIONAL in Dev** | `dev_jwt_secret` | Disallowed in prod (keypair required) | **YES** |
| `LOG_LEVEL` | `string` | **OPTIONAL** | `info` | `debug`, `info`, `warn`, `error` | No |
| `SHUTDOWN_TIMEOUT_MS` | `number` | **OPTIONAL** | `10000` | Range 1000-60000 ms | No |
| `HEALTH_CHECK_TIMEOUT_MS` | `number` | **OPTIONAL** | `1500` | Range 100-10000 ms | No |
| `ENABLE_DEBUG_ROUTES` | `boolean` | **DISALLOWED in Prod** | `false` | Must be `false` in production | No |
| `MOCK_TRANSPORTS` | `boolean` | **DISALLOWED in Prod** | `false` | Must be `false` in production | No |

---

## 2. Application Startup & Lifecycle Management

```mermaid
stateDiagram-v2
    [*] --> UNINITIALIZED
    UNINITIALIZED --> STARTING: Boot process initiated
    STARTING --> INITIALIZING: Configuration validated & DB connected
    INITIALIZING --> READY: All required & optional dependencies healthy
    INITIALIZING --> DEGRADED: Required DB healthy, optional Redis/MQTT offline
    INITIALIZING --> FAILED: Required configuration or DB connection fails
    READY --> SHUTTING_DOWN: SIGTERM / SIGINT signal received
    DEGRADED --> SHUTTING_DOWN: SIGTERM / SIGINT signal received
    SHUTTING_DOWN --> TERMINATED: In-flight requests drained, resources closed
    TERMINATED --> [*]
    FAILED --> [*]
```

### Startup Sequence
1. **Load Configuration**: Read process environment variables and validate against runtime schema.
2. **Pre-Flight Validation**: Fail fast if `NODE_ENV=production` and any required variable is missing or violates production invariants (e.g. loopback IP, weak secret, or debug bypass).
3. **Initialize Database Client**: Connect to PostgreSQL and verify migration version (current: `026_disaster_recovery_state_resilience`, 98 tables).
4. **Initialize Platform Services**: Core domain, authentication, RBAC, audit, and recovery services.
5. **Initialize Optional Integrations**: Connect to Redis and MQTT. If unavailable, mark readiness as `DEGRADED` instead of crashing.
6. **Register API Routes & Probes**: Mount `/health/*` and `/api/v1/*` endpoints.
7. **Mark Service READY**: Begin accepting customer traffic.

---

## 3. Health & Readiness Probes

### Endpoint Reference

| Endpoint | Target Consumer | Purpose | Status Codes | Response Structure |
| :--- | :--- | :--- | :--- | :--- |
| `GET /health/liveness`<br>`GET /api/v1/health/liveness` | Kubernetes / Docker / Load Balancer | Process Liveness (Is the Node process alive?) | `200` | `{"status":"UP","service":"eh-home-backend","uptimeSeconds":120}` |
| `GET /health/readiness`<br>`GET /api/v1/health/readiness` | Load Balancer / Ingress Gateway | Request Serving Readiness (Can the service accept traffic?) | `200` (READY/DEGRADED)<br>`503` (NOT_READY) | `{"status":"READY","checks":{"database":"PASS","redis":"PASS","mqtt":"PASS"}}` |
| `GET /health/startup`<br>`GET /api/v1/health/startup` | Container Runtime | Container Startup Probe | `200` (INITIALIZED)<br>`503` (STARTING) | `{"status":"INITIALIZED","isInitialized":true}` |
| `GET /health`<br>`GET /api/v1/health` | Operators / Monitoring | Shallow Health Summary | `200` (OK)<br>`503` (UNHEALTHY) | `{"success":true,"data":{"status":"READY"}}` |
| `GET /api/v1/admin/operations/diagnostics` | Authorized Admins | Comprehensive Operational Telemetry | `200` (Authorized)<br>`401` / `403` (Forbidden) | `{"success":true,"data":{...release, process, dependencies}}` |

### Dependency Failure Interpretation Matrix

| Dependency | Classification | Failure Symptom | System Behavior | Liveness | Readiness |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **PostgreSQL Database** | **REQUIRED** | Connection refused / Pool timeout | Service cannot read/write domain state | `200 UP` | `503 NOT_READY` |
| **Redis Cache / Lock** | **OPTIONAL** | Host unreachable / Timeout | Cache falls back to local memory; distributed locks degrade safely | `200 UP` | `200 DEGRADED` |
| **MQTT Broker** | **OPTIONAL** | Broker disconnect / mTLS failure | Real-time device push degraded; API commands queued or rejected with clear code | `200 UP` | `200 DEGRADED` |
| **Background Workers** | **OPTIONAL** | Worker error / Unhandled rejection | Scheduled jobs temporarily stalled | `200 UP` | `200 DEGRADED` |

---

## 4. Graceful Shutdown & Drain Policy

When receiving `SIGTERM` or `SIGINT`:
1. **Lifecycle Transition**: Service immediately transitions `lifecycleState` to `SHUTTING_DOWN`.
2. **Readiness Probe Fail**: `/health/readiness` immediately begins returning `503 NOT_READY`, causing load balancers to route new incoming traffic away.
3. **HTTP Server Close**: Stop accepting new HTTP connections while allowing existing in-flight requests to complete.
4. **Service Clean Disconnects**: Cleanly disconnect MQTT transport, flush audit logs, and close database connection pool.
5. **Timeout Safeguard**: If clean shutdown does not complete within `SHUTDOWN_TIMEOUT_MS` (default 10s), process forces exit with status code 1.
6. **Clean Exit**: Once all resources close, process exits cleanly with status code 0.

---

## 5. Security & Zero Secret Exposure Invariants

1. **Boundary Sanitization**: Connection strings in logs and error responses are automatically redacted (`postgres://***:***@host:port/db`).
2. **Diagnostics Redaction**: `GET /api/v1/admin/operations/diagnostics` and `toSafeConfig()` omit all JWT private keys, session secrets, database passwords, and API keys.
3. **RBAC Isolation**: Public probes (`/health/liveness`, `/health/readiness`) expose zero infrastructure topology details or connection parameters.
4. **Phase 32 Authority**: Device trust, revocations, and credential expirations remain strictly authoritative.
5. **Phase 33 DR Handoff**: Operational readiness probes do not trigger or alter disaster recovery manifests or snapshots.

---

## 6. Migration Policy & Rollback Considerations

- **Phase 34 Database Policy**: Migration-free. Operational health, lifecycle states, and telemetry are maintained as dynamic in-memory constructs without persistent table overhead.
- **Migration Level**: Verified at `026_disaster_recovery_state_resilience` managing 98 tables.
- **Rollback Procedure**: Reverting backend binaries to Phase 33 does not require database down-migrations or table drops.
