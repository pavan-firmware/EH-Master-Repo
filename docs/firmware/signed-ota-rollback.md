# EH Home — Signed OTA & Anti-Rollback Architecture

## 1. Scope & Objective
This document specifies the end-to-end cryptographic and runtime verification procedure for delivering firmware updates to EH Home devices in the field.

---

## 2. Partition Configuration (4MB Dual-Slot)

```
[0x000000] Bootloader + Partition Table
[0x009000] nvs (24 KB)
[0x00F000] otadata (8 KB)
[0x011000] phy_init (4 KB)
[0x012000] fact_v2 (16 KB)
[0x020000] ota_0 (1792 KB) -> Slot A
[0x1E0000] ota_1 (1792 KB) -> Slot B
[0x3A0000] storage (384 KB)
```

---

## 3. Cryptographic Verification & Anti-Rollback Rules

1. **Manifest Contract:** Defined in `packages/contracts/ota/ota-manifest.schema.json`.
2. **Hash Integrity:** Device computes SHA-256 over received binary payload and verifies exact match with manifest.
3. **Signature Verification:** Manifest signature validated against release authority public key.
4. **Anti-Rollback Enforced:** `targetVersion >= runningVersion`. Downgrades are rejected by firmware logic.
5. **Bridge Version Requirement:** If `minFirmwareVersion` is specified, `runningVersion >= minFirmwareVersion` is required before upgrading to `targetVersion`.

---

## 4. Automatic Rollback Protection

```
1. Device downloads validated binary into alternate slot (e.g. ota_1).
2. Bootloader flags ota_1 as ESP_OTA_IMG_PENDING_VERIFY and reboots.
3. On boot, watchdog timer starts (10s timeout).
4. Device must:
   a. Initialize hardware peripherals.
   b. Connect to Wi-Fi station.
   c. Perform TLS handshake with MQTT broker.
5. Upon successful connection:
   Device calls esp_ota_mark_app_valid_cancel_rollback().
6. If boot fails or watchdog triggers before step 5:
   Bootloader automatically boots back into previous known-good partition (ota_0).
```
