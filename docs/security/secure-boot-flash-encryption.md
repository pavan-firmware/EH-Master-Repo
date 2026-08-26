# EH Home — Secure Boot v2 & Flash Encryption Guide

## 1. Security Architecture Overview
In commercial deployment, physical access to the ESP32 must not allow firmware tampering, extraction of mTLS private keys, or bypassing of authentication tokens.

EH Home implements a multi-layered hardware security model on the ESP32-C6 / ESP32-C3:

1. **Hardware Root of Trust:** eFuse-burned public key hash for Secure Boot v2.
2. **Flash Encryption:** Transparent AES-XTS-256 hardware encryption of SPI flash.
3. **Dual-Slot Signed OTA:** Anti-rollback verification and Ed25519 signature enforcement.
4. **Commissioning Secret Ephemerality:** Hardware locking of secret access post-commissioning.

---

## 2. Secure Boot v2 Workflow

```
[Power On / Reset]
       │
       ▼
[ROM Bootloader]
       │ Reads Public Key Hash from eFuse
       │ Verifies RSA-3072 / ECDSA Signature of 2nd Stage Bootloader
       ▼
[2nd Stage Bootloader]
       │ Verifies Signature of Application Image (ota_0 or ota_1)
       ▼
[ESP-IDF Application]
       │ Executes securely
```

### Production eFuse Configuration
- `SECURE_BOOT_EN`: Set to `1` (irreversible).
- `SECURE_BOOT_KEY`: 384-bit/256-bit digest of OEM signing key.
- `DIS_PAD_JTAG`: Set to `1` to disable hardware JTAG debugging in production.
- `DIS_DOWNLOAD_MODE`: Set to `1` to disable ROM UART bootloader.

---

## 3. Flash Encryption Workflow
- Key generated internally by true random number generator (TRNG) on first boot and written to write-protected eFuse `FLASH_CRYPT_KEY`.
- All flash partitions (code, NVS, SPIFFS) are encrypted on-the-fly by the hardware AES peripheral.
- Protects the per-device mTLS client private key stored in `fact_v2`.

---

## 4. OTA Firmware Verification & Rollback Policy

### Integrity & Signature Verification
1. Manifest signed by release engineering with Ed25519.
2. Device validates:
   - `sha256(downloaded_bytes) == manifest.sha256`
   - `manifest.version >= running_version` (Anti-Rollback)
   - `running_version >= manifest.minFirmwareVersion` (Bridge requirement)
3. Firmware written to alternate partition (e.g. `ota_1`).

### Automatic Bootloader Rollback
1. Bootloader sets new partition state to `ESP_OTA_IMG_PENDING_VERIFY`.
2. Device boots new application image.
3. If device crashes in boot loop or fails Wi-Fi/MQTT connection within watchdog timeout, the hardware watchdog resets the MCU.
4. Bootloader detects unconfirmed image and automatically rolls back to previous known-good partition (`ota_0`).
5. On successful connection, application executes `esp_ota_mark_app_valid_cancel_rollback()`, finalizing the update.
