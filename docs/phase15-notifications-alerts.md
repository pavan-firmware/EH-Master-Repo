# EH Home — Phase 15: Notifications, Alerts & Event Delivery Platform

## Architecture & Design

### Downstream Invariant
The notification and alert delivery platform is strictly downstream of authoritative events.
Notification logic never mutates hardware states, sends device commands, or modifies system authorization tables.

```
Authoritative Event (EventBus)
       ↓
Notification Policy Classification (type, category, priority)
       ↓
Recipient Resolution (home members / owner)
       ↓
User Preferences Check (push_enabled, category toggles)
       ↓
Deduplication & Rate Limiting (windowed key hash)
       ↓
Notification Persistence (notifications table)
       ↓
Delivery Queue Enqueue (notification_delivery_queue)
       ↓
Push Delivery Worker (NotificationDeliveryWorker with exponential backoff)
       ↓
Push Notification Provider (FCM / APNs / SimulatedProvider)
       ↓
Client Device Notification Center
```

### Database Schema (Migration 008)
- `notifications`: Stores historical in-app notifications with `read_at`, `priority`, `category`, and `delivery_status`.
- `push_device_tokens`: Secure registration of user device tokens (FCM/APNs) with platform and active state.
- `user_notification_preferences`: Fine-grained toggles for push alerts (`critical_alerts`, `device_offline`, `automation_failure`, `firmware_updates`).
- `notification_delivery_queue`: Reliable delivery items with retry counters, next attempt timestamps, and terminal dead-letter states.

### REST Endpoints
- `GET /api/v1/notifications`: Paginated notification history with unread count and category filter.
- `GET /api/v1/notifications/unread-count`: Fast unread count badge lookup.
- `PATCH /api/v1/notifications/:id/read`: Mark single notification as read.
- `POST /api/v1/notifications/mark-all-read`: Mark all unread notifications as read.
- `GET /api/v1/notifications/preferences`: Get user notification settings.
- `PUT /api/v1/notifications/preferences`: Update user notification settings.
- `POST /api/v1/notifications/push-tokens`: Register push token for device.
- `DELETE /api/v1/notifications/push-tokens/:token`: Revoke/remove push token.

### Verification Status
- **Backend Test Suite**: 8/8 test categories passed (`backend/tests/phase15-notifications.test.js`).
- **Flutter Test Suite**: 127/127 tests passed (`flutter test`).
- **Flutter Analyzer**: 0 issues found (`flutter analyze`).
- **Monorepo Pre-Push Suite**: 25/25 suites passed (`node scripts/validate-repo.js`).
