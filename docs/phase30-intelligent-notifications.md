# Phase 30 — Intelligent Notifications, Alerts & User Event Center

## 1. Architectural Overview

Phase 30 establishes an authoritative, unified notification and event-center platform for the EH Home smart-home ecosystem. It extends and hardens the existing Phase 15 notification infrastructure into a production-grade, multi-source event center without creating duplicate tables, duplicate queues, or parallel services.

Key Architectural Principles:
- **Unified Event Pipeline**: Platform events from 9 distinct subsystems (`DEVICE_STATE`, `CONNECTIVITY`, `RELIABILITY`, `OTA`, `ENERGY`, `AUTOMATION`, `SECURITY`, `MATTER`, `ACCOUNT`) are funneled through a single authoritative ingestion gateway (`NotificationService.publishPlatformEvent`).
- **No Second Notification System**: Reuses existing `notifications`, `user_notification_preferences`, `push_device_tokens`, and `notification_delivery_queue` tables. Additive migration `023_intelligent_notifications.sql` strictly introduces `platform_events`, `notification_aggregations`, and `notification_actions`.
- **Deterministic Severity & Quiet Hours (FIX 2)**:
  - Severity classification maps to `CRITICAL`, `ERROR`, `WARNING`, `NOTICE`, and `INFO`.
  - Quiet hours defaults to deferring non-critical events (`ERROR`, `WARNING`, `NOTICE`, `INFO`) while **always immediately dispatching CRITICAL safety alerts**.
  - Quiet hours **never silently discards notifications**; deferred notifications are marked `DEFERRED` and delivered immediately upon quiet hours termination or trigger release.
  - Every decision includes fully auditable metadata (`policy`, `bypassQuietHours`, `reason`).
- **Downstream Failure Isolation (FIX 3)**:
  - Originating operations (device control, automations, OTA lifecycle, Matter synchronization, reliability routines, energy telemetry) are isolated from downstream notification dispatch failures.
  - Provider or push delivery failures are safely logged and queued; originating operations always return success.
- **Restricted Audit Endpoint (FIX 4)**:
  - Platform event audit trails are accessible exclusively via restricted endpoints (`GET /api/v1/admin/notifications/events` and alias `/api/v1/notifications/events`).
  - Server-side RBAC strictly enforces `ADMIN` or diagnostic role authorization, returning `401 UNAUTHORIZED` for unauthenticated requests and `403 FORBIDDEN` for standard `MEMBER` users. Sensitive credentials and tokens are sanitized from all responses.
- **Actionable Notifications**:
  - Interactive flows (`RECONNECT_DEVICE`, `ACK_ALERT`, `DISMISS_ALERT`, `MUTE_ALERTS`, `VIEW_DEVICE`, `REVIEW_UPDATE`, `CHECK_ENERGY`, `VIEW_ROUTINE`, `VIEW_INTEGRATIONS`, `VIEW_SECURITY`) allow users to act directly on alerts from within the notification surface with full replay safety and execution auditing.
- **Sliding-Window Aggregation & Deduplication**:
  - Consecutive events matching home, room, and event type within a sliding window (e.g. 60 seconds) are aggregated into cluster summaries to prevent user notification fatigue, with counts displayed as visual badge pills in the UI.

---

## 2. Event Sources & Deterministic Severity Matrix

| Event Source | Example Event Types | Default Severity | Action Type / Interactive Flow |
| :--- | :--- | :--- | :--- |
| `SECURITY` | `TAMPER_DETECTED`, `INTRUSION_ALARM`, `SMOKE_ALARM` | `CRITICAL` | `ACK_ALERT`, `DISMISS_ALERT` |
| `ENERGY` | `SURGE_PROTECTION_TRIP`, `POWER_OVERLOAD` | `CRITICAL` | `ACK_ALERT`, `CHECK_ENERGY` |
| `ENERGY` | `ENERGY_HIGH`, `BUDGET_EXCEEDED` | `WARNING` | `CHECK_ENERGY` |
| `CONNECTIVITY` | `DEVICE_OFFLINE`, `GATEWAY_DISCONNECTED` | `WARNING` | `RECONNECT_DEVICE`, `MUTE_ALERTS` |
| `RELIABILITY` | `RAPID_REBOOT_LOOP`, `HEALTH_DEGRADED` | `WARNING` | `RECONNECT_DEVICE` |
| `AUTOMATION` | `AUTOMATION_FAILED`, `SCENE_FAILED`, `TRIGGER_TIMEOUT` | `ERROR` | `VIEW_ROUTINE` |
| `OTA` | `OTA_FAILED`, `FIRMWARE_ROLLBACK` | `ERROR` | `REVIEW_UPDATE` |
| `OTA` | `OTA_AVAILABLE`, `UPDATE_READY` | `NOTICE` | `REVIEW_UPDATE` |
| `MATTER` | `FABRIC_DISCONNECTED`, `COMMISSIONING_FAILED` | `WARNING` | `VIEW_INTEGRATIONS` |
| `ACCOUNT` | `MEMBER_INVITED`, `ROLE_CHANGED` | `NOTICE` | `VIEW_SECURITY` |
| `DEVICE_STATE` | `DEVICE_ONLINE`, `STATE_CHANGED`, `SWITCH_TOGGLED` | `INFO` | `VIEW_DEVICE` |

---

## 3. Quiet Hours Policy Engine (FIX 2)

```
Incoming Platform Event
         │
         ▼
Evaluate Quiet Hours Decision
         ├── Is Quiet Hours Active for User? (e.g., 22:00 - 07:00)
         │       │
         │       ├── NO ──► Action: SEND (Dispatch immediately across enabled channels)
         │       │
         │       └── YES ─► Check Event Severity
         │                     │
         │                     ├── CRITICAL ──► Action: SEND (Bypass quiet hours; critical safety priority)
         │                     │                Metadata: { bypassQuietHours: true, policy: "SAFETY_CRITICAL" }
         │                     │
         │                     └── ERROR / WARNING / NOTICE / INFO
         │                             │
         │                             └──► Action: DEFER (Persist with status DEFERRED; NEVER discard)
         │                                  Metadata: { deferredUntil: quietHoursEnd, policy: "QUIET_HOURS_DEFERRED" }
```

---

## 4. REST API Reference

### Notification Management
- `GET /api/v1/notifications`: List paginated notifications with filters (`severity`, `category`, `homeId`, `unreadOnly`).
- `GET /api/v1/notifications/unread-count`: Retrieve unread count for current user or home.
- `PATCH /api/v1/notifications/:id/read`: Mark an individual notification as read.
- `POST /api/v1/notifications/mark-all-read`: Mark all notifications as read for current user/home.
- `POST /api/v1/notifications/:id/action`: Execute an actionable notification flow (`actionType`, `payload`).
- `POST /api/v1/notifications/release-deferred`: Release and deliver deferred quiet-hours notifications.

### Preferences & Push Tokens
- `GET /api/v1/notifications/preferences`: Get user notification preferences (quiet hours, channels, categories).
- `PUT /api/v1/notifications/preferences`: Update preferences (supports both camelCase and snake_case payloads).
- `POST /api/v1/notifications/push-tokens`: Register or update FCM/APNs push device token.
- `DELETE /api/v1/notifications/push-tokens/:token`: Revoke a device token.

### Restricted Audit Endpoints (FIX 4)
- `GET /api/v1/admin/notifications/events` (and alias `/api/v1/notifications/events`): Query canonical platform events audit log.
  - Requires `role: ADMIN` or `x-admin-role: true` header.
  - Returns `401` if unauthenticated, `403` if standard member.
  - Sensitive internal tokens and secrets are automatically redacted.

---

## 5. Compliance & Certification Disclosure

- **Physical Hardware Changes**: `NONE`
- **Physical Hardware Validation**: `NOT RUN`
