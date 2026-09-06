# Phase 38 — Real Push Notifications & Remote Backup Storage

## 1. Executive Summary

Phase 38 transitions the EH Home platform from mock/simulated cloud-service stubs to secure, real, provider-backed implementations for:
1. **Mobile Push Notification Delivery** via Google Firebase Cloud Messaging (FCM HTTP v1 REST API) and Apple Push Notification service (APNs HTTP/2 with token-based authentication).
2. **Remote / Off-Site Disaster Recovery Backup Storage** via Amazon S3-compatible object storage APIs (AWS S3, Cloudflare R2, MinIO, Ceph, Wasabi).

All integrations preserve the existing Phase 30 intelligent notification decision engine, Phase 33 disaster recovery verification pipeline, Phase 32 device trust and credential security invariants, and local-first architecture.

---

## 2. Push Notification Architecture

### 2.1 Pipeline Flow
The notification delivery architecture preserves the strict unidirectional pipeline:
```
Platform Event / Telemetry / Audit Trigger
               ↓
Phase 30 Notification Decision Engine
  (Severity, Suppression, Aggregation, Quiet Hours, Deduplication)
               ↓
Notification Delivery Worker
  (Channel Routing, Preferences, Recipient Resolution, Device Tokens)
               ↓
Push Provider Abstraction (PushNotificationProvider)
  ├── FcmHttpV1PushProvider (Android, Web, iOS via FCM)
  ├── ApnsPushProvider (Direct iOS APNs)
  └── CompositePushProvider (Multi-platform fan-out)
```

Business decisions (severity, quiet hours, user mute preferences) remain exclusively in the Phase 30 decision engine and delivery worker. Providers only handle transport formatting, authentication, payload transmission, and error classification.

### 2.2 Provider Implementations

#### A. Google FCM HTTP v1 (`FcmHttpV1PushProvider`)
- **Protocol**: FCM HTTP v1 REST API (`https://fcm.googleapis.com/v1/projects/{projectId}/messages:send`).
- **Authentication**: RFC 7523 OAuth2 Service Account assertion using RS256 JWT signature exchanged for short-lived Google OAuth2 bearer tokens (`https://oauth2.googleapis.com/token`).
- **Payload Schema**: Canonical standard FCM payload containing:
  - `message.token`: Target device registration token.
  - `message.notification`: `title`, `body`.
  - `message.data`: `notification_id`, `event_type`, `severity`, `home_id`, `timestamp`.
  - `message.android.priority`: `HIGH` for `CRITICAL`/`ERROR`, `NORMAL` for `WARNING`/`NOTICE`/`INFO`.
- **Token Cache**: Reuses in-memory OAuth2 token with a 60-second expiry safety buffer before automatic renewal.

#### B. Apple APNs (`ApnsPushProvider`)
- **Protocol**: APNs HTTP/2 Provider API (`api.push.apple.com` for production, `api.sandbox.push.apple.com` for sandbox/development).
- **Authentication**: JWT authentication tokens using ECDSA P-256 (ES256) algorithm with Team ID (`iss`), Key ID (`kid`), and issuing time (`iat`), refreshed every 50 minutes.
- **Payload Schema**: Canonical Apple `aps` alert payload:
  - `aps.alert`: `title`, `body`.
  - `aps.sound`: `default`.
  - `aps.interruption-level`: `critical` / `time-sensitive` / `active`.
  - Custom payload dictionary with canonical notification identifiers.

#### C. Composite & Test Providers
- `CompositePushProvider`: Dynamically routes to FCM or APNs based on device token platform metadata.
- `SimulatedPushProvider`: In-memory mock strictly restricted to `test` and local development environments. Blocked in production unless `ALLOW_SIMULATED_PUSH=true` is explicitly provided.

---

## 3. Push Token Lifecycle & Security

### 3.1 Token Lifecycle States
1. **Registration**: Client app acquires platform token from Firebase Messaging / APNs SDK and registers with backend via authenticated `/api/v1/notifications/tokens` endpoint.
2. **Refresh**: When OS rotates push token, client updates backend with new token; old token record is replaced.
3. **Deactivation / Invalid Token**: When FCM returns `UNREGISTERED` / `404` or APNs returns `BadDeviceToken` / `410`, provider classifies error as permanent and delivery worker immediately marks the device token as `status: 'INACTIVE'` in the database.
4. **Logout / User Unlink**: On user logout or account deletion, device tokens bound to that session are revoked.

### 3.2 Token Privacy & RBAC Boundaries
- **Ownership Isolation**: Device tokens are strictly isolated per `user_id`. Non-admin users cannot query or enumerate tokens belonging to other users.
- **Redaction**: Push tokens are treated as sensitive credentials. Diagnostic logs and API outputs mask tokens (e.g. `eK7...9qX`). Complete tokens are never logged.

### 3.3 Delivery Retries & Error Classification
- **Temporary Failures**: `503 Service Unavailable`, `429 Too Many Requests`, timeouts, network drops. Delivery item is scheduled for exponential backoff retry with bounded attempt limits.
- **Permanent Failures**: `404 Unregistered`, `400 Invalid Argument`, `401 Unauthorized`. Delivery item is immediately marked `status: 'FAILED'`, and invalid tokens are pruned.

---

## 4. Remote Disaster-Recovery Backup Storage

### 4.1 Architecture & Abstraction
The `BackupProvider` abstraction extends Phase 33 to support multi-cloud object storage:
- `LocalBackupProvider`: Local disk snapshots (`var/backups/`).
- `MemoryBackupProvider`: In-memory transient snapshots for isolated unit testing.
- `S3BackupProvider`: Real remote object storage implementing AWS Signature Version 4 (SigV4) signing with support for:
  - AWS S3
  - Cloudflare R2
  - MinIO / Local S3 Mock
  - Ceph / Wasabi / DigitalOcean Spaces

### 4.2 S3BackupProvider Capabilities
- **Object Operations**: `upload(key, data)`, `download(key)`, `list(prefix)`, `delete(key)`, `exists(key)`.
- **Integrity**: Calculates and verifies SHA-256 digests over all uploaded and downloaded streams.
- **Path Style**: Supports virtual-hosted and path-style URLs (`forcePathStyle`).
- **Server-Side Encryption**: Supports `x-amz-server-side-encryption` headers (e.g., `AES256`, `aws:kms`).
- **Retries**: Automatically retries transient 5xx / 429 status codes with exponential backoff and jitter.

### 4.3 Backup Secret Sanitization & Manifest Invariant
Backups strictly adhere to Phase 33 sanitization before serialization and upload:
1. **Sanitize Entities**: Strip passwords, private keys, refresh tokens, MQTT credentials, Wi-Fi credentials, session secrets.
2. **Serialize to JSON**: Canonical formatting.
3. **Compute SHA-256 Digest**: Calculate per-object cryptographic checksum.
4. **Generate Manifest**: Include object file names, byte sizes, checksums, and schema version.
5. **Upload Objects & Manifest**: Upload all snapshot data files first; upload `manifest.json` last.
6. **Mark COMPLETED**: Backup record is only marked `COMPLETED` when remote uploads and checksums are verified. Interrupted or partial uploads remain `FAILED`.

### 4.4 Restore Pipeline & Security Guarantees
Remote backups are restored through the canonical 5-stage pipeline:
`VALIDATE` → `PRECHECK` → `PLAN` → `APPLY` → `VERIFY`.

- **Phase 32 Trust Authority**: Restore operations will **NEVER** resurrect revoked devices, restore expired certificates, or bypass decommissioned hardware states. Active security revocations in the database always take precedence over historical backup snapshots.

---

## 5. Configuration & Environment Variables

### 5.1 Push Notification Configuration
| Environment Variable | Description | Required For |
|---|---|---|
| `PUSH_PROVIDER_TYPE` | `simulated`, `fcm`, `apns`, `composite` | Production (`fcm` / `apns` / `composite`) |
| `ALLOW_SIMULATED_PUSH` | Explicit override to allow simulation in prod | Testing only |
| `FCM_PROJECT_ID` | Google Cloud / Firebase Project ID | FCM |
| `FCM_CLIENT_EMAIL` | Service account client email | FCM |
| `FCM_PRIVATE_KEY` | PEM-encoded RSA private key | FCM |
| `FCM_SERVICE_ACCOUNT_KEY` | Path or raw JSON of service account key | FCM (Alternative) |
| `APNS_KEY_ID` | 10-character Key ID from Apple Developer | APNs |
| `APNS_TEAM_ID` | 10-character Team ID from Apple Developer | APNs |
| `APNS_BUNDLE_ID` | App bundle identifier (e.g. `com.ehhome.app`) | APNs |
| `APNS_AUTH_KEY` | PEM-encoded PKCS#8 auth key (`.p8`) | APNs |
| `APNS_ENVIRONMENT` | `production` or `sandbox` | APNs |

### 5.2 Remote Backup Configuration
| Environment Variable | Description | Required For |
|---|---|---|
| `BACKUP_PROVIDER_TYPE` | `local`, `memory`, `s3` | Production (`s3` / `local`) |
| `BACKUP_LOCAL_DIR` | Local disk root for backups | `local` |
| `BACKUP_S3_BUCKET` | S3 bucket name | `s3` |
| `BACKUP_S3_REGION` | S3 region (e.g. `us-east-1`, `auto`) | `s3` |
| `BACKUP_S3_ENDPOINT` | Custom S3 endpoint (e.g. MinIO, R2) | `s3` (optional) |
| `BACKUP_S3_ACCESS_KEY_ID` | S3 access key ID / AWS_ACCESS_KEY_ID | `s3` |
| `BACKUP_S3_SECRET_ACCESS_KEY` | S3 secret access key / AWS_SECRET_ACCESS_KEY | `s3` |
| `BACKUP_S3_PREFIX` | Object prefix (defaults to `backups/`) | `s3` |
| `BACKUP_S3_FORCE_PATH_STYLE` | `true` for MinIO/local storage | `s3` (optional) |
| `BACKUP_S3_SSE` | Server-side encryption header | `s3` (optional) |

---

## 6. Operational Readiness & Diagnostics

### 6.1 Health Probes
Integrated into Phase 34 `OperationalReadinessService`:
- `checkPushProvider()`: Non-destructive probe verifying provider configuration, credential validity, and token cache status.
- `checkBackupProvider()`: Non-destructive probe verifying storage configuration, bucket reachability, or local directory write permissions.

### 6.2 Admin Diagnostics
- Accessible via authenticated `/api/v1/system/diagnostics` (admin-only).
- Diagnostics display provider readiness states (`READY`, `STANDBY`, `UNCONFIGURED`).
- **Zero Secret Exposure**: All private keys, access tokens, AWS secret keys, and passwords are fully redacted.

---

## 7. Live-Validation Limitations
- Unit and contract tests mock network boundaries to ensure deterministic, fast CI/CD execution without external cloud dependencies.
- Live integration with Google FCM, Apple APNs, and AWS S3 requires real external cloud credentials and active mobile device hardware tokens, reported as `NOT RUN` in mock environments.
