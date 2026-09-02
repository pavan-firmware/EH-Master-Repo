# EH Home — Phase 18: Device Fleet Management, Firmware Inventory & OTA Lifecycle

## 1. Overview & Architectural Principles

Phase 18 implements an enterprise device fleet management, signed firmware inventory, and OTA update lifecycle architecture for the EH Home smart home ecosystem.

### Architectural Invariants
1. **Reuses Existing Transports**: Dispatches update triggers through `DeviceCommandService` on MQTT topic `eh/v1/devices/{deviceId}/commands` with action `otaUpdate`. Ingests progress and completion via standard telemetry/events pipeline.
2. **Authoritative Device State**: The backend tracks *desired* firmware version and operation state, but never claims update completion until the physical device sends an authoritative boot confirmation from the new partition.
3. **Rollback Resilience**: In event of CRC/signature mismatch or boot failure, hardware hardware-rolls-back to the previous active partition. Backend converges to `ROLLED_BACK` state and triggers alerts.
4. **Compatibility Guarding**: Rejects incompatible releases before rollout based on `productVariantId`, `hardwareRevision`, `firmwareFamily`, and bridge versions (`minFirmwareVersion`).
5. **Zero Secret Leakage**: Manifests, fleet summaries, and maintenance logs strictly exclude device private keys, MQTT credentials, password hashes, and commissioning secrets.

---

## 2. API Endpoints

### 1. `GET /api/v1/ota/check`
Evaluates whether a compatible, newer firmware release is available for a given device hardware profile.
- **Query Parameters**: `productVariantId`, `hardwareRevision`, `currentVersion`, `releaseChannel`
- **Response**: `{ updateAvailable: boolean, release: FirmwareRelease | null }`

### 2. `GET /api/v1/fleet/status`
Aggregates device inventory health, online/offline counts, update availability counts, and per-device firmware details.
- **Query Parameters**: `homeId` (optional for home-scoped aggregation)
- **Response**: `FleetStatus`

### 3. `POST /api/v1/ota/operations`
Initiates a signed OTA firmware update for an authorized device.
- **Request Body**: `{ deviceId: string, releaseId: string, homeId: string }`
- **Response**: `OtaOperation` (status `DOWNLOADING`)

### 4. `GET /api/v1/ota/maintenance`
Returns the historical maintenance logs, firmware upgrades, rollbacks, and diagnostic events for a home or device.
- **Query Parameters**: `homeId`, `deviceId` (optional)
- **Response**: `DeviceMaintenanceLog[]`

---

## 3. Database Schema (Migration 011)

```sql
CREATE TABLE IF NOT EXISTS firmware_releases (
  id TEXT PRIMARY KEY,
  product_variant_id TEXT NOT NULL,
  hardware_revision TEXT,
  firmware_family TEXT NOT NULL,
  version TEXT NOT NULL,
  min_firmware_version TEXT,
  release_channel TEXT NOT NULL DEFAULT 'production',
  binary_size_bytes INTEGER NOT NULL,
  sha256 TEXT NOT NULL,
  ed25519_signature TEXT NOT NULL,
  download_url TEXT NOT NULL,
  release_notes TEXT,
  status TEXT NOT NULL DEFAULT 'PUBLISHED',
  created_at TEXT NOT NULL,
  released_at TEXT,
  FOREIGN KEY (product_variant_id) REFERENCES product_variants(id)
);

CREATE TABLE IF NOT EXISTS ota_rollouts (
  id TEXT PRIMARY KEY,
  release_id TEXT NOT NULL,
  home_id TEXT,
  rollout_stage TEXT NOT NULL DEFAULT 'CANARY',
  status TEXT NOT NULL DEFAULT 'ACTIVE',
  target_filters_json TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (release_id) REFERENCES firmware_releases(id)
);

CREATE TABLE IF NOT EXISTS ota_operations (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  home_id TEXT NOT NULL,
  release_id TEXT NOT NULL,
  rollout_id TEXT,
  from_version TEXT NOT NULL,
  target_version TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'QUEUED',
  progress_percent INTEGER DEFAULT 0,
  error_code TEXT,
  error_message TEXT,
  initiated_by_user_id TEXT,
  started_at TEXT NOT NULL,
  completed_at TEXT,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (device_id) REFERENCES devices(id),
  FOREIGN KEY (home_id) REFERENCES homes(id),
  FOREIGN KEY (release_id) REFERENCES firmware_releases(id)
);

CREATE TABLE IF NOT EXISTS device_maintenance_logs (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  home_id TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  release_id TEXT,
  from_version TEXT,
  to_version TEXT,
  status TEXT NOT NULL,
  details_json TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (device_id) REFERENCES devices(id),
  FOREIGN KEY (home_id) REFERENCES homes(id)
);
```

---

## 4. Flutter Client Experience

- **`FirmwareUpdateCard`**: Integrated component within Device Management page displaying current installed firmware, update eligibility, interactive download & install action, real-time progress bar, and rollback alerts.
- **`FleetHealthDashboardPage`**: Fleet-wide command center with live KPI metric cards, status filters (All, Updates Available, In Progress, Issues), and interactive maintenance history sheet.
