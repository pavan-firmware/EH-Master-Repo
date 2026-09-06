# Phase 39 — Product Catalog Expansion

## 1. Executive Summary

Phase 39 expands the canonical EH Home product catalog from the initial 7 smart switch and socket definitions to 11 canonical product variants by introducing:
1. **Smart Fan (`smart-fan/1x`)**: Multi-step capacitive speed regulator (0..5 levels) with real-time integer fixed-point energy monitoring.
2. **Smart Light / CCT (`smart-light/cct`)**: Tunable white lighting with continuous dimming (0..100) and correlated color temperature control (2700K..6500K), supporting Thread 1.3 and Matter 0x010C.
3. **Smart Hub (`smart-hub/v1`)**: High-performance multi-protocol edge gateway on ESP32-S3 (16MB Flash, 8MB PSRAM) serving as a local automation coordinator and Matter 0x0016 bridge.
4. **Sensor Node (`sensor-node/v1`)**: Low-power environmental monitoring telemetry node on ESP32-C6 with battery/USB DC power and Matter 0x0302 sensor compatibility.

All product definitions are 100% metadata-driven, strictly adhering to the 14 canonical capability contracts and integrating seamlessly into backend discovery, multi-dimensional compatibility evaluation, database migrations, and Flutter UI capability rendering without hardcoded SKU branching.

---

## 2. Expanded Product Families & Canonical SKUs

| Product Variant ID | Product Family | Display Name | Channels | Primary Capabilities | Target Silicon / Profile |
|---|---|---|---|---|---|
| `eh-smart-switch-1x` | `smart_switch` | EH Smart Switch 1X | 1 | `switch`, `relay`, `local_switch`, `energy`, `ota` | ESP32-C6 (16A relay, BL0942) |
| `eh-smart-switch-2x` | `smart_switch` | EH Smart Switch 2X | 2 | `switch`, `relay`, `local_switch`, `energy`, `ota` | ESP32-C6 (10A relay, BL0942) |
| `eh-smart-switch-3x` | `smart_switch` | EH Smart Switch 3X | 3 | `switch`, `relay`, `local_switch`, `energy`, `ota` | ESP32-C6 (10A relay, BL0942) |
| `eh-smart-switch-4x` | `smart_switch` | EH Smart Switch 4X | 4 | `switch`, `relay`, `local_switch`, `energy`, `ota` | ESP32-C6 (10A relay, BL0942) |
| `eh-smart-socket-1x` | `smart_socket` | EH Smart Socket 1X | 1 | `switch`, `relay`, `local_switch`, `energy`, `ota` | ESP32-C6 (16A relay, BL0942) |
| `eh-smart-socket-2x` | `smart_socket` | EH Smart Socket 2X | 2 | `switch`, `relay`, `local_switch`, `energy`, `ota` | ESP32-C6 (16A relay, BL0942) |
| `eh-smart-socket-3x` | `smart_socket` | EH Smart Socket 3X | 3 | `switch`, `relay`, `local_switch`, `energy`, `ota` | ESP32-C6 (16A relay, BL0942) |
| `eh-smart-fan-1x` | `smart_fan` | EH Smart Fan 1X | 1 | `switch`, `relay`, `fan_speed`, `local_switch`, `energy`, `ota` | ESP32-C6 (5A relay, BL0942, Triac/Capacitor) |
| `eh-smart-light-cct` | `smart_lighting` | EH Smart Light CCT | 1 | `switch`, `brightness`, `cct`, `energy`, `ota` | ESP32-C6 (2A driver, Dual-PWM, Matter 0x010C) |
| `eh-smart-hub-v1` | `smart_controller` | EH Smart Hub Gateway V1 | 1 | `switch`, `ota`, `automation`, `schedule` | ESP32-S3 (16MB Flash, 8MB PSRAM, Matter 0x0016) |
| `eh-sensor-node-v1` | `smart_sensor` | EH Environmental Sensor Node V1 | 1 | `switch`, `ota`, `automation`, `schedule` | ESP32-C6 (I2C/DHT, Battery/USB DC, Matter 0x0302) |

---

## 3. Canonical Capability Reuse & Schema Compliance

The new definitions strictly reuse the canonical 14 capabilities defined in `packages/contracts/capability/capability-registry.json`:
1. `switch`: Binary power state (`power: boolean`).
2. `relay`: Electromechanical relay state (`closed: boolean`).
3. `local_switch`: Physical manual switch toggle/held event.
4. `energy`: Deterministic fixed-point electrical metering (`e_tot_wh`, `p_mw`).
5. `voltage`: AC RMS voltage measurement (`v_mv`).
6. `current`: AC load current measurement (`i_ma`).
7. `power`: Active real-time power draw (`p_mw`).
8. `fan_speed`: Multi-step speed regulation (`speed: 0..5`).
9. `brightness`: Phase-cut or PWM dimming level (`level: 0..100`).
10. `cct`: Tunable white color temperature (`tempK: 2700..6500`).
11. `ota`: Dual-partition cryptographic firmware update support.
12. `automation`: Local edge trigger-action participation.
13. `scene`: Preset activation target.
14. `schedule`: RTC-backed local execution target.

No ad-hoc, proprietary, or SKU-specific capability names were introduced.

---

## 4. Metadata-Driven Architecture & UI Rendering

### 4.1 Backend Architecture
- **Filesystem Authority**: Product variants are canonically stored in `product-definitions/{family}/{variant}/metadata.json`.
- **Indexing & Discovery**: `ProductCatalogService` automatically discovers, normalizes, indexes, and queries variants by category, family, capability, and connectivity profiles.
- **Compatibility Resolver**: Multi-dimensional verification checks silicon, hardware revision, firmware version, home wireless availability (Wi-Fi, BLE, Thread), and Matter fabric capabilities.
- **Database Seed (Migration 027)**: Seeds PostgreSQL tables `product_families`, `product_models`, `products`, `product_variants` with symmetric UP and DOWN lifecycle.

### 4.2 Flutter Capability Engine
- **`CapabilityResolver`**: Transforms backend product metadata into `ResolvedDevice` models.
- **`CapabilityRendererRegistry`**: Dynamically maps resolved channel capabilities to UI widgets (`EHFanSpeedDial`, `EHDimmerSlider`, `EHCCTDial`, `EHSwitchCard`, `EHEnergyCard`).
- Zero SKU conditionals in Flutter widget trees; UI controls are purely derived from channel capability arrays and configuration bounds.

---

## 5. Security & Hardware Boundary Disclaimer

### 5.1 Zero Secret Storage
- Product metadata contains zero credentials, private keys, authentication tokens, Wi-Fi keys, or factory secrets.
- All product definitions are safe for public caching and API distribution.

### 5.2 Physical Hardware Validation Limitations
> [!IMPORTANT]
> **Physical Hardware Validation: NOT RUN**
>
> Phase 39 validates product metadata schemas, JSON contract compliance, backend catalog discovery, database migration symmetry, compatibility evaluation, and Flutter UI capability resolution.
>
> It does **NOT** prove that physical production silicon, RF antennas, PCB traces, high-voltage safety clearances, or physical fan/CCT driver hardware have undergone laboratory electrical or RF compliance certification. Physical validation remains designated for subsequent test fixtures and factory testing.
