# EH Home — Manufacturing QR Code & Thermal Label Printing Architecture (Part 10)

## 1. Overview & Objectives

Part 10 establishes the secure, deterministic, manufacturing label-printing and 2D QR-code generation foundation for the EH Home production bench. It directly consumes verified device traceability records from Part 09 and renders high-density thermal adhesive labels (TSPL) and traveler receipts (ESC/POS) without exposing cryptographic secrets or credentials.

```
+---------------------------------------+
|  Part 09 Traceability Record          |
|  (deviceId, serialNumber, traceId)    |
+---------------------------------------+
                   |
                   v
+---------------------------------------+
|  Deterministic Label Data Model       |
|  (Zero-Secret Assertions & Canonical) |
+---------------------------------------+
                   |
                   v
+---------------------------------------+
|  8-Gate Print Safety Validation       |
|  (Pre-Print Execution Block)          |
+---------------------------------------+
        |                       |
        v                       v
+-------------------+   +--------------------+
| TSPL Generator    |   | ESC/POS Generator  |
| (50x30mm/40x20mm) |   | (Traveler Receipt) |
+-------------------+   +--------------------+
        |                       |
        v                       v
+---------------------------------------+
|  Tauri Native Print Command Boundary  |
|  (Strict Input Validation / Spooler)  |
+---------------------------------------+
```

---

## 2. Canonical Opaque QR Payload Architecture

### Opaque URI Schema
All EH Home consumer and device onboarding QR codes strictly adhere to the opaque token scheme defined in `packages/contracts/src/qr/index.ts`:

```
eh://p/v1?t=<OPAQUE_TOKEN>
```

* **Scheme**: `eh`
* **Path**: `/p/v1` (Provisioning Protocol Version 1)
* **Parameter**: `t` (Opaque high-entropy cryptographic token, 16–64 characters matching `/^[A-Za-z0-9_-]{16,64}$/`)

### Zero-Secret Invariant
The QR code is an **opaque resolution token**, NOT a credential carrier. The payload strictly prohibits:
* Commissioning secrets
* Wi-Fi passwords and SSIDs
* Private keys (RSA/ECC)
* Client/device TLS certificates or private keys
* Factory CA or Intermediate CA private keys
* Passwords, PINs, or raw authentication tokens

When the mobile app scans `eh://p/v1?t=<token>`, it contacts the authorized backend (`apps/api`) via TLS to resolve the device identity and initiate an authenticated, ephemeral session (`EH-PROV/1`).

---

## 3. Label Data Model & Template Engine

The label data model is defined by `LabelDataModelSchema` in `@eh-home/contracts`:

| Field | Type | Description |
| :--- | :--- | :--- |
| `schemaVersion` | `number` | Version 1 |
| `brand` | `'EH Home'` | Canonical brand name |
| `deviceId` | `UUID` | Verified device UUID v4 from Part 09 |
| `serialNumber` | `string` | Canonical serial (e.g. `EH-SW3X-2026W39-00001`) |
| `productVariantId`| `string` | Canonical variant (e.g. `eh-smart-switch-3x`) |
| `productDisplayName`| `string` | Human-friendly name (e.g. `EH Smart Switch 3-Gang`) |
| `hardwareRevision`| `string` | Certified HW revision (canonical `HW_1_0`, `HW_1_1`) |
| `firmwareFamily` | `string` | Verified family (e.g. `esp32c6-switch-platform`) |
| `firmwareVersion` | `string` | Verified release version (e.g. `1.0.0`) |
| `qrUri` | `string` | Canonical `eh://p/v1?t=<token>` URI |
| `qrToken` | `string` | Opaque high-entropy token (16–64 chars) |
| `traceId` | `UUID` (optional) | Part 09 traceability correlation ID |
| `templateId` | `enum` | Certified template version |

### Supported Templates
1. **`device-primary-50x30-v1`**:
   - Physical dimensions: 50mm width x 30mm height (400 x 240 dots at 203 DPI)
   - Layout: Brand, Model, Hardware Revision, Firmware Version, 2D QR Code (Module 4, ECC M), 1D Code128 Barcode, Serial Number, Short UUID.
2. **`device-compact-40x20-v1`**:
   - Physical dimensions: 40mm width x 20mm height (320 x 160 dots at 203 DPI)
   - Layout: Compact variant ID, Hardware Revision, Serial Number, QR Code.
3. **`box-receipt-escpos-v1`**:
   - Continuous receipt roll (58mm/80mm) traveler slip for quality station logging.

---

## 4. TSPL Printer Support

TSPL (Taiwan Semiconductor Printing Language) is the primary manufacturing protocol for thermal label printers with gap sensing (e.g. TSC TE200, Zebra ZD421 in TSPL mode).

### Deterministic Command Construction
A deterministic TSPL job produces identical byte streams for identical inputs:

```ts
SIZE 50 mm,30 mm
GAP 2 mm,0 mm
SPEED 4
DENSITY 8
DIRECTION 1
REFERENCE 0,0
CLS
TEXT 16,14,"3",0,1,1,"EH Home"
TEXT 16,42,"2",0,1,1,"EH Smart Switch 3-Gang"
TEXT 16,66,"1",0,1,1,"Model: eh-smart-switch-3x"
TEXT 16,84,"1",0,1,1,"HW: HW_1_0 | FW: v1.0.0"
QRCODE 256,14,M,4,A,0,"eh://p/v1?t=..."
BARCODE 16,112,"128",38,0,0,2,2,"EH-SW3X-2026W39-00001"
TEXT 16,156,"2",0,1,1,"SN: EH-SW3X-2026W39-00001"
TEXT 16,182,"1",0,1,1,"ID: 0194fe23-7a1b-7890... [SEC-OPQ]"
PRINT 1,1
```

### Command Injection Prevention
All string fields passed into TSPL formatting pass through `sanitizeTsplString`:
- Replaces newline and carriage return characters (`\r`, `\n`, `\0`) with whitespace.
- Escapes or converts double-quotes (`"`) to single-quotes (`'`).
- Truncates fields to safe bounds, preventing buffer overruns and arbitrary TSPL command injection.

---

## 5. ESC/POS Status

- **Primary Device Label Protocol**: **TSPL** is the authoritative protocol for adhesive product labels due to precise label gap/black-mark sensors and fixed dimensions.
- **ESC/POS Support**: ESC/POS is implemented as an auxiliary receipt/slip adapter (`generateReceiptEscPos`) for continuous-roll paper traveler slips at bench stations.
- No duplicate printer abstractions are created; `IPrinterService` routes jobs based on the typed `PrinterProtocol` (`'TSPL'` or `'ESCPOS'`).

---

## 6. The 8 Print Safety Gates

Printing is strictly blocked unless all 8 sequential validation gates pass:

1. **Gate 1 — `DEVICE_RECORD_EXISTS`**: Device identifier must be a valid, non-nil UUID v4.
2. **Gate 2 — `SERIAL_NUMBER_VALID`**: Serial number must match canonical format `^EH-[A-Z0-9]+-\d{4}W\d{2}-\d{5}$`.
3. **Gate 3 — `PRODUCT_VARIANT_CANONICAL`**: Product variant ID must exist in the canonical approved catalog (`eh-smart-switch-1x` ... `eh-sensor-node-v1`).
4. **Gate 4 — `HARDWARE_REVISION_VALID`**: Hardware revision must be canonical (`HW_1_0`, `HW_1_1`).
5. **Gate 5 — `QR_PAYLOAD_VALID`**: QR URI must strictly match `eh://p/v1?t=<token>` with token length 16–64 characters.
6. **Gate 6 — `TEMPLATE_SUPPORTED`**: Template identifier must be in the approved template catalog.
7. **Gate 7 — `PRINTER_PROTOCOL_SUPPORTED`**: Protocol must be allowlisted (`TSPL` or `ESCPOS`).
8. **Gate 8 — `ZERO_SECRET_CONTENT`**: Recursive regex scan ensures no private keys, passwords, or secrets exist in any printable field.

---

## 7. Tauri Native Printer Command Boundary

Printing from the desktop application is restricted to a typed native command in `apps/desktop/src-tauri/src/commands.rs`:

```rust
pub fn print_label_native(request: PrintLabelNativeRequest) -> Result<PrintLabelNativeResponse, String>
```

- **Printer ID Validation**: Must be alphanumeric with underscores/dashes, maximum 64 chars.
- **Protocol Allowlist**: Rejects anything other than `TSPL` and `ESCPOS`.
- **Copies Range**: Enforces `1 <= copies <= 100`.
- **Payload Bounds**: Enforces maximum payload size of 16 KB.
- **Native Secret Scan**: Scans raw payload for `private key`, `wifi_password`, `commissioning_secret` before dispatching to printer spooler.
- **Zero Shell Execution**: No arbitrary shell commands or external executables are invoked.

---

## 8. Physical Printer Smoke Test Procedure

When a physical thermal printer (e.g. TSC TE200, Zebra ZD421) is connected via USB:
1. Verify thermal paper roll (50mm x 30mm gap label) is loaded and sensor calibrated.
2. Connect USB cable; identify system printer queue (e.g. `PRINTER_TSC_TE200` on Windows Spooler).
3. Open EH Home Desktop App -> Navigate to **Label & QR Printer** tab.
4. Select provisioned device record and choose `device-primary-50x30-v1`.
5. Verify 8/8 Safety Gates pass in the UI checklist.
6. Click **Validate & Print Thermal Label**.
7. Confirm printed label has:
   - High-contrast, scannable QR code.
   - Legible human-readable serial number and barcode.
   - Clean alignment without horizontal/vertical drift.
8. Scan QR code using smartphone camera or handheld 2D scanner; verify URI starts with `eh://p/v1?t=`.
