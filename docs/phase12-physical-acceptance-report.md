# EH Home — Phase 12 Physical Acceptance Report

**Date**: 2026-08-30
**Baseline**: `origin/main` (`342425b`)
**Head Commit**: `bcc690a`
**Target Hardware SKU**: `EH-SW3X` (`EH-SW3X-2026W12-00001`, Device ID: `4444688e-989d-458e-820e-ac62a99ed8e1`)
**Physical Acceptance Gate Status**: **BLOCKED BY PHYSICAL HARDWARE BENCH EXECUTION**

---

## 1. Physical Hardware Acceptance Matrix

| Test ID | Gate / Subsystem | Device Target | Expected Behavior | Observed Behavior | Log / Evidence | Result |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **PHY-01** | BLE GATT Discovery | Smart Switch 3X | Advertises EH-PROV/1 UUID (`6100`), reads `6105` paging identity | No serial/USB hardware attached during test run | `tools/hardware-test-harness/test_esp32_lifecycle.py` | **NOT TESTED (PENDING ATTACHMENT)** |
| **PHY-02** | Secure Handshake & QR | Smart Switch 3X | 4-step AES-GCM EH-PROV/1 transcript verified without secret leak | No serial/USB hardware attached during test run | Host simulation passed; physical hardware bench pending | **NOT TESTED (PENDING ATTACHMENT)** |
| **PHY-03** | Wi-Fi Provisioning & IP | Smart Switch 3X | ESP32 receives encrypted credentials, associates with AP, gets DHCP IP | No serial/USB hardware attached during test run | Host simulation passed; physical hardware bench pending | **NOT TESTED (PENDING ATTACHMENT)** |
| **PHY-04** | Cloud MQTT mTLS | Smart Switch 3X | Establishes mTLS on port 8883 to EMQX broker with CN=deviceId | Real EMQX 5.8 mTLS verified with client cert; physical ESP32 pending | `backend/tests/test_real_emqx.js` (22/22 pass) | **NOT TESTED (PENDING ATTACHMENT)** |
| **PHY-05** | Claim & Room Assign | Smart Switch 3X | Device claims into Home and assigns to Room without hardcoded IDs | Backend lifecycle and DB persistence verified; physical device pending | `backend/tests/phase11-device-management.test.js` | **NOT TESTED (PENDING ATTACHMENT)** |
| **PHY-06** | Real Relay Actuation | Smart Switch 3X | Actuates Relay 1, 2, 3 on command with sub-50ms latency | No physical relay board attached to serial | Host debounce/relay passed; physical load pending | **NOT TESTED (PENDING ATTACHMENT)** |
| **PHY-07** | Physical Switch Override| Smart Switch 3X | Wall switch toggle overrides cloud state with hardware ISR | Host debounce/relay passed; physical switch pending | `firmware/tests/test_firmware_modules.js` | **NOT TESTED (PENDING ATTACHMENT)** |
| **PHY-08** | Realtime State Sync | Flutter / Backend | DeviceState converges authoritatively via SSE to Flutter UI | Full SSE bus & client models verified; physical sync pending | `smart_home_application_v1/test/` (115/115 pass) | **NOT TESTED (PENDING ATTACHMENT)** |
| **PHY-09** | BL0942 Energy Metering | Smart Switch 3X | UART1 @ 4800 baud reports raw V/I/P/E converted to fixed-point | Host BL0942 frame parser passed; physical UART pending | `firmware/tests/test_firmware_modules.js` | **NOT TESTED (PENDING ATTACHMENT)** |
| **PHY-10** | Power Cycle Restoration| Smart Switch 3X | State & credentials persist across hard power drop without reset | Host NVS fact_v2 tests passed; physical power drop pending | `tools/manufacturing/test_manufacturing.py` | **NOT TESTED (PENDING ATTACHMENT)** |
| **PHY-11** | Factory Reset Boundary | Smart Switch 3X | Reset clears runtime Wi-Fi & re-enables BLE while preserving fact_v2 | NVS immutable identity separation verified; physical button pending| `backend/tests/phase11-device-management.test.js` | **NOT TESTED (PENDING ATTACHMENT)** |
| **PHY-12** | Automation & Schedules | Smart Switch 3X | Cloud schedule triggers physical relay actuation via outbox | Host automation engine verified; physical actuation pending | `backend/tests/phase10-automation.test.js` | **NOT TESTED (PENDING ATTACHMENT)** |
| **PHY-13** | Signed OTA Partition | Smart Switch 3X | Downloads signed firmware binary to `ota_1`, swaps, and boots | Host OTA compatibility & anti-rollback verified; physical flash pending| `backend/tests/phase8-ota.test.js` | **NOT TESTED (PENDING ATTACHMENT)** |

---

## 2. Evidence & Automated Host Tests

All 23 host and integration test suites pass with 100% success (`node scripts/validate-repo.js`). In accordance with truthfulness invariants, host test results are not substituted for physical hardware validation.
