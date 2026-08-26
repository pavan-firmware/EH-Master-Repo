# ADR-004: Phase 7B Server-Sent Events (SSE) Realtime Architecture & Background Workers

- **Status:** `ACCEPTED`
- **Date:** 2026-08-26
- **Author:** EH Home Platform Architecture Team
- **Relevant Components:** `backend/src/services/realtime-event-bus.js`, `backend/src/api/realtime-stream.router.js`, `backend/src/workers/`, `packages/contracts`

---

## 1. Context & Problem Statement

Phase 7A established production HTTP REST APIs, RS256 JWT user authentication, and tenant-scoped home membership authorization.
However, state changes resulting from physical hardware toggles, command receipts, or device telemetry are ingested by the backend over MQTT and written to PostgreSQL/MemoryDB, but are not pushed to connected app clients in real time.
Mobile app clients require low-latency state updates without inefficient HTTP polling.

---

## 2. Decision

We adopt **Server-Sent Events (SSE)** over HTTP/1.1 as the Phase 7B Realtime Architecture for server-to-app state push, alongside a suite of resilient background workers:

### A. Server-Sent Events (SSE) Rationale & Transport Protocol
- **Transport Protocol**: Standard HTTP/1.1 text-based event streaming (`Content-Type: text/event-stream`, `Cache-Control: no-cache`, `Connection: keep-alive`).
- **Unidirectional Push Model**: Mobile apps only require server-to-client state push (commands are issued via HTTP REST `POST /api/v1/commands/send`). SSE provides zero-overhead unidirectional streaming natively over standard HTTP without WebSocket handshake complexity.
- **Authentication & Authorization**:
  - Connection request `GET /api/v1/homes/:homeId/stream` requires JWT Bearer authentication (via `Authorization: Bearer <accessToken>` header or `?token=<accessToken>` query parameter for event source compatibility).
  - Enforces `requireHomeMembership()` authorization guard. A user in Home A MUST NEVER receive SSE events from Home B.

### B. Transport-Neutral Realtime Event Bus
- **In-Memory Pub-Sub**: `RealtimeEventBus` provides event fan-out decoupled from MQTT transport details.
- **Home Scoped Subscriptions**: Event subscribers register by `homeId`.
- **Post-Commit Authoritative Emission**: Events (`device.state`, `device.event`, `device.availability`, `command.receipt`, `telemetry.update`) are emitted ONLY AFTER authoritative backend processing and database persistence succeed.

### C. Reconnect & Event ID Semantics
- **Event Formatting**: Standard `id`, `event`, `data` fields.
- **Last-Event-ID Support**: Each event includes a deterministic monotonic event ID. Upon client disconnect and reconnect, the client passes `Last-Event-ID` header.
- **Best-Effort Live Stream**: If an event is beyond live memory buffer retention, clients perform a one-time HTTP GET snapshot sync upon reconnect (`GET /api/v1/homes/:homeId/devices`).

### D. Resilient Background Worker Suite
1. **Device STALE Heartbeat Detector (`device-stale-detector.js`)**: Inspects `lastSeenAt` timestamps, transitions device connection state to `STALE` if heartbeat threshold (default 45s) is exceeded, and emits `device.availability` SSE event.
2. **Command Timeout Worker (`command-timeout-worker.js`)**: Scans `SENT`/`CREATED` commands past `expiresAt`, transitions status to `TIMEOUT`/`EXPIRED`, and emits `command.receipt` SSE event.
3. **Outbox Retry Worker (`outbox-retry-worker.js`)**: Scans pending `outbox` records, retries MQTT transmission with exponential backoff up to max retry attempts, ensuring at-least-once transport delivery.

---

## 3. Rationale

- **Low Complexity & High Compatibility**: SSE uses standard HTTP infrastructure, easily passes through corporate firewalls, and works seamlessly with reverse proxies (NGINX `proxy_buffering off`).
- **Strict Multi-Tenant Isolation**: Events are filtered at the EventBus fan-out layer per `homeId`, guaranteeing multi-tenant security boundaries.

---

## 4. Status

- **Status**: `ACCEPTED` — Implemented in Phase 7B branch `feature/phase-7b-realtime-backend-workers`.
