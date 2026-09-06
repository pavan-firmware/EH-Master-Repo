# Phase 40 — Manufacturing Flasher CLI & Hardware Validation Architecture

**Author:** EH Platform Engineering  
**Revision:** 1.0.0 (Phase 40 Release)  
**Target Silicon:** ESP32-C6, ESP32-C3, ESP32-S3, ESP32-D0WD  

---

## 1. Overview & Architecture

The EH Home Manufacturing Flasher CLI (`tools/manufacturing/flash_device.py`) provides an automated, deterministic factory programming tool designed for assembly lines, hardware engineering benches, and staging environments.

### Core Architecture Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Port & Silicon │ ──> │ Dynamic Partition│ ──> │ Product Catalog  │
│  Auto-Detection │     │  Table Parser    │     │ Compatibility    │
└─────────────────┘     └──────────────────┘     └──────────────────┘
                                                           │
                                                           ▼
┌─────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Post-Flash     │ <── │ Esptool Flashing │ <── │ Factory Identity │
│  Verification   │     │  (Multi-region)  │     │ (fact_v2 NVS)    │
└─────────────────┘     └──────────────────┘     └──────────────────┘
        │
        ▼
┌─────────────────┐
│ Bounded Silicon │
│ Lifecycle Test  │
└─────────────────┘
```

---

## 2. Dynamic Partition Layout Resolution

Partition offsets are **never** hard-coded. The flasher dynamically parses `partitions.csv` (or binary partition tables) for each target product:

```csv
# ESP-IDF Partition Table for EH Smart Switch (4MB Flash)
# Name,      Type, SubType, Offset,   Size,     Flags
nvs,         data, nvs,     0x9000,   24K,
otadata,     data, ota,     0xF000,   8K,
phy_init,    data, phy,     0x11000,  4K,
fact_v2,     data, nvs,     0x12000,  16K,
ota_0,       app,  ota_0,   0x20000,  1792K,
ota_1,       app,  ota_1,   0x1E0000, 1792K,
storage,     data, spiffs,  0x3A0000, 384K,
```

### Partition Map Verification Rules
- **No Overlaps:** Each partition's `offset + size` must not exceed the next partition's start offset.
- **Capacity Limits:** Binary artifact byte size must be strictly $\le$ partition size.
- **Required Partitions:** Every production image must include `fact_v2`, `nvs`, and `ota_0`.

---

## 3. CLI Subcommands & Operational Usage

### 3.1 Device Detection
Scans available host serial ports, filters candidate USB-to-UART bridges, and queries ESP32 silicon parameters:

```bash
# Human-readable detection
python tools/manufacturing/flash_device.py detect

# Machine-readable JSON output
python tools/manufacturing/flash_device.py detect --json
```

### 3.2 Factory Device Flashing
Executes the multi-stage programming sequence (silicon check $\to$ compatibility check $\to$ identity generation $\to$ write flash $\to$ reset $\to$ boot verification):

```bash
# Interactive flashing
python tools/manufacturing/flash_device.py flash \
    --port COM6 \
    --product eh-smart-switch-3x

# Batch non-interactive manufacturing mode (requires explicit port and product)
python tools/manufacturing/flash_device.py flash \
    --port COM6 \
    --product eh-smart-switch-3x \
    --non-interactive \
    --json
```

### 3.3 Post-Flash Verification
Non-destructively connects to a programmed device, executes a clean hardware reset pulse, captures serial boot logs, and confirms runtime state:

```bash
python tools/manufacturing/flash_device.py verify \
    --port COM6 \
    --product eh-smart-switch-3x \
    --json
```

### 3.4 Hardware Lifecycle Validation
Performs bounded silicon lifecycle steps (silicon detection, partition loading, `fact_v2` loading, device UUID integrity, relay manager initialization, and `FACTORY_NEW` state):

```bash
python tools/manufacturing/flash_device.py lifecycle \
    --port COM6 \
    --json
```

### 3.5 Factory Reset & Identity Preservation
Erases runtime network credentials from the `nvs` partition while **strictly preserving** the authoritative `fact_v2` manufacturing identity:

```bash
python tools/manufacturing/flash_device.py reset \
    --port COM6 \
    --json
```

---

## 4. Factory Identity (`fact_v2`) Invariant

The `fact_v2` partition represents the immutable manufacturing identity created at factory assembly:

```
+-------------------------------------------------------------------+
| Namespace: fact_v2                                                |
+-------------------+-----------------------------------------------+
| dev_id            | UUID v4 (e.g. 4444688e-989d-458e-...)         |
| serial            | EH-<PRODUCT>-<YEAR>W<WEEK>-<SEQ>              |
| comm_sec          | 256-bit cryptographically random secret (bin) |
| comm_cons         | u8: 0 (Unclaimed) -> 1 (Claimed)              |
| cert_fp           | SHA-256 fingerprint of mTLS device cert       |
| is_dev            | u8: 1 (Dev) / 0 (Production)                  |
+-------------------+-----------------------------------------------+
```

### Critical Identity Invariants
1. **Never Re-generate on Reset:** Factory reset clears runtime `nvs` (`0x9000`) but **never** regenerates Device ID, Serial Number, or certificates.
2. **Authoritative Cloud Link:** Device ID in `fact_v2` matches the mTLS Common Name ($CN$) in the device certificate.
3. **Secret Redaction:** Flasher logs automatically mask 256-bit commissioning secret hex strings.

---

## 5. Error Recovery & Safety Boundaries

| Failure Scenario | Flasher Behavior | Safe Recovery Action |
|------------------|------------------|----------------------|
| **Serial Disconnection** | Aborts immediately with `FAIL` status. | Reconnect USB cable and retry detection. |
| **Partition Overlap** | Rejects layout before flashing. | Fix `partitions.csv` and re-validate. |
| **Silicon Mismatch** | Halts with compatibility error unless `--force` is set. | Verify product profile matches physical device. |
| **Verification Timeout** | Marks device as `FAIL` with log summary. | Inspect UART baud rate and reset pin circuit. |
| **Ambiguous Selection** | Refuses to flash if multiple candidates found. | Provide explicit `--port <PORT>` parameter. |

---

## 6. Claim Boundaries & Certification Notice

- **Verified on Hardware:** Real ESP32 silicon boot, partition mapping, `fact_v2` storage, and relay GPIO state on `COM6`.
- **Not Certified by Phase 40:** High-voltage AC load safety, Matter ecosystem interoperability, RF emissions, or mass production line qualification.
