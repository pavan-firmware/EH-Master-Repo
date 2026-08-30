# EH Home — Phase 10: Automation + Scenes + Scheduling Engine
**Production Cloud Automation, Multi-Device Scenes & Reliable Scheduler Engine**

> **STATUS**: PRODUCTION READY  
> **BASELINE**: `origin/main` (`6e70a2b`)  
> **BRANCH**: `feature/phase10-automation-scenes-schedules`

---

## 1. Architecture Overview

Phase 10 provides a cloud-native, multi-device automation, scene orchestration, and scheduling subsystem for the EH Home platform.

### Non-Negotiable Invariant
Automation and scene execution **strictly reuse the existing authenticated device command pipeline**:
```
User / Scheduler Worker
  ↓ (JWT / SYSTEM Actor Context)
HomeAuthorizationService (Home Membership & Device Authorization Guard)
  ↓
SceneService / AutomationService (Idempotency Key & Action Normalization)
  ↓
DeviceCommandService (Schema Validation, DB Transaction & Outbox Commit)
  ↓
MqttDeviceTransport (Encrypted TLS/TCP MQTT Dispatch)
  ↓
ESP32 Physical Hardware (Relay Execution)
  ↓
CommandReceipt (Published by Device)
  ↓
DeviceEventTelemetryIngestionService (DeviceState & ChannelState Convergence)
  ↓
RealtimeEventBus & SSE Stream (automation.executed & scene.executed Events)
  ↓
Flutter Mobile App (Live Execution Updates)
```
**Zero second transports, zero second command services, and zero authorization bypass paths were created.**

---

## 2. Database Schema & Migrations

**Migration Files**:
- [`backend/migrations/006_automations_scenes_schedules.sql`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/migrations/006_automations_scenes_schedules.sql)
- [`backend/migrations/006_automations_scenes_schedules.down.sql`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/migrations/006_automations_scenes_schedules.down.sql)

### Managed Tables:
1. **`scenes`**:
   - `id VARCHAR(64) PRIMARY KEY`
   - `home_id VARCHAR(64) REFERENCES homes(id) ON DELETE CASCADE`
   - `name VARCHAR(128)`, `description TEXT`, `icon VARCHAR(64)`, `is_active BOOLEAN`
   - `actions JSONB NOT NULL DEFAULT '[]'::jsonb`
   - `created_at`, `updated_at`
2. **`automations`**:
   - `id VARCHAR(64) PRIMARY KEY`
   - `home_id VARCHAR(64) REFERENCES homes(id) ON DELETE CASCADE`
   - `name VARCHAR(128)`, `description TEXT`, `is_enabled BOOLEAN`
   - `trigger_type VARCHAR(32)` (`'schedule'`, `'time'`, `'device_state'`)
   - `trigger_config JSONB`, `conditions JSONB`, `actions JSONB`, `timezone VARCHAR(64)`
   - `created_at`, `updated_at`
3. **`schedules`**:
   - `id VARCHAR(64) PRIMARY KEY`
   - `home_id VARCHAR(64) REFERENCES homes(id) ON DELETE CASCADE`
   - `automation_id VARCHAR(64) REFERENCES automations(id) ON DELETE CASCADE`
   - `scene_id VARCHAR(64) REFERENCES scenes(id) ON DELETE CASCADE`
   - `name VARCHAR(128)`, `schedule_type VARCHAR(32)` (`'one_time'`, `'daily'`, `'weekly'`, `'cron'`)
   - `cron_expression VARCHAR(64)`, `time_of_day VARCHAR(8)`, `days_of_week JSONB`, `timezone VARCHAR(64)`
   - `is_enabled BOOLEAN`, `next_run_at TIMESTAMP WITH TIME ZONE`, `last_run_at TIMESTAMP WITH TIME ZONE`
4. **`automation_execution_logs`**:
   - `id VARCHAR(64) PRIMARY KEY`
   - `home_id VARCHAR(64) REFERENCES homes(id) ON DELETE CASCADE`
   - `automation_id VARCHAR(64)`, `scene_id VARCHAR(64)`, `schedule_id VARCHAR(64)`
   - `trigger_source VARCHAR(64)`, `status VARCHAR(32)` (`'succeeded'`, `'partial'`, `'failed'`)
   - `execution_identity VARCHAR(128)` (Deterministic Idempotency Key)
   - `target_results JSONB`, `error_message TEXT`, `duration_ms INTEGER`, `executed_at TIMESTAMP`

---

## 3. Core Services & Scheduler Worker

### A. SceneService ([`backend/src/services/scene.service.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/src/services/scene.service.js))
- Orchestrates multi-device actions across target channels.
- Normalizes action payloads to canonical command contracts (`setPower`, `setLevel`, `setColorTemp`, `identifyDevice`).
- Dispatches each action independently through `DeviceCommandService` with isolated error handling.
- Emits `scene.executed` event over `RealtimeEventBus`.

### B. AutomationService ([`backend/src/services/automation.service.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/src/services/automation.service.js))
- Evaluates rules, trigger contexts, and multi-condition sets.
- **Conditions**:
  - `time_window`: Checks current time against `startTime` and `endTime` (including midnight crossovers).
  - `device_channel_state`: Checks live channel state from `DeviceStateRepository`.
  - `device_availability`: Validates device connection (`ONLINE` vs `OFFLINE`).
- Dispatches commands with deterministic execution identities (`auto_exec_<uuid>`).
- Persists structured diagnostics in `automation_execution_logs`.
- Emits `automation.executed` event over `RealtimeEventBus`.

### C. ScheduleService ([`backend/src/services/schedule.service.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/src/services/schedule.service.js))
- Calculates deterministic `nextRunAt` timestamps for:
  - **One-time** executions (auto-disables on completion).
  - **Daily** recurring schedules.
  - **Weekly** recurring schedules with arbitrary weekday bitmasks (`[1, 2, 3, 4, 5]`).
- Advances schedule run timestamps post-execution.

### D. AutomationSchedulerWorker ([`backend/src/workers/automation-scheduler-worker.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/src/workers/automation-scheduler-worker.js))
- Background worker executing a 1-second polling loop against due schedules (`findDueSchedules`).
- **Resilience Invariants**:
  - **In-memory Execution Lock**: Prevents tick overlap on slow I/O.
  - **Deterministic Idempotency Key**: Formatted as `schedule-{scheduleId}-{scheduledTimestamp}`.
  - **Worker Restart Safety**: Schedules already processed cannot execute twice.

---

## 4. REST API Endpoints

Mounted in [`backend/src/api/automation-scene.router.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/src/api/automation-scene.router.js):

| Method | Path | Description | Authorization |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/homes/:homeId/scenes` | List scenes for home | Home Membership |
| `POST`| `/api/v1/homes/:homeId/scenes` | Create new scene | Home Membership |
| `GET` | `/api/v1/homes/:homeId/scenes/:sceneId` | Get scene details | Home Membership |
| `PUT` | `/api/v1/homes/:homeId/scenes/:sceneId` | Update scene | Home Membership |
| `DELETE` | `/api/v1/homes/:homeId/scenes/:sceneId` | Delete scene | Home Membership |
| `POST`| `/api/v1/homes/:homeId/scenes/:sceneId/run` | Execute scene now | Home Membership |
| `GET` | `/api/v1/homes/:homeId/automations` | List automations | Home Membership |
| `POST`| `/api/v1/homes/:homeId/automations` | Create automation | Home Membership |
| `PATCH`| `/api/v1/homes/:homeId/automations/:id/toggle` | Enable/Disable rule | Home Membership |
| `POST`| `/api/v1/homes/:homeId/automations/:id/run` | Execute rule now | Home Membership |
| `GET` | `/api/v1/homes/:homeId/automations/:id/history` | Get rule execution history | Home Membership |
| `GET` | `/api/v1/homes/:homeId/schedules` | List schedules | Home Membership |
| `POST`| `/api/v1/homes/:homeId/schedules` | Create schedule | Home Membership |
| `PATCH`| `/api/v1/homes/:homeId/schedules/:id/toggle` | Enable/Disable schedule | Home Membership |
| `GET` | `/api/v1/homes/:homeId/automation-history` | Get home execution history | Home Membership |

---

## 5. Flutter Client Architecture

1. **Models** ([`lib/core/models/automation_models.dart`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/smart_home_application_v1/lib/core/models/automation_models.dart)):
   - `SceneModel`, `AutomationRuleModel`, `AutomationActionModel`, `ScheduleModel`, `AutomationExecutionLogModel`.
2. **Repository** ([`lib/core/repositories/cloud_automation_repository.dart`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/smart_home_application_v1/lib/core/repositories/cloud_automation_repository.dart)):
   - Implements `AutomationRepository` communicating with backend REST endpoints via authenticated `ApiClient`.
3. **UI Integration** ([`lib/features/automations/presentation/automations_page.dart`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/smart_home_application_v1/lib/features/automations/presentation/automations_page.dart)):
   - Consumer UI with full execution feedback, live toggles, and detail inspection.

---

## 6. Verification & Automated Test Coverage

- **Database Migrations Lifecycle**: `node backend/migrations/verify-migrations.js` (26/26 tables symmetric)
- **Backend Automation Tests**: `node backend/tests/phase10-automation.test.js` (6/6 passing)
- **Flutter Unit & Repository Tests**: `flutter test test/phase10_automation_test.dart` (8/8 passing)
- **Full Monorepo Integration Validation**: `node scripts/validate-repo.js` (21/21 suites passing)
- **Dart Analyzer**: `dart analyze .` (0 issues)
