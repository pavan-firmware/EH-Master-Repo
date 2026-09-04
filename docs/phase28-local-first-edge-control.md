# Phase 28 — Local-First Home Control & Edge Execution Platform

## 1. Architecture Overview

Phase 28 establishes a production-grade **Local-First Home Control and Edge Execution** architecture for the EH Home ecosystem.

### Core Principle
In-home device control continues seamlessly without interruption when the Internet or EH Cloud is unavailable. The application automatically decides the best execution route (`LOCAL`, `CLOUD`, `DEFERRED`, or `UNAVAILABLE`) without ever requiring the consumer to manually choose between Local or Cloud modes.

```
+-------------------------------------------------------------------------------+
|                             Flutter Application                               |
|   - Consumer UI / Dashboard (Subtle LocalModeIndicator: Local / Cloud / Off)  |
|   - Deterministic State Machine (Pending -> Confirmed / Failed / Offline)      |
+---------------------------------------+---------------------------------------+
                                        |
                         Automatic Execution Router
                                        |
           +----------------------------+----------------------------+
           | Phone on Home LAN                                       | Outside Home LAN
           v                                                         v
+-------------------------------+                         +---------------------+
|      Local Execution Path     |                         |  EH Cloud Services  |
| - mDNS / SSDP Discovery Node  |                         |  - Remote Control   |
| - CoAP / Local MQTT / Matter  |                         |  - Cloud Sync Outbox|
| - Sub-20ms Direct Dispatch    |                         |  - Fleet Telemetry  |
+---------------+---------------+                         +----------+----------+
                |                                                    |
                +----------------------------+-----------------------+
                                             |
                                             v
                              +-----------------------------+
                              |   Physical Hardware Device  |
                              | - Authoritative State       |
                              | - Physical Switch Override  |
                              | - Local Hardware Execution  |
                              +-----------------------------+
```

---

## 2. Canonical Contracts & Schemas

Exported in `packages/contracts/edge/`:
1. `local-execution-request.schema.json`: Unified payload for local direct command dispatch.
2. `execution-route-decision.schema.json`: Deterministic routing decision envelope with confidence score and reasons.
3. `local-connectivity-state.schema.json`: Real-time LAN reachability and transport summary.
4. `local-device-discovery.schema.json`: LAN discovered node advertisement with cryptographic fingerprint.
5. `local-execution-result.schema.json`: Execution outcome with latency, route mode, and physical confirmation state.
6. `local-state-event.schema.json`: Real-time state event emitted locally without internet.
7. `edge-automation-execution.schema.json`: Offline edge scene, schedule, and automation execution record.

---

## 3. Database Schema

Database Migration `021_local_first_edge_control.sql` introduces 3 managed relational tables:

1. **`local_route_cache`**:
   - Stores fast IP:Port endpoints, transport types, reachability status (`REACHABLE`, `DEGRADED`, `UNREACHABLE`), identity fingerprints, and latency metrics.
2. **`edge_execution_records`**:
   - Records execution audit logs, route mode (`LOCAL`, `CLOUD`, `DEFERRED`), physical confirmation boolean, and hardware receipt state.
3. **`local_discovery_nodes`**:
   - Tracks discovered nodes on the local subnet, hardware MAC, advertised protocols, and cryptographic trust flags (`is_trusted`).

---

## 4. Backend Services & Pipeline

1. **`ExecutionRoutingService`**:
   - Automatically determines `LOCAL` vs `CLOUD` vs `DEFERRED` vs `UNAVAILABLE` route based on user presence, local cache reachability, transport health, and cloud reachability.
2. **`LocalExecutionService`**:
   - Dispatches direct local commands with idempotency and anti-replay guards.
   - Requires physical device state confirmation before reporting `CONFIRMED`.
   - Automatically falls back to cloud routing if local transport experiences socket timeout.
3. **`LocalDiscoveryService`**:
   - Discovers LAN nodes and validates cryptographic identity fingerprints.
   - Rejects rogue or unauthenticated devices trying to claim ownership on the local subnet.
4. **`EdgeAutomationService`**:
   - Executes offline scenes, schedules, and local rules with graceful partial-failure handling.
   - Enforces the authority hierarchy: `Physical Manual Switch > Consumer App > Local Automation > Schedule`.

---

## 5. Mobile / Flutter Client

- **`EdgeControlService`**: Client ChangeNotifier handling auto-routing requests, local status caching, LAN discovery, and offline sync.
- **`LocalModeIndicator`**: Subtle status badge (`Local Fast`, `Cloud Sync`, `Offline`) with zero technical jargon.
- **`EdgeDeviceControlCard`**: Physical confirmation card handling `Pending -> Confirmed -> Failed -> Offline` states.
- **`EdgeExecutionDashboardPage`**: Full diagnostic and metrics view for local performance and discovered LAN nodes.
