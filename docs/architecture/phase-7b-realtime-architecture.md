# EH HOME — Phase 7B Realtime SSE & Worker Architecture Specification

- **Status:** `ACCEPTED`
- **Date:** 2026-08-26
- **Relevant Components:** `backend/src/services/realtime-event-bus.js`, `backend/src/api/realtime-stream.router.js`, `backend/src/workers/`, `packages/contracts`

---

## 1. End-to-End Realtime Event Flow

```
ESP32 / Device Simulator
       │
       ▼ (MQTT over mTLS Port 8883)
  EMQX Broker
       │
       ▼ (QoS 1 State / Event Ingestion)
MqttDeviceTransport (backend)
       │
       ▼
DeviceEventTelemetryIngestionService / DeviceCommandService
       │
       ▼
PostgreSQL / Relational DB Transaction COMMIT (Authoritative State)
       │
       ▼
RealtimeEventBus.publish({ homeId, eventType, payload })
       │
       ▼
SSE Connection Router (GET /api/v1/homes/:homeId/stream)
       │
       ▼ (HTTP text/event-stream)
App Clients / Subscribed Listeners
```

---

## 2. Realtime Event Envelope (`SSEEventEnvelope`)

All SSE events follow canonical contract formatting:

```json
{
  "schemaVersion": 1,
  "eventId": "0194fe23-7a1b-7890-a123-sse000000001",
  "type": "device.state",
  "occurredAt": "2026-08-26T17:00:00.000Z",
  "homeId": "0194fe23-7a1b-7890-a123-home0000000a",
  "deviceId": "0194fe23-7a1b-7890-a123-45678900000a",
  "payload": {
    "connectionState": "ONLINE",
    "channels": [
      { "channelIndex": 1, "reportedState": { "power": true }, "confidence": "CONFIRMED" }
    ]
  }
}
```

### Initial Event Types
- `device.state`: Authoritative device state updates
- `device.event`: Hardware physical switch toggle events
- `device.availability`: LWT and STALE heartbeat connection state changes
- `command.receipt`: Device command ACK / APPLIED / FAILED / TIMEOUT receipts
- `telemetry.update`: Sensor and energy telemetry reports

---

## 3. Background Workers Responsibilities

| Worker | File | Frequency | Responsibility |
|---|---|---|---|
| Device STALE Detector | `device-stale-detector.js` | 15s | Identifies devices where `lastSeenAt` exceeds 45s, sets `OFFLINE`/`STALE`, and emits `device.availability` event |
| Command Timeout Worker | `command-timeout-worker.js` | 10s | Finds `SENT`/`CREATED` commands past `expiresAt`, transitions status to `TIMEOUT`/`EXPIRED`, emits `command.receipt` event |
| Outbox Retry Worker | `outbox-retry-worker.js` | 5s | Retries pending `outbox` records with exponential backoff up to max retry attempts |
| Worker Runner | `worker-runner.js` | — | Lifecycle runner supporting clean start, stop, and graceful shutdown |
