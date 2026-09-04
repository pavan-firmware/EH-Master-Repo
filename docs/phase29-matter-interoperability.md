# Phase 29 — Matter Ecosystem Interoperability & Multi-Platform Home Integration

## 1. Architectural Overview

Phase 29 delivers a production-grade Matter Ecosystem Interoperability and Multi-Platform Home Integration architecture for the EH Home ecosystem. It enables eligible EH products and devices to seamlessly participate in Matter ecosystems (such as Apple Home, Google Home, Amazon Alexa, Samsung SmartThings, and Home Assistant) while preserving:
- **EH State Authority**: Physical device confirmation is strictly required before updating actual state. Desired state commands from external ecosystems are never assumed to have executed until hardware confirmation is received.
- **EH Ownership Sovereignty**: Multi-admin fabric membership enables external controller access without transferring or replacing EH Home ownership, access control policies, or user permissions.
- **Capability-Driven Matter Mapping**: Exposes only Matter clusters and attributes directly backed by validated device capability metadata (e.g. On/Off for switches, Level Control for dimmers, Color Control for CCT/RGB, Electrical Measurement only when hardware energy metering is active).
- **Provider-Neutral Interoperability**: Abstract platform adapter pattern (`SmartHomePlatformAdapter`) with specialized provider implementations isolating platform-specific translation.
- **Local-First Execution Reuse**: External Matter commands route through the existing Phase 28 `ExecutionRoutingService` and `LocalExecutionService`.
- **Factory Reset Reconciliation**: Cleanly revokes fabrics, resets commissioning windows, and clears stale external platform links without erasing immutable factory identity.

---

## 2. Capability-Driven Matter Cluster Mapping

Matter clusters and features are mapped strictly based on validated product and device capabilities:

| EH Capability | Product Metadata Trigger | Matter Cluster | Cluster ID | Supported Features / Attributes |
| :--- | :--- | :--- | :--- | :--- |
| `switch` | `channels` / relay presence | On/Off | `0x0006` | `OnOff`, `GlobalSceneControl`, `OnTime`, `OffWaitTime` |
| `dimmer` / `brightness` | `isDimmable: true` | Level Control | `0x0008` | `CurrentLevel`, `MinLevel`, `MaxLevel`, `OnOffTransitionTime` |
| `cct` / `rgb` | `colorMode: 'CCT' \| 'RGB'` | Color Control | `0x0300` | `ColorMode`, `EnhancedCurrentHue`, `ColorTemperatureMireds` |
| `fan_speed` | `fanLevels > 0` | Fan Control | `0x0202` | `FanMode`, `FanModeSequence`, `PercentSetting`, `PercentCurrent` |
| `energy` | `hasEnergyMetering: true` | Electrical Measurement | `0x0B04` | `ActivePower`, `RMSVoltage`, `RMSCurrent` |
| `temperature_sensor` | `hasSensor: true` | Temperature Measurement | `0x0402` | `MeasuredValue`, `MinMeasuredValue`, `MaxMeasuredValue` |
| `humidity_sensor` | `hasSensor: true` | Relative Humidity | `0x0405` | `MeasuredValue`, `MinMeasuredValue`, `MaxMeasuredValue` |

> [!IMPORTANT]
> Clusters are NEVER inferred from broad category names. If a device has `switch` but lacks energy metering hardware (`hasEnergyMetering: false`), cluster `0x0B04` is omitted entirely.

---

## 3. Command & State Synchronization Flow

```
External Matter Controller (Apple Home / Google Home / Alexa)
             │
             ▼
     Matter Command Handler (MatterStateSyncService)
             │
             ├── 1. Authentication & RBAC Check (Home/Fabric Membership)
             ├── 2. Capability Validation (Cluster & Attribute Support)
             ├── 3. Deduplication Check (eventId / correlationId)
             │
             ▼
     Existing Execution Routing (Phase 28 ExecutionRoutingService)
             │
             ├── Route: LOCAL (LAN MQTT / UDP / CoAP) or CLOUD
             ▼
       Physical Device (Hardware Execution)
             │
             ▼
    Actual State Confirmation (Confirmed Payload)
             │
             ▼
     EH Actual State Engine (DeviceService / State Store)
             │
             ├── Update EH App & Cloud State
             └── Matter State Update (ReportAttributes / Event)
```

---

## 4. Multi-Fabric & Ownership Boundary

- **EH Ownership**: Governed by EH Account, Home, and RBAC rules (Owner, Admin, Member, Guest).
- **Matter Fabric**: A cryptographic administrative domain establishing secure CASE sessions with external controllers.
- **Multi-Admin Commissioning**: Devices support up to 5 concurrent active fabrics. Adding or revoking a Matter fabric does NOT affect EH ownership, and external controllers cannot modify EH membership or grant ownership privileges.

---

## 5. Factory Reset Reconciliation

When a device undergoes a factory reset:
1. All active Matter fabrics are revoked (`REVOKED`).
2. Matter commissioning state returns to `NOT_COMMISSIONED`.
3. Commissioning windows and sessions are closed.
4. Stale external platform links are set to `DISCONNECTED`.
5. Device immutable hardware identity (Vendor ID, Product ID, Serial Number) is preserved.

---

## 6. Certification & Compliance Transparency

| Standard / Ecosystem | Implementation Status | Certification Status |
| :--- | :--- | :--- |
| **Matter Core Protocol** | Software Implemented & Contract Tested | **NOT CLAIMED** |
| **Apple Home (HomeKit)** | Software Implemented & Contract Tested | **NOT CLAIMED** |
| **Google Home** | Software Implemented & Contract Tested | **NOT CLAIMED** |
| **Amazon Alexa** | Software Implemented & Contract Tested | **NOT CLAIMED** |
| **Physical Hardware** | Architecture & Protocol Validated | **NOT RUN** |
