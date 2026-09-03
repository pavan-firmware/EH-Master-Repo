# Phase 26 — Multi-Protocol Device Connectivity & Interoperability

## 1. Overview & Architecture

Phase 26 introduces a protocol-neutral device connectivity layer into the EH Home smart home platform. This layer abstracts and unifies device transports across:
- **Wi-Fi / MQTT**: Authoritative for existing and deployed ESP32/EH hardware.
- **Bluetooth Low Energy (BLE)**: Proximity commissioning, beaconing, and direct local controls.
- **Thread Mesh**: Ultra-low-power IPv6 802.15.4 mesh networking.
- **Matter**: Unified application layer over Thread and Wi-Fi fabrics.

The connectivity layer operates alongside existing services (`DeviceCommandService`, `DeviceEventTelemetryIngestionService`, `ReliabilityService`, `RealtimeEventBus`) without creating duplicate command pipelines, parallel state stores, or second device registries.

---

## 2. Core Components

### 2.1 Transport Abstraction & Adapters
Each protocol implements the canonical `IDeviceTransport` lifecycle:
- `connect(deviceId)` & `disconnect(deviceId)`
- `probeAvailability(deviceId)`
- `sendCommand(cmd)`
- `getState(deviceId)`
- `requestTelemetry(deviceId)`
- `getHealth(deviceId)`
- `getCapabilities()`

**Implemented Adapters:**
- `WifiMqttTransportAdapter`: Direct IP, non-mesh, 64KB max payload, default priority rank 1.
- `BleTransportAdapter`: Local-only, low-power, 512B max payload, default priority rank 4.
- `ThreadTransportAdapter`: IPv6 mesh, low-power, 1280B MTU, default priority rank 3.
- `MatterTransportAdapter`: Local IPv6/mesh, interoperable, 64KB max payload, default priority rank 2.

### 2.2 Deterministic Transport Selection
When dispatching commands or reading device states, `ConnectivityService.selectTransport()` calculates the optimal route using:
1. Active transport preference
2. Supported transport status in device catalog/transports
3. Priority rank ordering
4. Historical latency and error rates
5. Transport availability probes

The selection returns a confidence score (0.00 – 1.00) and an explicit ordered fallback list.

### 2.3 Safe Fallback Execution
To guarantee zero accidental duplicate operations on non-idempotent device commands (e.g. toggles, door locks):
1. Command is dispatched to primary transport.
2. If primary transport rejects or times out:
   - Device state is cross-checked against `DeviceStateRepository`.
   - Next permitted fallback transport is selected.
   - Command is executed once on fallback.
   - Connection state and active transport are updated.

### 2.4 Connection Lifecycle State Machine
Devices transition through explicit states:
`DISCOVERING` $\to$ `COMMISSIONING` $\to$ `CONNECTING` $\to$ `CONNECTED` $\to$ `DEGRADED` $\to$ `RECONNECTING` $\to$ `DISCONNECTED` $\to$ `FAILED` $\to$ `DECOMMISSIONED`

State changes emit real-time events on `RealtimeEventBus` (`transport.connected`, `transport.disconnected`, `transport.changed`, `transport.health_changed`).

### 2.5 Protocol-Neutral Discovery & Commissioning
Commissioning follows a 7-stage deterministic pipeline:
1. `DISCOVERED`
2. `READY`
3. `STARTED`
4. `AUTHENTICATING`
5. `NETWORK_JOINING`
6. `VERIFYING`
7. `COMPLETED` (or `FAILED` / `CANCELLED`)

---

## 3. Database Schema (Migration 019)

Four tables added bringing the monorepo total to **73 managed tables**:
1. `device_transports`: Configured transports, priority ranks, active flags, transport config.
2. `device_connection_states`: Current active transport, connection state, reconnect counts, timestamps.
3. `commissioning_sessions`: Stage timeline, auth methods, failure reasons, session durations.
4. `transport_health_snapshots`: Latency, error rate, availability, RSSI, telemetry metrics.

---

## 4. REST API Endpoints

All endpoints are RBAC-protected via `HomeAuthorizationService`:
| Method | Route | Description |
|---|---|---|
| `GET` | `/api/v1/connectivity/homes/:homeId/devices` | Fleet connectivity summary & state distribution |
| `GET` | `/api/v1/connectivity/devices/:deviceId` | Device connection snapshot & active transport |
| `GET` | `/api/v1/connectivity/devices/:deviceId/transports` | Device configured transports & capabilities |
| `GET` | `/api/v1/connectivity/devices/:deviceId/health` | Multi-transport health snapshot & metrics |
| `GET` | `/api/v1/connectivity/devices/:deviceId/commissioning` | Device commissioning session history |
| `POST` | `/api/v1/connectivity/devices/:deviceId/reconnect` | Trigger reconnection signal |
| `POST` | `/api/v1/connectivity/devices/:deviceId/select-transport` | Force active transport selection |
| `GET` | `/api/v1/connectivity/discovery` | Scan & discover commissionable devices |
| `POST` | `/api/v1/connectivity/commissioning/start` | Start new commissioning session |
| `POST` | `/api/v1/connectivity/commissioning/cancel` | Cancel in-progress commissioning session |

---

## 5. Mobile / Flutter Client

- **Models**: `DeviceTransportType`, `TransportAvailability`, `DeviceConnectionState`, `CommissioningStage`, `TransportCapability`, `TransportHealth`, `DeviceConnectionSnapshot`, `CommissioningSession`, `FleetConnectivitySummary`.
- **Service**: `ConnectivityService` with caching, notifications, and async REST actions.
- **UI Components**:
  - `DeviceConnectivityPage`: Active transport hero, connection status, reconnect, protocol breakdown.
  - `TransportDetailsPage`: Technical protocol inspection (direct IP, mesh, low power, payload).
  - `CommissioningStatusPage`: 7-step pipeline timeline with cancel dialog.
  - `TransportHealthCard`: Reusable latency, RSSI, and error rate card.
  - `TransportSelector`: ChoiceChip protocol selector.
