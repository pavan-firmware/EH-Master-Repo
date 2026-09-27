# EH Home — PostgreSQL & Drizzle Database Schema Guide

## 1. Architectural Role & Source of Truth

The database layer serves as the persistent state backbone for EH Home.
- **Authoritative Baseline**: PostgreSQL migrations `001_initial_schema.sql` through `029_production_observability_and_incidents.sql` in `backend/migrations/`.
- **TypeScript / ORM Representation**: `@eh-home/db-schema` (`packages/db-schema/src/`), providing 100% type-safe Drizzle ORM models, relations, and connection management.
- **Frozen Migrations Invariant**: Migrations `001–029` are completely **frozen**. They may not be edited, squashed, reordered, or deleted. All future schema growth begins at migration `030+`.

---

## 2. Zod Contracts vs. Drizzle Persistence Boundary

The Part 01 contracts and Part 02 database schema maintain strict separation of concerns:

| Aspect | Zod Contracts (`@eh-home/contracts`) | Drizzle Schema (`@eh-home/db-schema`) |
|---|---|---|
| **Primary Purpose** | Wire format, runtime API validation, transport validation (MQTT, HTTP, BLE, QR). | PostgreSQL persistence, relational constraints, foreign keys, indexes, storage types. |
| **Field Naming** | CamelCase (`productVariantId`, `serialNumber`, `isMatch`). | Database column names in SQL snake_case (`product_variant_id`, `serial_number`), mapped to typed camelCase accessors in TypeScript. |
| **Nullability** | Schema `.optional()` or `.nullable()`. | PostgreSQL `NOT NULL`, `NULL`, and SQL `DEFAULT` clauses. |
| **Internal Secrets** | Strictly excludes passwords, password hashes, and private keys from public schemas (e.g., QR payload). | Persists secure hashes (`password_hash`, `mqtt_password_hash`, `local_session_key_hash`) with restricted query access. |

---

## 3. Database Inventory: Existing Schema (Migrations 001–029)

Across the 29 historical migrations, exactly **103 tables** are managed. They are organized into 18 architectural domains:

### 3.1. Identity & Access Control (`auth-identity.ts`)
| Table | Migration | Purpose & Primary Key | Key Constraints & Relations |
|---|---|---|---|
| `users` | 001 | Core user authentication records. PK: `id VARCHAR(128)` | Unique `email`. Roles: `USER`, `ADMIN`. |
| `refresh_tokens` | 001 | OAuth/session refresh tokens. PK: `id VARCHAR(128)` | FK `user_id` -> `users(id)` ON DELETE CASCADE. |
| `user_profiles` | 009 | Extended profile metadata. PK: `id VARCHAR(64)` | FK `id` -> `users(id)` ON DELETE CASCADE. |
| `home_invitations` | 009 | Pending/accepted home invites. PK: `id VARCHAR(64)` | FK `home_id` -> `homes(id)`, `inviter_user_id` -> `users(id)`. Unique `invite_code`. |
| `home_memberships` | 001 | User-to-home membership & RBAC. PK: `id VARCHAR(255)` | Unique composite `(home_id, user_id)`. Role check: `OWNER`, `ADMIN`, `MEMBER`, `GUEST`. |

### 3.2. Home Topology (`home-topology.ts`)
| Table | Migration | Purpose & Primary Key | Key Constraints & Relations |
|---|---|---|---|
| `homes` | 001 | Customer home boundary. PK: `id VARCHAR(128)` | FK `owner_id` -> `users(id)` ON DELETE RESTRICT. |
| `floors` | 001 | Multi-level home structure. PK: `id VARCHAR(128)` | FK `home_id` -> `homes(id)` ON DELETE CASCADE. |
| `rooms` | 001 | Room zones for device placement. PK: `id VARCHAR(128)` | FK `home_id` -> `homes(id)`, FK `floor_id` -> `floors(id)`. |

### 3.3. Product Catalog Foundation (`product-catalog.ts`)
| Table | Migration | Purpose & Primary Key | Key Constraints & Relations |
|---|---|---|---|
| `product_families` | 001 | Broad category definitions. PK: `id VARCHAR(128)` | Unique `slug`. |
| `products` | 001 | Top-level product lines. PK: `id VARCHAR(128)` | FK `family_id` -> `product_families(id)`. Status check. |
| `product_variants` | 001 | Concrete SKUs and channel counts. PK: `id VARCHAR(128)` | FK `product_id` -> `products(id)`. Stores hardware & connectivity JSONB profiles. |
| `product_models` | 020 | Hardware model abstraction. PK: `id VARCHAR(128)` | FK `family_id` -> `product_families(id)`. |
| `capabilities` | 002 | Canonical hardware capability registry. PK: `capability_id VARCHAR(64)` | Stores commands, properties, events JSONB definitions. |
| `product_capabilities` | 002 | Junction table linking variants to capabilities. Composite PK `(product_variant_id, capability_id, channel_index)` | Relational mapping for multi-gang channels. |
| `product_images` | 002 | Catalog visual assets. PK: `id VARCHAR(128)` | FK `product_variant_id` -> `product_variants(id)`. Kind check (`HERO`, `FRONT`, etc.). |
| `device_add_sessions` | 020 | Guided pairing & setup sessions. PK: `id VARCHAR(64)` | FK `home_id` -> `homes(id)`. |

### 3.4. Device Identity & Hardware State (`device-identity-state.ts`)
| Table | Migration | Purpose & Primary Key | Key Constraints & Relations |
|---|---|---|---|
| `devices` | 001 | Physical device hardware identity. PK: `id VARCHAR(128)` | Unique `serial_number`. FK `product_variant_id` -> `product_variants(id)`. |
| `device_credentials` | 001 | Hardware MQTT credentials and secret hashes. PK: `device_id VARCHAR(128)` | FK `device_id` -> `devices(id)`. Unique `mqtt_username`. State check. |
| `device_authorizations` | 001 | Device-to-home association and naming. PK: `device_id VARCHAR(128)` | FK `home_id` -> `homes(id)`, FK `room_id` -> `rooms(id)`. |
| `device_state` | 001 | Online/offline and heartbeat state. PK: `device_id VARCHAR(128)` | Connection state: `ONLINE`, `STALE`, `OFFLINE`. |
| `channel_state` | 001 | Decoupled desired vs reported channel state. PK: `id VARCHAR(255)` | Unique composite `(device_id, channel_index)`. Confidence check. |
| `device_commands` | 001 | Command ledger with idempotency keys. PK: `id VARCHAR(128)` | FK `device_id` -> `devices(id)`. Status check. |
| `device_events` | 001 | Event log from physical toggles or cloud actions. PK: `id VARCHAR(128)` | Ordered sequence numbers per device. |
| `network_identity` | 002 | Ephemeral network info (IP, MAC). PK: `device_id VARCHAR(128)` | FK `device_id` -> `devices(id)`. |
| `provisioning_sessions` | 005 | Wi-Fi onboarding handshake. PK: `id VARCHAR(128)` | FK `device_id` -> `devices(id)`. |

### 3.5. Automations & Schedules (`automations-scenes.ts`)
| Table | Migration | Purpose & Primary Key | Key Constraints & Relations |
|---|---|---|---|
| `scenes` | 006 | Preset multi-device target states. PK: `id VARCHAR(64)` | FK `home_id` -> `homes(id)`. Actions JSONB. |
| `automations` | 006 | Event-driven trigger rules. PK: `id VARCHAR(64)` | FK `home_id` -> `homes(id)`. Triggers, conditions, actions JSONB. |
| `schedules` | 006 | Time-of-day and cron schedules. PK: `id VARCHAR(64)` | FK `home_id` -> `homes(id)`. Recurrence rules JSONB. |
| `automation_execution_logs` | 006 | Execution history and timing logs. PK: `id VARCHAR(64)` | Idempotency execution key. Target results JSONB. |

### 3.6. Device Observability & Metrics (`device-health-activity.ts`)
- `device_activity_logs` (007): Structured audit events per device.
- `device_health_metrics` (007): Uptime, RSSI, command failure metrics.
- `device_transports` (019): Transport protocol records (Wi-Fi, BLE, Thread).
- `device_connection_states` (019): Protocol-level state transitions.
- `commissioning_sessions` (019): Multi-protocol pairing sessions.
- `transport_health_snapshots` (019): Transport latency and signal strength.

### 3.7. Notifications & Alerts (`notifications-alerts.ts`)
- `notifications` (008): In-app and push notifications.
- `push_device_tokens` (008): FCM/APNS push tokens per user.
- `user_notification_preferences` (008): User alert filter preferences.
- `notification_delivery_queue` (008): Retry queue for push delivery.
- `platform_events` (023): Event bus persistence.
- `notification_aggregations` (023): Batched alert rollups.
- `notification_actions` (023): User interactions on alerts.
- `platform_alerts` (029): Operational service alerts.

### 3.8. Sync & Data Lifecycle (`sync-lifecycle.ts`)
- `sync_checkpoints` (010): Client offline-sync version checkpoints.
- `pending_change_audits` (010): Client mutation reconciliation log.
- `data_export_records` (010): GDPR data takeout export records.

### 3.9. Fleet Management & Firmware (`fleet-ota.ts`)
- `firmware_releases` (011): Firmware binaries, SHA-256 checksums, and release channels.
- `ota_rollouts` (011): Phased rollout campaigns (Canary, Production).
- `ota_operations` (011): Device-specific OTA progress tracking.
- `device_maintenance_logs` (011): Historical firmware changes per device.
- `fleet_device_firmware_state` (028): Firmware compliance view.
- `ota_attempts` (028): Granular OTA download and flash attempt logs.

### 3.10. Energy Intelligence (`energy-intelligence.ts`)
- `device_telemetry_measurements` (012), `telemetry_aggregates` (012), `energy_threshold_configs` (012), `energy_events` (012)
- `energy_automation_executions` (013), `energy_optimizations` (013)
- `energy_tariffs` (014), `tariff_periods` (014), `energy_budgets` (014), `cost_optimizations` (014)
- `energy_forecasts` (015), `energy_anomalies` (015), `energy_baselines` (015), `forecast_accuracy_records` (015), `energy_efficiency_scores` (015)

### 3.11. Presence & Context (`presence-context.ts`)
- `presence_signals` (016), `presence_states` (016), `home_contexts` (016), `context_overrides` (016), `context_transitions` (016)

### 3.12. Smart Home Intelligence (`home-intelligence.ts`)
- `intelligence_decisions` (017), `intelligence_recommendations` (017), `intelligence_decision_outcomes` (017)

### 3.13. Proactive Device Reliability (`device-reliability.ts`)
- `reliability_incidents` (018), `reliability_diagnostics` (018), `reliability_recovery_attempts` (018), `reliability_health_snapshots` (018), `maintenance_recommendations` (018)

### 3.14. Edge & Local Control (`edge-local-control.ts`)
- `local_route_cache` (021), `edge_execution_records` (021), `local_discovery_nodes` (021)

### 3.15. Matter Interoperability (`matter-interop.ts`)
- `matter_devices` (022), `matter_fabrics` (022), `matter_endpoints` (022), `matter_sync_state` (022), `external_platform_links` (022)

### 3.16. Operations & Audit (`operations-audit.ts`)
- `audit_logs` (002), `outbox` (002), `operational_events` (024), `security_audit_records` (024), `system_health_snapshots` (024), `platform_incidents` (029)

### 3.17. Secure Device Trust (`device-trust.ts`)
- `device_trust_states` (025), `device_credential_lifecycle` (025), `device_revocations` (025), `device_provisioning_records` (025)

### 3.18. Disaster Recovery & State Resilience (`disaster-recovery.ts`)
- `backup_records` (026), `backup_objects` (026), `restore_operations` (026), `recovery_checkpoints` (026), `recovery_integrity_results` (026)

---

## 4. Future Schema Gaps (To Be Introduced in Migrations 030+)

The existing schema covers customer home execution, device operation, and operational diagnostics. However, manufacturing, supply chain, and hardware lifecycle domains require new forward migrations starting at `030+`:

| Requirement Gap | Purpose & Planned Tables | Target Migration Phase |
|---|---|---|
| **Hardware Revision & BOM** | `hardware_revisions`, `bom_specifications`, `bom_items` tracking PCB revisions, Gerber files, and vendor MPNs. | Migration `030` |
| **Production Batches & QC** | `production_batches`, `batch_devices`, `qc_station_logs`, `qc_measurements` for manufacturing runs. | Migration `031` |
| **Opaque QR & Packing Verification** | `device_qr_records`, `dual_scan_verifications`, `packaging_records` enforcing the `eh://p/v1?t=<TOKEN>` invariant and box/device serial matching. | Migration `032` |
| **Warehouse & Inventory** | `warehouse_inventory`, `stock_transfers`, `device_allocations`. | Migration `033` |

*Note: In accordance with Part 02 rules, none of these tables have been created yet. They are scheduled for deliberate migration rollout in their respective phases.*
