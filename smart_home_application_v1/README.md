# Haven Home

A consumer-focused Flutter app prototype for the smart-home hub project.

## Included

- Calm, responsive five-tab home experience: Home, Rooms, Automations, Activity, and Settings.
- Plain-language safety alert and acknowledgement flow.
- Room controls, automation templates, guided nearby-device setup, system update progress, diagnostics, technical details, and factory-reset confirmation.
- Android and iOS permission declarations for the planned nearby-device and local-network flows.
- A starter widget test for the home dashboard.
- A typed `HomeController` boundary for acknowledged device commands and temporary local state.
- Typed device, command, firmware-release, and firmware-job models in `lib/core/models/`.
- A provider-neutral `HomeRepository` contract with a local fake implementation in `lib/core/repositories/`.
- A typed connection lifecycle (`notConfigured`, `connecting`, `connected`, `offline`, `failed`) shared by the setup screen and dashboard.
- A `ConnectionRepository` boundary for BLE discovery, secure identification, Wi-Fi provisioning, and verification. The default adapter refuses to claim success until the real ESP32 contract is configured.

## Integration boundary

The interface currently uses simulated local state so it can be reviewed without hardware or backend services. `lib/app/home_controller.dart` is the first integration boundary: replace its temporary command delays with repositories for the agreed BLE GATT, local hub, cloud shadow/event, and update-job contracts when those services are available. Keep the customer-facing wording unchanged: technical protocol and firmware details belong only in the owner-only Technical details/support flow.

## Code structure

- `lib/main.dart` — application entry point only.
- `lib/app/` — theme/app setup, navigation shell, and app-level controller.
- `lib/features/<feature>/presentation/` — self-contained screens for dashboard, rooms, routines, activity, settings, alerts, setup, updates, and diagnostics.

As real integrations are introduced, add each feature's `domain/` and `data/` folders alongside `presentation/`; keep BLE, local-hub, cloud, and persistence code out of widgets.

## Hardware values required for real connection

Before enabling the real Bluetooth/Wi-Fi flow, provide the approved ESP32 contract:

- ESP32 part number and firmware protocol version.
- BLE service UUID.
- Provisioning, command, and event characteristic UUIDs, including read/write/notify properties.
- Device-name prefix and whether scanning uses manufacturer data or service UUID filtering.
- QR bootstrap payload format and challenge-response message format.
- Wi-Fi provisioning request/response format and completion event.
- Command envelope fields, acknowledgement states, timeout, and error codes.
- Whether local control uses BLE only after setup or also a local HTTPS/WebSocket hub endpoint.

Put non-secret identifiers in `lib/core/config/device_connection_config.dart`. Never place setup credentials, private keys, passwords, or cloud tokens in source code.

## Run

```powershell
flutter pub get
flutter run
```
