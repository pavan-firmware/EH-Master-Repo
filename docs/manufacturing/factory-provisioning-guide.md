# EH Home — Factory Provisioning & Staging Guide

## 1. Scope & Security Model
Factory provisioning is the process of generating unique cryptographic identity and physical packaging assets for each manufactured device prior to boxing and shipment.

### Immutable Invariants:
1. **Device ID Format:** Canonical RFC 4122 UUID v4.
2. **Serial Number Format:** `EH-<VARIANT>-<YEAR>W<WEEK>-<SEQUENCE>` (e.g., `EH-SW3X-2026W35-00101`).
3. **Commissioning Secret:** 32-byte (256-bit) cryptographically secure random token.
4. **Per-Device Certificate:** CommonName strictly equals `deviceId`.
5. **No Production Keys in Source Control:** Private keys for the Manufacturing Root CA are held in an offline Hardware Security Module (HSM).

---

## 2. Factory Provisioning Workflow

```
[Factory Staging Server]
       │
       ├─► 1. ca_manager.py: Issue Device mTLS Keypair & Certificate
       ├─► 2. factory_provisioner.py: Generate UUID, Serial, Secret
       ├─► 3. Generate fact_v2 NVS partition binary image
       ├─► 4. Flash binary to offset 0x12000 on ESP32
       ├─► 5. Generate EH1: QR label for physical packaging
       └─► 6. Append entry to manufacturing_audit.json
```

---

## 3. QR Code Payload Format

```
EH1:<deviceId>:<productVariantId>:<commissioningSecretHex>:<setupCode>
```

- **Prefix:** `EH1:` (Canonical EH Home V1 QR protocol identifier).
- **deviceId:** UUID v4 (e.g. `0194fe23-7a1b-7890-a123-456789abcdef`).
- **productVariantId:** Catalog variant string (e.g. `eh-smart-switch-3x`).
- **commissioningSecretHex:** 64-character hexadecimal representation of 32-byte secret.
- **setupCode:** 6-digit numeric backup setup code (e.g. `123456`).

---

## 4. Factory NVS Partition Structure (`fact_v2`)

| NVS Key | Type | Value Example | Description |
|---|---|---|---|
| `dev_id` | string | `0194fe23-7a1b-7890-a123-456789abcdef` | Device UUID v4 |
| `serial` | string | `EH-SW3X-2026W35-00101` | Human-readable serial |
| `comm_sec`| hex2bin | `32 bytes binary` | 256-bit commissioning secret |
| `comm_cons`| uint8 | `0` | Commissioning consumed flag (0=fresh, 1=consumed) |
| `cert_fp` | string | `64 chars hex` | SHA-256 fingerprint of mTLS client cert |
| `is_dev` | uint8 | `0` (Prod) / `1` (Dev) | Development flag |

---

## 5. Execution Command Example

```bash
python tools/manufacturing/factory_provisioner.py \
  --variant eh-smart-switch-3x \
  --hw-rev HW_1_0 \
  --count 100 \
  --out ./build/manufacturing-batch-2026W35
```
