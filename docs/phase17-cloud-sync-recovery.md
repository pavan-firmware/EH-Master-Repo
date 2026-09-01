# EH Home — Phase 17: Cloud Sync, Backup, Restore, Offline Reconciliation & Data Lifecycle

## 1. Overview & Architecture

Phase 17 establishes an enterprise-grade cloud synchronization, backup recovery, offline reconciliation, and data retention architecture across the EH Home smart home platform.

### Source-of-Truth Matrix
| Domain / Entity | Authoritative Store | Client Storage | Offline Mutations Allowed | Conflict Resolution Policy |
|---|---|---|---|---|
| **User & Profile** | Backend Relational DB | Memory / SQLite cache | Safe metadata (name, phone, timezone) | Last-Write-Wins (LWW) with server validation |
| **Homes & Roles** | Backend Relational DB | Memory / SQLite cache | Safe metadata (name, timezone, address) | Server-authoritative capability check / LWW |
| **Floors & Rooms** | Backend Relational DB | Memory / SQLite cache | Create, Rename, Delete, Sort | Server-authoritative with ID reconciliation |
| **Devices & Claiming** | Backend Claim / HW Identity | Memory / SQLite cache | Rename, Room Assignment | Server-authoritative capability check |
| **Device Live State** | ESP32 Hardware + SSE Bus | Ephemeral UI cache | Read-only (marked STALE if disconnected) | Hardware / SSE authoritative. No blind queuing. |
| **Scenes & Automations**| Backend Relational DB | Memory / SQLite cache | Create, Update, Delete, Toggle | Version-aware LWW |
| **Schedules** | Backend Relational DB | Memory / SQLite cache | Read-only / Cloud-triggered | Cloud scheduler authoritative |
| **Notifications** | Backend Relational DB | Memory / SQLite cache | Mark Read, Mark All Read | Server-authoritative deduplication |

---

## 2. API Endpoints

### 1. `GET /api/v1/sync/bootstrap`
Returns a unified, consistent snapshot of the user's entire account, homes, members, rooms, claimed devices, automations, scenes, schedules, and notification preferences for cold app start or cloud restore after data clear.

- **Query Parameters**: `homeId` (optional), `clientDeviceId` (optional)
- **Response**: `SyncBootstrapBundle`

### 2. `POST /api/v1/sync/reconcile`
Processes queued offline mutations in a batch transaction with capability validation, role enforcement, ID reconciliation, and conflict reporting.

- **Request Body**: `{ homeId: string, mutations: PendingMutation[] }`
- **Response**: `ReconciliationSummary`

### 3. `GET /api/v1/sync/export`
Generates a sanitized JSON export of user or home data complying with privacy regulations (GDPR/CCPA).

- **Security Boundary**: Strictly excludes password hashes, refresh tokens, private keys, session tokens, and Wi-Fi PSKs.
- **Query Parameters**: `homeId` (optional for home-scoped export)
- **Response**: `DataExportBundle`

---

## 3. Database Schema (Migration 010)

```sql
-- Sync Checkpoints
CREATE TABLE IF NOT EXISTS sync_checkpoints (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  home_id TEXT NOT NULL,
  client_device_id TEXT NOT NULL,
  last_sync_seq INTEGER DEFAULT 0,
  schema_version INTEGER DEFAULT 1,
  last_synced_at TEXT NOT NULL
);

-- Pending Change Audits
CREATE TABLE IF NOT EXISTS pending_change_audits (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  home_id TEXT NOT NULL,
  client_mutation_id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  mutation_type TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  status TEXT NOT NULL,
  rejection_reason TEXT,
  applied_at TEXT NOT NULL
);

-- Data Export Records
CREATE TABLE IF NOT EXISTS data_export_records (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  home_id TEXT,
  export_scope TEXT NOT NULL,
  sanitized_summary_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);
```

---

## 4. Flutter Client Implementation

- **`SyncService`**: Implements local caching, network awareness (`setOnlineStatus`), offline FIFO mutation queueing (`queueMutation`), cloud reconciliation (`reconcilePending`), and cold start restoration (`bootstrapSync`).
- **`SyncStatusWidget`**: Compact, animated badge widget dynamically reflecting sync states (`synced`, `syncing`, `pendingChanges`, `offline`, `conflict`, `error`).
- **`SyncCenterPage`**: Dedicated management hub for inspecting the offline mutation queue, triggering manual sync, and requesting zero-secret data exports.
