# EH Home — Phase 7C Flutter Cloud Integration Architecture

## 1. Overview & Objective
Phase 7C establishes the production connection between the Flutter mobile application (`smart_home_application_v1`) and the EH Home backend cloud infrastructure.

The legacy/preview fake data sources (`FakeHomeRepository`) are bypassed in the production control path in favor of authenticated HTTP API endpoints and a persistent Server-Sent Events (SSE) realtime stream, while preserving test-time dependency injection.

---

## 2. End-to-End Control & Realtime Flows

### 2.1 Outbound Command Flow (Control Path)
```
Flutter UI (User Action)
  │
  ▼
HomeController.setLivingRoomLight(bool)
  │ (sets pending state in UI, does not assume immediate success)
  ▼
CloudHomeRepository.sendCommand(...)
  │
  ▼
ApiClient.post('/api/v1/commands/send')
  │ (Authorization: Bearer <accessToken>)
  ▼
Backend DeviceCommandRouter (JWT validation + HomeAuthorization)
  │
  ▼
DeviceCommandService
  │ (Creates Command record in PostgreSQL / Outbox)
  ▼
MqttDeviceTransport (EMQX mTLS)
  │ (Publishes to `eh/<homeId>/<deviceId>/cmd`)
  ▼
Physical Device / Device Simulator
```

### 2.2 Inbound State, Availability & Receipt Flow (Realtime Path)
```
Physical Switch Event / Actuator Confirmation
  │
  ▼
Device publishes MQTT state / receipt / LWT
  │
  ▼
EMQX Broker (Port 8883 mTLS + Per-Device ACL)
  │
  ▼
Backend DeviceEventTelemetryIngestionService
  │ (Persists state to PostgreSQL DeviceStateRepository)
  ▼
Backend RealtimeEventBus.emit(...)
  │
  ▼
RealtimeStreamRouter (GET /api/v1/homes/:homeId/stream)
  │ (SSE Event Envelope: `device.state`, `command.receipt`, `device.availability`)
  ▼
Flutter SseClient / RealtimeEventService
  │ (Parses SSEEventEnvelope, filters duplicates, tracks Last-Event-ID)
  ▼
HomeController._handleSseEvent(...)
  │
  ▼
Flutter UI (Authoritative Convergence)
```

---

## 3. Key Components Implemented in Flutter

### 3.1 `ApiClient` (`lib/core/api/api_client.dart`)
- Central HTTP wrapper handling Base URL and JSON serialization.
- Automatic injection of `Authorization: Bearer <accessToken>`.
- Transparent 401 handling with exactly one token refresh attempt via `/api/v1/auth/refresh`.
- Replays original failed request on successful token rotation.
- Emits session expiration on refresh failure to prompt re-login.

### 3.2 `AuthRepository` & `AuthController` (`lib/core/repositories/auth_repository.dart`, `lib/features/auth/auth_controller.dart`)
- Manages user credentials, PBKDF2 registration, login, and session persistence via `FlutterSecureStorage`.
- Exposes `AuthState` (`unknown`, `unauthenticated`, `authenticating`, `authenticated`, `failure`).
- Zero plaintext token leaks.

### 3.3 `CloudHomeRepository` (`lib/core/repositories/cloud_home_repository.dart`)
- Implements canonical `HomeRepository` interface.
- Maps backend REST endpoints (`/api/v1/homes`, `/api/v1/homes/:homeId/devices`, `/api/v1/commands/send`) to Flutter domain models (`DeviceSnapshot`, `CommandReceipt`).

### 3.4 `SseClient` & `RealtimeEventService` (`lib/core/api/sse_client.dart`, `lib/core/services/realtime_event_service.dart`)
- Connects to `/api/v1/homes/:homeId/stream` with Bearer auth and `Last-Event-ID` header.
- Exponential backoff reconnection loop on disconnect.
- Dispatches typed `SSEEventEnvelope` models to listening controllers.

### 3.5 `HomeController` Integration (`lib/app/home_controller.dart`)
- Subscribes to `RealtimeEventService` for `device.state`, `command.receipt`, and `device.availability`.
- Relies on authoritative backend convergence: physical switch toggles and cloud receipts update actuator confidence and relay booleans reactively.

---

## 4. Hardware Boundary Invariant
- `firmware/legacy-v1/` remains untouched.
- Physical hardware validation status: `PENDING` (tested via `tools/device-simulator/` in CI).
