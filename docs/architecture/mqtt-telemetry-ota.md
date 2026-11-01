# EH HOME — Part 13: EMQX / MQTT / Telemetry / Signed OTA Architecture

- **Status:** `ACCEPTED`
- **Version:** `1.1.0`
- **Domain:** Transport, Ingestion, Command Execution & Signed OTA
- **Authoritative Packages:** `packages/contracts`, `packages/db-schema`, `apps/api`

---

## 1. Canonical MQTT Topic Architecture

All MQTT communication across firmware, API, mobile, and simulator follows the single canonical topic hierarchy:

```
eh/v1/devices/{deviceId}/{category}
```

### Topic Categories, QoS, & Retain Policies

| Category | Direction | QoS | Retain | Description |
| :--- | :--- | :---: | :---: | :--- |
| `commands` | Backend $\to$ Device | `1` | `false` | Asynchronous command envelopes dispatched to target device |
| `command-receipts` | Device $\to$ Backend | `1` | `false` | Execution status receipt (`APPLIED`, `FAILED`, `EXPIRED`, `OVERRIDDEN`) |
| `state` | Device $\to$ Backend | `1` | `false` | Reported physical switch and channel state updates |
| `events` | Device $\to$ Backend | `1` | `false` | Discrete hardware events (e.g. physical toggle, factory reset) |
| `telemetry` | Device $\to$ Backend | `0` | `false` | High-frequency fixed-point electrical measurements |
| `availability` | Device $\to$ Broker/Backend | `1` | `true` | Retained broker connection status (`ONLINE`, `OFFLINE` LWT) |
| `ota` | Backend $\leftrightarrow$ Device | `1` | `false` | OTA job announcements, download progress, and verification status |

---

## 2. Authentication & Authorization (EMQX ACL Model)

### Security Invariants
1. **Device Isolation**: Each device client ID is strictly bound to its canonical `deviceId` UUID.
2. **Namespace Restriction**: Devices can only publish to `eh/v1/devices/${clientid}/*` and subscribe to `eh/v1/devices/${clientid}/commands` and `eh/v1/devices/${clientid}/ota`.
3. **No Wildcard Subscriptions for Devices**: Wildcards `+` and `#` are strictly prohibited for device identities.
4. **Backend Identity**: Backend ingestion services authenticate with dedicated service credentials (`backend_service_*`) authorized to subscribe to `eh/v1/devices/+/*`.

---

## 3. Telemetry Pipeline

```
ESP32 Hardware / Simulator
       │ (Fixed-Point Telemetry: v_mv, i_ma, p_w, e_tot_wh, pf_x1000, rssi_dbm)
       ▼
EMQX Broker (QoS 0, eh/v1/devices/{id}/telemetry)
       │
       ▼
MqttDeviceTransport (apps/api Ingestion Boundary)
       │
       ▼
TelemetryIngestionService
  ├── Schema Validation (FixedPointEnergyTelemetrySchema)
  ├── Range Verification (v_mv > 0, i_ma >= 0, 0 <= pf_x1000 <= 1000)
  ├── Monotonic Sequence Deduplication (Drops duplicate/out-of-order sequence numbers)
  └── Outbox Notification Enqueueing
       │
       ▼
TelemetryRepository (PostgreSQL / Drizzle ORM)
  ├── device_telemetry_measurements (Indexed timeseries storage)
  └── telemetry_aggregates (1m, 5m, 1h, 1d rollups)
```

---

## 4. Command Lifecycle & Receipt Correlation

```
Application Context (Authenticated Actor)
       │
       ▼
POST /api/v1/devices/:deviceId/commands
       │
       ▼
DeviceCommandService
  ├── Actor Authorization & Home Membership Check
  ├── Expiry Pre-Check (Rejects if expiresAt has passed)
  ├── Idempotency Key Check (Returns existing record if duplicate)
  ├── Database Transaction (device_commands + outbox)
  └── Transaction COMMIT
       │
       ▼
MqttDeviceTransport (MQTT Publish QoS 1)
       │
       ▼
ESP32 Hardware (Actuation & Ring Buffer Idempotency)
       │
       ▼
CommandReceipt (Status: APPLIED / FAILED / EXPIRED / OVERRIDDEN)
       │ (eh/v1/devices/{deviceId}/command-receipts)
       ▼
DeviceCommandService.handleCommandReceipt()
       │
       ▼
Database Update (device_commands.status + channel_state.reported_state)
```

---

## 5. Device Availability Semantics

- **ONLINE**: Published by device on successful MQTT connection (`retain: true`).
- **OFFLINE**: Published by broker as Last Will and Testament (LWT) upon ungraceful disconnect (`retain: true`) or published by device upon graceful shutdown.
- **STALE**: Derived exclusively on the backend when $(T_{current} - T_{last\_seen}) > 90\text{ seconds}$. `STALE` is an application-level health derivation and is **never** published as an MQTT topic.

---

## 6. Authoritative OTA Lifecycle State Machine

The platform enforces a single authoritative 10-state OTA lifecycle:

| State | Phase | Description | Terminal? |
| :--- | :--- | :--- | :---: |
| `REQUESTED` | Pre-flight | Job created in database, pending server security authorization | No |
| `AUTHORIZED` | Pre-flight | Multi-point security evaluation passed; download permitted | No |
| `AVAILABLE` | Pre-flight | Artifact manifest published to device topic | No |
| `DOWNLOADING` | Execution | Device is actively fetching binary chunks over HTTPS | No |
| `VERIFYING` | Execution | Download finished; device checking SHA-256 and Ed25519 signature | No |
| `INSTALLING` | Execution | Cryptographic verification passed; writing flash partition | No |
| `SUCCEEDED` | Post-flight | Boot verified & health verified; target firmware active | **Yes** |
| `FAILED` | Error | Failure at any stage with explicit errorCode & errorMessage | Non-terminal (can rollback) |
| `ROLLED_BACK` | Recovery | Reverted to previous stable boot partition | **Yes** |
| `CANCELLED` | Operator | Explicitly cancelled before download commenced | **Yes** |

### Legal Transition Graph

| From State | Allowed Next States |
| :--- | :--- |
| `REQUESTED` | `AUTHORIZED`, `FAILED`, `CANCELLED` |
| `AUTHORIZED` | `AVAILABLE`, `FAILED`, `CANCELLED` |
| `AVAILABLE` | `DOWNLOADING`, `FAILED`, `CANCELLED` |
| `DOWNLOADING` | `VERIFYING`, `FAILED` |
| `VERIFYING` | `INSTALLING`, `FAILED`, `ROLLED_BACK` |
| `INSTALLING` | `SUCCEEDED`, `FAILED`, `ROLLED_BACK` |
| `FAILED` | `ROLLED_BACK` |
| `SUCCEEDED` | *(None - Terminal)* |
| `ROLLED_BACK` | *(None - Terminal)* |
| `CANCELLED` | *(None - Terminal)* |

### Rejection Rules
- **Backwards Transitions**: Backward movement (e.g. `DOWNLOADING` $\to$ `REQUESTED` or `INSTALLING` $\to$ `DOWNLOADING`) is strictly rejected.
- **Skipping Gates**: Bypassing steps (e.g. `REQUESTED` $\to$ `INSTALLING` or `AVAILABLE` $\to$ `INSTALLING`) is rejected.
- **Terminal State Regress**: Once a terminal state is reached (`SUCCEEDED`, `ROLLED_BACK`, `CANCELLED`), no further state mutations are permitted.
- **Cancellation Boundaries**: Cancellation is only permitted from pre-download states (`REQUESTED`, `AUTHORIZED`, `AVAILABLE`).

---

## 7. Multi-Point OTA Authorization Security Gate

1. **Device Identity & Trust State**: Device must exist, have a valid UUID, and not be `REVOKED`, `DECOMMISSIONED`, or `QUARANTINED`.
2. **Release Lifecycle Status Gate**: Production OTA authorization strictly accepts canonical `RELEASED` or legacy `PUBLISHED` only.
   - `PRODUCTION_READY` is **NOT** a production OTA authorization state and is strictly rejected.
   - `DRAFT`, `BUILDING`, `VALIDATION`, `APPROVED`, `DEPRECATED`, `RETIRED`, `REVOKED`, or missing/unknown statuses fail closed with `OTA_AUTH_LIFECYCLE_NOT_RELEASED`.
3. **Firmware Family Compatibility**: Release firmware family must match the product variant / platform.
4. **Hardware Revision Gate**: Device PCB revision (`HW_1_0`, `HW_1_1`) must match the compatible revisions of the release.
5. **Target MCU Architecture Gate**: Device MCU must match the release target exactly (`esp32-c6` for switches/sockets, `esp32-s3` for hub gateways). Prototype generic `esp32`, unsupported architectures, missing MCU values, or cross-target mismatches (`esp32-c6` vs `esp32-s3`) fail closed with `OTA_AUTH_TARGET_MISMATCH`.
6. **Cryptographic Integrity & Signature Presence**: Valid 128-char hex Ed25519 signature and 64-char hex SHA-256 digest are mandatory (fail-closed).
7. **Anti-Rollback Rule**: Target version must be strictly greater than current version ($\text{targetVersion} > \text{fromVersion}$).
8. **Bridge Version Requirement**: If release specifies `minFirmwareVersion`, device current version must be $\ge \text{minFirmwareVersion}$.

---

## 8. Local EMQX Development & Integration Testing

### Docker Broker Management
```bash
# 1. Start EMQX Broker
docker compose up -d emqx

# 2. Execute Live Integration Test
node scripts/test-emqx-live.js
# Or via npm:
npm run test:part13-emqx

# 3. Teardown
docker compose down
```

### Test Classification Hierarchy
- **Mock Transport Tests**: Executed in unit/CI suites via `MockMqttClient` in `apps/api/tests/mqtt-telemetry-ota.test.js` (26/26 passing).
- **Live EMQX Integration Tests**: Executed against local EMQX container in `apps/api/tests/emqx-live-integration.test.js` covering authentication, telemetry, commands, receipts, availability, OTA lifecycle, and multi-device ACL isolation.
- **Physical Hardware Tests**: ESP32-C6 / ESP32-S3 physical bench testing (requires hardware devices).
