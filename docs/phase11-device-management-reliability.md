# EH Home — Phase 11: Device Management, Reliability & Observability
**Production Device Lifecycle, Unified Health, Diagnostics & Observability Engine**

> **STATUS**: PRODUCTION READY  
> **BASELINE**: `origin/main` (`c7ef916`)  
> **BRANCH**: `feature/phase11-device-management-reliability`

---

## 1. Architecture Overview

Phase 11 delivers an enterprise-grade device management, reliability, and observability subsystem for EH Home.

### Non-Negotiable Invariants & Reused Foundations
1. **Authenticated Command & Ingestion Pipeline**:
   ```
   User / Cloud Request
     ↓ (Bearer JWT Token)
   HomeAuthorizationService (Home Membership & Device Authorization Guard)
     ↓
   DeviceManagementService (Domain Validation & Lifecycle Orchestration)
     ↓
   DeviceCommandService (Schema, DB Transaction & Outbox Commit)
     ↓
   MqttDeviceTransport (mTLS Port 8883 / EMQX 5.8 Broker)
     ↓
   ESP32 Physical Hardware
     ↓
   CommandReceipt & DeviceState (Published by Device)
     ↓
   DeviceEventTelemetryIngestionService (Convergence to Database Truth)
     ↓
   RealtimeEventBus & SSE Stream (device.updated, device.removed, device.activity)
     ↓
   Flutter Mobile Client (Realtime UI Synchronization)
   ```
2. **Zero Second Transports**: Reuses official `MqttDeviceTransport` and `RealtimeEventBus`.
3. **Zero Secret Leakage**: Wi-Fi credentials, private keys, JWT secrets, and provisioning secrets are never logged or exposed via diagnostic APIs.
4. **Factory Reset Boundary**: User unclaiming / device removal strictly alters home authorization only; immutable physical factory identity (`fact_v2`) is never erased remotely.

---

## 2. Database Schema & Migrations

**Migration Files**:
- [`backend/migrations/007_device_management_health_observability.sql`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/migrations/007_device_management_health_observability.sql)
- [`backend/migrations/007_device_management_health_observability.down.sql`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/migrations/007_device_management_health_observability.down.sql)

### Managed Tables Added:
1. **`device_activity_logs`**:
   - `id VARCHAR(64) PRIMARY KEY`
   - `home_id VARCHAR(64) REFERENCES homes(id) ON DELETE CASCADE`
   - `device_id VARCHAR(64) REFERENCES devices(id) ON DELETE CASCADE`
   - `event_type VARCHAR(64) NOT NULL` (`connected`, `disconnected`, `state_changed`, `command_applied`, `command_failed`, `device_renamed`, `device_moved`, `device_removed`, `error`)
   - `severity VARCHAR(16) DEFAULT 'info'` (`info`, `warn`, `error`)
   - `message TEXT NOT NULL`
   - `correlation_id VARCHAR(128)`
   - `details JSONB DEFAULT '{}'::jsonb`
   - `created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()`
2. **`device_health_metrics`**:
   - `id VARCHAR(64) PRIMARY KEY`
   - `device_id VARCHAR(64) UNIQUE REFERENCES devices(id) ON DELETE CASCADE`
   - `home_id VARCHAR(64) REFERENCES homes(id) ON DELETE CASCADE`
   - `health_status VARCHAR(32) DEFAULT 'UNKNOWN'` (`ONLINE`, `OFFLINE`, `STALE`, `DEGRADED`, `ERROR`, `UNKNOWN`)
   - `last_seen_at TIMESTAMP WITH TIME ZONE`
   - `uptime_seconds INTEGER DEFAULT 0`
   - `rssi INTEGER`
   - `ip_address VARCHAR(45)`
   - `command_success_count INTEGER DEFAULT 0`
   - `command_failure_count INTEGER DEFAULT 0`
   - `last_error_message TEXT`
   - `last_error_at TIMESTAMP WITH TIME ZONE`
   - `updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()`

---

## 3. Core Services & Features

### A. DeviceManagementService ([`backend/src/services/device-management.service.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/src/services/device-management.service.js))
- **`getDeviceDetails`**: Resolves physical device identity, product variant, metadata, room, floor, custom name, firmware, hardware revision, channel configuration, capabilities, live health, and OTA status without secret leakage.
- **`renameDevice`**: Validates friendly names (1-64 chars), updates database, records activity log, and publishes `device.updated` SSE event.
- **`moveDevice`**: Moves device to target room within the home, validates room ownership, records activity log, and publishes `device.updated` SSE event.
- **`removeDeviceFromHome`**: Removes `device_authorizations`, sets connection state to `OFFLINE`, publishes `device.removed` SSE event, and preserves immutable factory identity.
- **`calculateDeviceHealth`**: Computes unified health status (`ONLINE`, `OFFLINE`, `STALE`, `DEGRADED`, `ERROR`, `UNKNOWN`) combining heartbeat freshness and command success ratios.
- **`getDeviceActivityHistory`**: Returns chronological activity and audit logs for the device.
- **`getDeviceDiagnostics`**: Technical diagnostics (connection state, last heartbeat, command success/failure stats, safe protocol metadata).

---

## 4. REST API Endpoints

Mounted in [`backend/src/api/device-management.router.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/src/api/device-management.router.js):

| Method | Path | Description | Authorization |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/health/liveness` | Service liveness probe | Public |
| `GET` | `/api/v1/health/readiness` | Database & dependency readiness probe | Public |
| `GET` | `/api/v1/health` | Comprehensive system health & dependency status | Public |
| `GET` | `/api/v1/health/diagnostics` | Deep diagnostic status for DB, MQTT & workers | Public |
| `GET` | `/api/v1/homes/:homeId/devices/:deviceId/details` | Complete device details & health | Home Membership & Device Auth |
| `GET` | `/api/v1/homes/:homeId/devices/:deviceId/health` | Device health metrics | Home Membership & Device Auth |
| `GET` | `/api/v1/homes/:homeId/devices/:deviceId/diagnostics` | Technical diagnostics | Home Membership & Device Auth |
| `GET` | `/api/v1/homes/:homeId/devices/:deviceId/activity` | Device activity history | Home Membership & Device Auth |
| `PATCH`| `/api/v1/homes/:homeId/devices/:deviceId/rename` | Rename device friendly name | Home Membership & Device Auth |
| `PATCH`| `/api/v1/homes/:homeId/devices/:deviceId/move` | Move device to different room | Home Membership & Device Auth |
| `DELETE`| `/api/v1/homes/:homeId/devices/:deviceId` | Remove device from home (unclaim) | Home Membership & Device Auth |

---

## 5. Flutter Client Integration

1. **Models** ([`lib/core/models/device_management_models.dart`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/smart_home_application_v1/lib/core/models/device_management_models.dart)):
   - `DeviceDetailsModel`, `DeviceHealthMetricsModel`, `DeviceActivityLogItemModel`, `DeviceOtaInfo`.
2. **Repository** ([`lib/core/repositories/cloud_device_management_repository.dart`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/smart_home_application_v1/lib/core/repositories/cloud_device_management_repository.dart)):
   - Implements `DeviceManagementRepository` with authenticated `ApiClient`.
3. **UI Implementation** ([`lib/features/diagnostics/presentation/device_management_page.dart`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/smart_home_application_v1/lib/features/diagnostics/presentation/device_management_page.dart)):
   - Consumer-grade UI displaying health status, hardware revision, firmware version, rename dialog, remove confirmation, and activity history stream.

---

## 6. Validation & Test Coverage

- **Database Migrations Lifecycle**: `node backend/migrations/verify-migrations.js` (28/28 tables symmetric UP & DOWN)
- **Backend Device Management Tests**: `node backend/tests/phase11-device-management.test.js` (7/7 passing)
- **Flutter Phase 11 Tests**: `flutter test test/phase11_device_management_test.dart` (4/4 passing)
- **Full Monorepo Integration Validation**: `node scripts/validate-repo.js` (22/22 suites passing)
- **Flutter Analyzer**: `dart analyze .` (0 issues)
- **Flutter Full Test Suite**: `flutter test` (115/115 passing)
