# EH Home — Phase 5 Firmware Reuse Matrix & Security Classification

## 1. Overview
This document evaluates all legacy firmware source files in `firmware/legacy-v1/node/main/` for Phase 5 Secure Device Onboarding, Provisioning, and Claiming.

Legacy code in `firmware/legacy-v1/` remains untouched as historical reference. Production abstractions adapt and extend these proven concepts.

---

## 2. Firmware Reuse Matrix

| Legacy File | Purpose / Responsibility | Current Behavior | Classification | Target Component / Action | Security & Compatibility Notes |
|---|---|---|---|---|---|
| `ble_server.c` | NimBLE stack initialization, BLE GAP advertising, and GATT service definition | Advertises custom 128-bit service UUID (`12345678-1234-5678-1234-56789abcdef0`) with telemetry and status characteristics | **REUSE WITH ADAPTATION** | Commissioning Transport Layer | Custom 128-bit UUID service and NimBLE advertising foundation reused. Must add authenticated `EH-PROV/1` commissioning characteristic with explicit read/write access control. |
| `factory_identity.c` | Immutable device identity persistence in NVS (`nvs_flash`) | Reads/writes device serial number and UUID-like hex string from/to NVS key `factory_id` | **REUSE WITH ADAPTATION** | Device Identity & Secure Storage | NVS storage pattern reused. Format MUST conform to canonical `device-identity.schema.json` UUID (e.g. `c0a80101-0000-4000-8000-000000000001`), rejecting raw non-UUID hex strings. |
| `node_identity.c` | Legacy node identity helper | Generates MAC-based node string identifier | **OBSOLETE** | Device Identity Boundary | MAC address MUST NOT be used as `deviceId`. Immutable canonical UUID `deviceId` is authoritative. |
| `node_protocol.c` | Legacy protocol parser | Binary packet header parsing and payload deserialization | **REFERENCE ONLY** | Commissioning Framing Protocol | Referenced for packet framing ideas. Production commissioning uses `EH-PROV/1` protocol with sequence nonces and session auth. |
| `product_profile.c` | Hardware profile definitions | Exposes hardware variant capability flags | **REUSE DIRECTLY** | Product Catalog Integration | Reused directly in product variant validation (`product-definitions/`). |
| `device_info.c` | System & firmware version metadata | Returns firmware family and hardware revision string | **REUSE DIRECTLY** | Device Identity Service | Reused directly for hardware revision and firmware family verification. |
| `user_configuration.c` | User settings persistence in NVS | Saves Wi-Fi SSID and password to NVS `wifi_cfg` | **REUSE WITH ADAPTATION** | Secure Provisioning Storage | Reused for Wi-Fi credential persistence, ensuring credentials are stored in encrypted NVS partitions (`nvs_sec`) and never exposed via readable GATT characteristics. |

---

## 3. Protocol Versioning & Security Guidelines

### Protocol Identifier
* **Version:** `EH-PROV/1`

### Security Boundary Constraints
1. **Unauthenticated BLE Protection:** Unauthenticated BLE GATT characteristics MUST NOT allow reading or writing Wi-Fi passwords, MQTT keys, or backend secrets.
2. **Session Authentication:** Commissioning session establishment requires cryptographic proof (`appChallenge` + `deviceChallenge` + session token).
3. **Session Expiration:** Commissioning session expires after 300 seconds of inactivity or upon completion/failure.
4. **Single Session Rule:** Only 1 active commissioning session is permitted per device at a time.
5. **Replay Protection:** Every commissioning packet contains a 32-bit incrementing sequence number and session nonce.
