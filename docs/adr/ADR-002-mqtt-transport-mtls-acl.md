# ADR-002: Transport-Neutral MQTT, mTLS & Per-Device ACL Architecture

- **Status:** `ACCEPTED`
- **Date:** 2026-08-26
- **Author:** EH Home Platform Architecture Team
- **Relevant Components:** `docs/architecture`, `backend/src/services`, `backend/src/shared`, `tools/device-simulator`, `scripts/setup-emqx-mtls.js`

---

## 1. Context & Problem Statement

Phase 6 required a secure, production-grade transport layer connecting backend services to physical IoT devices. The transport must guarantee:
1. **Device Identity Verification**: Strict mutual TLS (mTLS) X.509 client certificate authentication.
2. **Access Control (ACL)**: Per-device topic isolation where Device A cannot publish or subscribe to Device B's topics, nor spoof another device's client ID.
3. **Transport Neutrality**: Backend business services (commands, state, events) must depend on an interface abstraction (`IDeviceTransport`), avoiding vendor lock-in to MQTT.
4. **Transactional Safety**: Commands must never be published to the message broker before database transactions are fully committed.

---

## 2. Decision

We formalize the **Phase 6 MQTT & mTLS Transport Architecture**:

### A. Strict mTLS & Certificate Identity Mapping
- **Port 8883 (mTLS Listener)**: Configured in EMQX with `verify = verify_peer` and `fail_if_no_peer_cert = true`.
- **Identity Extraction**: Device client certificate Common Name (CN) is strictly mapped to `deviceId`.
- **Client ID Matching**: MQTT ClientId must match the client certificate CN (`%c`), preventing ClientId spoofing attacks.

### B. Deny-By-Default ACL Policy
- **Authorization Source**: File-based authorizer (`acl.conf`) managed dynamically in EMQX.
- **Topic Isolation**:
  - `eh/devices/${cert_common_name}/commands` — Device can subscribe to commands addressed to itself.
  - `eh/devices/${cert_common_name}/receipts` — Device can publish command execution receipts.
  - `eh/devices/${cert_common_name}/state` — Device can publish state updates.
  - `eh/devices/${cert_common_name}/events` — Device can publish event logs.
  - `eh/devices/${cert_common_name}/telemetry` — Device can publish energy/sensor telemetry.
  - `eh/devices/${cert_common_name}/availability` — Device can publish LWT status.
- **Default Deny**: `authorization.no_match = deny` enforced at the EMQX broker level.

### C. Outbox Pattern & Transactional Boundary
- Backend command processing writes to `device_commands` and `outbox` in a single PostgreSQL transaction.
- `MqttDeviceTransport` processes outbox events asynchronously after transaction commitment (`COMMIT`).

---

## 3. Rationale

- **Zero Trust Messaging**: Even if an attacker gains access to one device certificate, they cannot inspect or tamper with traffic for any other device in the system.
- **Hardware Idempotency**: QoS 1 redelivery with idempotency key checks guarantees that duplicate messages will not trigger duplicate hardware relay toggles.

---

## 4. Consequences & Status

- **Status**: `ACCEPTED` — Merged into `main` in Phase 6. All integration tests pass in CI.
