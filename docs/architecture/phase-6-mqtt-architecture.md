# EH HOME — Phase 6 Transport-Neutral MQTT Architecture

- **Status:** `ACCEPTED`
- **Date:** 2026-08-25
- **Relevant Components:** `backend/src/services`, `backend/src/shared`, `firmware/common/mqtt_transport`

---

## 1. Transport Neutrality & Outbox Boundary

To prevent vendor lock-in and decouple business domain logic from communication details, all device command operations depend strictly on the `IDeviceTransport` interface.

```
API Request (Authenticated Actor Context)
      │
      ▼
HomeMembership / DeviceAuthorization Check
      │
      ▼
DeviceCommandService
      │
      ▼
DB Transaction (PostgreSQL)
  ├── Insert into device_commands (Idempotency Key Check)
  └── Insert into outbox_events
      │
      ▼
Transaction COMMIT
      │
      ▼
Outbox Processor / Transport Router
      │
      ▼
MqttDeviceTransport (Adapter)
      │
      ▼
EMQX Broker (mTLS Port 8883)
      │
      ▼
ESP32 Device (Hardware HAL)
```

Commands are **NEVER** published to the MQTT broker prior to database transaction commitment.

---

## 2. Command Receipt Correlation & Idempotency

- **Receipt Correlation**: Every `CommandReceipt` envelope contains `commandId`, matching the original `Command.commandId`.
- **Hardware Idempotency**: Devices track `deviceId + idempotencyKey` in volatile RAM / flash ring buffer. Under MQTT QoS 1 redelivery, duplicate commands produce a deterministic receipt without re-actuating hardware relays.
- **Expiration Safety**: Devices check `expiresAt` timestamp upon receipt. Expired commands produce `status: "EXPIRED"` without triggering hardware action.
