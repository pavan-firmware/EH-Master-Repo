# EH Home — Production Flutter Mobile Application (`smart_home_application_v1`)

The **EH Home** mobile and tablet application is built with Flutter 3.x and Dart 3.x, designed for high-availability smart-home management. It provides deterministic device control, real-time telemetry, local-first offline execution, dynamic catalog resolution, and role-based access control.

---

## 1. Key Architectural Features

- **Local-First & Zero-Touch LAN Switchover:** Direct LAN UDP discovery (`port 4210`) and HTTP actuator control (`POST http://<device-ip>/api/v1/relays/control`) with `<15ms` response latency. Automatically falls back to cloud SSE/MQTT when off-network.
- **Stale-While-Revalidate & Offline Resilience:** Cold starts, resume events, and background screenshot transitions render cached home and system telemetry instantly without flashing blank screens or triggering infinite spinners.
- **Strict Role-Based Access Control (RBAC):**
  - **`OWNER`**: Full administrative authority over home configurations, disaster recovery checkpoints, device security trust certificates, member management, and electricity tariffs.
  - **`ADMIN`**: Household room management, routine scheduling, and device onboarding.
  - **`MEMBER` / `GUEST`**: Day-to-day actuator toggling and scene activation with automatic gating from sensitive administrative pages (`AdminAccessRequiredView`).
- **Full Theme Engine & Dark-Mode Contrast:** Dynamic semantic token architecture (`context.ehColors`) ensuring high-contrast readability across all surfaces in both light and dark themes.
- **Intelligent Notification Filtering:** High-frequency routine command toggles are filtered out of the user alert stream (`isRoutineControlOperation`), preventing notification flooding while strictly preserving explicit hardware alerts (breaker trip, tamper, high power).
- **Dynamic Product Catalog Resolution:** Metadata-driven capability engine dynamically generates UI controls and telemetry tiles from product definitions rather than using hardcoded per-SKU screens.
- **Energy Intelligence & Dynamic Tariffs:** Localized monetary and consumption tracking with home-aware currency support (`INR`, `USD`) and time-of-use (ToU) utility rate blocks.
- **Secure BLE Provisioning:** Implements the `EH-PROV/1` protocol with HKDF-SHA256 key derivation, AES-256-GCM encryption, and transcript confirmation.

---

## 2. Directory Structure

```
smart_home_application_v1/
├── lib/
│   ├── app/                     # App lifecycle, navigation shell, controllers (HomeController)
│   ├── core/
│   │   ├── api/                 # ApiClient, SSE client, HTTP interceptors
│   │   ├── config/              # AppConfig & device connection configuration
│   │   ├── models/              # Immutable domain entities, energy models, access control
│   │   ├── repositories/        # Cloud and local repositories (Settings, Notifications, Sync)
│   │   ├── services/            # DeviceStorageService, LocalLanDeviceService, RealtimeEventService
│   │   ├── theme/               # Semantic color tokens (EhColors, SettingsColors), light/dark themes
│   │   └── utils/               # Event classification, time formatting, validators
│   ├── features/
│   │   ├── auth/                # Login, session restoration, profile completion
│   │   ├── connectivity/        # Multi-protocol connectivity & link metrics
│   │   ├── context/             # Presence detection & home context precedence modes
│   │   ├── dashboard/           # Home dashboard, quick actions, Cloud Sync sheet
│   │   ├── device_trust/        # Cryptographic trust certificates, attestation, revocation
│   │   ├── edge_control/        # Edge execution dashboard, LAN sweeps, routine synchronization
│   │   ├── energy/              # Energy optimization engine, tariff editor, consumption charts
│   │   ├── onboarding/          # Bluetooth commissioning, QR scanning, home creation
│   │   ├── operations/          # Operations health, diagnostics, transport telemetry
│   │   ├── recovery/            # Disaster recovery snapshots, backup archives, restoration
│   │   ├── routines/            # Routine builder, weekly scheduler, edge routine push
│   │   └── settings/            # Advanced fleet operations, home profile, legal & privacy
│   └── main.dart                # Application entrypoint
├── test/                        # 70+ widget, unit, integration, and regression test suites
└── pubspec.yaml                 # Flutter dependencies and asset declarations
```

---

## 3. Development & Testing

### Getting Dependencies
```bash
flutter pub get
```

### Static Analysis
Ensure zero warnings and zero analyzer issues:
```bash
flutter analyze
```

### Running Test Suites
Execute all unit and widget tests:
```bash
flutter test
```

Or run targeted phase test suites:
```bash
# Phase 36: Authentication & Navigation Lifecycle
flutter test test/phase36_flutter_runtime_auth_navigation_test.dart

# Phase 28: Edge Control & Local LAN Execution
flutter test test/phase28_local_first_edge_control_test.dart

# Phase 32: Device Trust & Security Attestation
flutter test test/phase32_device_trust_test.dart
```
