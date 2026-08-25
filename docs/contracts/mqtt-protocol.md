# EH HOME — Canonical MQTT Protocol Specification (v1.0)

- **Status:** `FROZEN`
- **Date:** 2026-08-25
- **Relevant Components:** `docs/contracts`, `backend/src/shared/mqtt-topic-builder.js`, `firmware/common/mqtt_transport`, `tools/device-simulator`

---

## 1. Topic Hierarchy & Canonical Contracts

All MQTT topics follow a strict single-namespace structure: `eh/v1/devices/{deviceId}/{category}` where `{deviceId}` is a canonical UUID format string with hyphens (36 ASCII characters).

| Topic Pattern | QoS | Retain | Publisher | Subscriber | Envelope Contract |
|---|---|---|---|---|---|
| `eh/v1/devices/{deviceId}/commands` | 1 | `false` | Backend | Device | `Command` schema |
| `eh/v1/devices/{deviceId}/command-receipts` | 1 | `false` | Device | Backend | `CommandReceipt` schema |
| `eh/v1/devices/{deviceId}/state` | 1 | `false` | Device | Backend | `DeviceState` schema |
| `eh/v1/devices/{deviceId}/events` | 1 | `false` | Device | Backend | `DeviceEvent` schema |
| `eh/v1/devices/{deviceId}/telemetry` | 0 | `false` | Device | Backend | `Telemetry` / `EnergyTelemetry` schema |
| `eh/v1/devices/{deviceId}/availability` | 1 | `true` | Device (LWT) | Backend | Availability String (`ONLINE` / `OFFLINE`) |

---

## 2. Topic Parser Rules & Wildcard Rejection

Centralized topic parsers (`MqttTopicParser` and C `mqtt_topic_parse`) must strictly enforce:
- **Wildcard Rejection**: Any topic containing `+` or `#` is immediately rejected.
- **UUID Format**: `{deviceId}` segment must match `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`.
- **Segment Length**: Exactly 5 slashes (`eh/v1/devices/{deviceId}/{category}`).
- **Invalid Category**: Categories outside `commands`, `command-receipts`, `state`, `events`, `telemetry`, `availability` are rejected.

---

## 3. Availability State Machine

```
Device State Transition:
  [Connect to Broker]
          │
          ▼
  [TLS Client Certificate Authenticated]
          │
          ▼
  [MQTT Session Accepted]
          │
          ▼
  [ACL Subscriptions Complete]
          │
          ▼
  [Publish Retained "ONLINE" to eh/v1/devices/{deviceId}/availability]
          │
          ▼
        READY

Unexpected Disconnect:
  [Broker detects TCP drop / keepalive timeout]
          │
          ▼
  [Broker publishes LWT Payload "OFFLINE" (Retained) to availability topic]

Graceful Disconnect:
  [Publish Retained "OFFLINE" to availability topic] ──► [Disconnect]

Backend Derived State:
  - ONLINE  = Received retained "ONLINE" from broker
  - OFFLINE = Received retained "OFFLINE" from broker
  - STALE   = Calculated by backend if (currentTime - lastSeenAt) > heartbeatThreshold (default 90s)
  * Note: "STALE" is NEVER published to the MQTT broker by the device.
```

---

## 4. Security & Broker ACL Permissions

### Device Principal
Each physical device authenticates using its unique X.509 client certificate provisioned during Phase 5B. The broker (EMQX) extracts `CN = deviceId`.

**ACL Permissions for Device `{deviceId}`:**
- **SUBSCRIBE**: `eh/v1/devices/{deviceId}/commands`
- **PUBLISH**:
  - `eh/v1/devices/{deviceId}/command-receipts`
  - `eh/v1/devices/{deviceId}/state`
  - `eh/v1/devices/{deviceId}/events`
  - `eh/v1/devices/{deviceId}/telemetry`
  - `eh/v1/devices/{deviceId}/availability`
- **REJECT**: Access to any topic pattern belonging to other devices (`eh/v1/devices/{otherDeviceId}/...`).

### Backend Principal
The EH Backend client authenticates as an administrative service principal:
- **SUBSCRIBE**: `eh/v1/devices/+/command-receipts`, `eh/v1/devices/+/state`, `eh/v1/devices/+/events`, `eh/v1/devices/+/telemetry`, `eh/v1/devices/+/availability`
- **PUBLISH**: `eh/v1/devices/+/commands`

---

## 5. Physical Switch Authority & Overridden Receipts

The physical wall switch is the ultimate hardware authority:
1. Physical toggle occurs → Hardware HAL actuates relay immediately.
2. Device updates `reportedState` and publishes `DeviceEvent(source="PHYSICAL_SWITCH")`.
3. If an in-flight cloud command was setting a conflicting state, the device generates a `CommandReceipt(status="OVERRIDDEN")`.
4. The backend state repository converges to the device's authoritative `reportedState`.
