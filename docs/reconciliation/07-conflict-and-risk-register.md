# Stage F — Conflict & Risk Register

**Generated Date:** October 31, 2026  
**Auditor:** Antigravity AI Engine  
**Project:** EH Home Platform  
**Target:** Safe Project Recovery Without Data Loss or Regressions

---

## 1. Conflict & Risk Matrix

| Risk ID | Domain | Risk Description | Severity | Likelihood | Mitigation Strategy |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **RSK-01** | Git Workflow | Overwriting local working files with `origin/main` via blind pull/merge. | **CRITICAL** | None (Prevented) | Full backup taken at `SMART_HOME_V1_BACKUP_20261031_PRE_RECONCILIATION`. Perform branch rebase/cherry-pick on isolated recovery copy. |
| **RSK-02** | Database | Migration number collision between `backend/migrations/030_...` and `packages/db-schema/migrations/030_...`. | **HIGH** | High | Renumber `backend/migrations/030_device_authorization_channel_configs.sql` $\to$ `036` and `031_automation_edge_execution_ownership.sql` $\to$ `037`. |
| **RSK-03** | Android Security | Global `android:usesCleartextTraffic="true"` flagged by Google Play and blocked on modern Android 13/14 for LAN HTTP. | **HIGH** | High | Add `network_security_config.xml` scoping cleartext HTTP strictly to RFC 1918 subnets (`192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`, `localhost`). |
| **RSK-04** | Cloud Transition | `app_config.dart` hardcoded fallback `http://192.168.0.227:3000` causes mobile app to appear disconnected for external reviewers. | **HIGH** | High | Set compiled default backend URL to production cloud instance (`https://eh-home-backend.onrender.com`), while retaining local developer override in Settings. |
| **RSK-05** | Test Reliability | 5 legacy backend tests fail due to duplicate `product_variants` insert of `eh-smart-switch-3x`. | **MEDIUM** | Guaranteed | Modify `backend/src/shared/in-memory-db-adapter.js` to perform idempotent upserts during test fixture seeding. |
| **RSK-06** | Test Reliability | 10 Flutter test assertion mismatches due to UI/auth security refinements. | **MEDIUM** | Guaranteed | Update finders to match `EHActionButton`, step 2 registration pump, and `"Owner only"` chips. |
| **RSK-07** | Clock Skew | ESP32 clock resets to epoch 0 (1970) if power cuts occur during an internet outage. | **MEDIUM** | Med | Integrate automatic phone-to-ESP32 local time sync (`POST /api/v1/time`) upon LAN discovery. |
| **RSK-08** | Wi-Fi Recovery | User changes router SSID/password; device enters backoff and cannot be reached. | **MEDIUM** | Med | Firmware automatically re-opens BLE advertising (`EH-Switch-XXXX`) after 10 failed connection attempts. |
| **RSK-09** | Background Alerts | No native push alerts when app is swiped away or closed. | **MEDIUM** | Med | Integrate `firebase_core` and `firebase_messaging` with FCM v1 backend dispatcher. |
| **RSK-10** | Desktop Polish | Missing `firmware-build-manifest.json` causes desktop silicon repo test to fail. | **LOW** | Low | Generate manifest via `scripts/build_firmware.ps1`. |

---

## 2. Secrets & Credential Exposure Audit

A security scan was conducted across all modified and untracked files to detect accidental commits of sensitive material:
- **Private Keys**: 0 private keys found. Test certificates use dummy keys or ephemeral generation.
- **Passwords & Tokens**: 0 hardcoded production database passwords or JWT secrets detected.
- **Environment Templates**: Configurations use parameterized `.env.example` templates.
- **Status**: **100% Secure**. No secrets will be leaked into commit history or PR descriptions.

