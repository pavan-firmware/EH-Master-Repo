# EH Home — Phase 14 Product Release Matrix

## Release Candidate Overview
EH Home Phase 14 unifies all backend services, embedded firmware protocols, and Flutter client layers into a production-grade consumer smart home system.

---

## Product Capability Matrix

| Feature | Implementation | Automated Validation | Physical Validation | Status | Known Limitation |
|---|---|---|---|---|---|
| **Account & Authentication** | PBKDF2-SHA512 password hashing, RS256 JWT access tokens, rotating refresh tokens with replay detection. | `backend/tests/phase7a-auth.test.js` (25/25 PASS) | Physical login/token lifecycle verified | **VALIDATED** | Single home switch per active session context |
| **Home & Multi-Tenant Isolation** | Canonical Home & Member RBAC (OWNER, ADMIN, MEMBER), cross-home access rejection (403 Forbidden). | `backend/tests/integration.test.js`, `phase7a-auth.test.js` | Verified | **VALIDATED** | Multi-home selector operates per authenticated account |
| **Room Management & Persistence** | Dedicated Add Room dialog with name & icon selection, zero-state creation without forced device onboarding redirection, local & cloud room persistence. | `smart_home_application_v1/test/phase14_consumer_product_test.dart` (Test 1 PASS), `rooms_page_test.dart` | Verified on Flutter UI | **VALIDATED** | Room renaming synced locally and on next backend fetch |
| **Device Onboarding & QR Verification** | Versioned QR parsing (`EH1:UUID:MAC:SECRET:VARIANT`), BLE GATT discovery, 4-step AES-GCM transcript proof handshake (`EH-PROV/1`), Wi-Fi credential provisioning without credential logging. | `backend/tests/phase5-onboarding.test.js`, `phase5_onboarding_test.dart` | ESP32-C6 / ESP32-WROOM BLE GATT Verified | **PHYSICAL PASS** | Camera permission required for optical QR scanning; manual fallback supported |
| **Multi-Device Lifecycle & Room Assignment** | Multiple devices commissioned to distinct rooms; device moving updates room device counts and persistence cleanly. | `smart_home_application_v1/test/phase14_consumer_product_test.dart` (Test 2 PASS), `phase9_lifecycle_convergence_test.dart` | Multi-node test harness PASS | **VALIDATED** | Max recommended BLE concurrent pairing: 1 device at a time |
| **Device Control & Capability UI** | Dynamic switch/relay actuations based on catalog metadata; confidence indicators (confirmed, pending, failed, unavailable). | `phase9_lifecycle_convergence_test.dart`, `capability_engine_test.dart` | Relay physical actuation <50ms verified | **PHYSICAL PASS** | Optimistic UI displays pending state until SSE receipt |
| **Quick Controls Customization** | Consumer quick controls customizer (up to 4 confirmed channels across devices), persistent storage, and live actuation. | `phase14_consumer_product_test.dart` (Test 3 PASS) | Verified on Flutter UI | **VALIDATED** | Limited to max 4 pinned controls on home overview |
| **Dynamic Daypart Greeting** | Local time-aware greeting daypart progression (Morning: 05:00-11:59, Afternoon: 12:00-16:59, Evening: 17:00-20:59, Night: 21:00-04:59). | `time_greeting_test.dart` (10/10 PASS), `phase14_consumer_product_test.dart` (Test 4 PASS) | Dynamic clock verified | **VALIDATED** | Tied to device system local clock |
| **Activity History** | Categorized event timeline (commands, physical switches, automations, safety, device connectivity) with search and filters. | `activity_page_test.dart` (18/18 PASS), `phase11-device-management.test.js` | Verified | **VALIDATED** | Infinite scrolling with cursor-based pagination |
| **Notification Management** | Consumer notification preferences (critical safety, offline alerts, automation failures, firmware updates) with local persistence. | `phase14_consumer_product_test.dart` (Test 5 PASS) | Verified on UI | **VALIDATED** | Critical safety alerts default to enabled for safety compliance |
| **Settings & Profile** | Comprehensive settings scaffold (Home profile, people access, notification preferences, appearance dark/light/system, system updates, diagnostics, help). | `settings_page_test.dart` (12/12 PASS), `theme_test.dart` | Verified at 360dp | **VALIDATED** | Secrets/tokens never exposed in UI |
| **App Data Clear & Separation** | Clear local app data leaves physical hardware, NVS factory identity (`fact_v2`), and cloud device record intact. | `phase14_consumer_product_test.dart` (Test 6 PASS), `dashboard_reliability_models_test.dart` | Hardware persistence verified | **PHYSICAL PASS** | Reconnection requires re-entering account credentials |
| **Firmware Protocol & Host Engine** | Proprietary C protocol framing engine with AES-256-GCM, HKDF-SHA256, NVS factory identity, and BL0942 telemetry parsing. | `backend/tests/phase8-ota.test.js`, 18 firmware host unit tests | Real ESP32 UART & Flash Verified | **PHYSICAL PASS** | Factory identity is immutable after manufacturing flash |
| **MQTT Transport & ACL Enforcement** | Strict mTLS on port 8883, certificate Common Name bound to deviceId (`peer_cert_as_clientid = cn`), file-based per-device ACL isolation. | `backend/tests/phase6-mqtt.test.js` (40/40 PASS), `phase6-protocol-harness.test.js` (5/5 PASS), `phase13-production-deployment.test.js` (6/6 PASS) | Verified in EMQX 5.8 | **VALIDATED** | Devices cannot publish/subscribe to cross-device topics |
| **Production Configuration** | Fast-fail production config validator rejecting loopback/LAN IP in production; health liveness/readiness probes; automated backup/restore tools. | `backend/tests/phase13-production-deployment.test.js`, `scripts/validate-environment.js` | Verified | **VALIDATED** | Requires production domain and TLS certificates in production deployment |

---

## Overall Assessment
- **Automated Validation**: 24 core backend & Flutter test suites passing.
- **Physical Hardware Lifecycle**: Validated on physical ESP32 and ESP32-C6 targets.
- **Release Status**: **RELEASE CANDIDATE READY (RC-1)**
