# EH Home — Phase 13 EMQX Permission & CI Lifecycle Resolution Report

**Baseline Commit**: `90164b0`
**Feature Branch**: `feature/phase13-production-deployment`
**Date**: 2026-08-30

---

## 1. Root Cause & Permission Fix

### Why `docker exec eh_emqx test -r /opt/emqx/etc/local-certs/server.key` Failed
1. **Linux Runner File Mode & Non-Root Container User**:
   - On Linux host runners (GitHub Actions UID 1001 `runner`), OpenSSL generates private keys with restrictive permissions (`0600`).
   - When mounted into the EMQX container running as user `emqx` (UID 1000), `test -r server.key` returned status 1 because group/others had 0 read permissions.
2. **Explicit World-Readable Permissions**:
   - Updated [`scripts/generate-dev-certs.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/scripts/generate-dev-certs.js) and [`scripts/setup-emqx-mtls.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/scripts/setup-emqx-mtls.js) to set `0644` permissions on all generated `.local-certs/` files and `0755` on the directory.
   - Updated [`.github/workflows/ci.yml`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/.github/workflows/ci.yml) to execute `chmod -R 755 .local-certs` and `chmod 644 .local-certs/*` immediately after generation and before broker startup.

---

## 2. Security Authorization Matrix

| Certificate Identity | Client ID | Target Topic | Operation | Expected | Actual Result |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Device A** (`0194fe23-7a1b-7890-a123-456789abcdef`) | Device A | `eh/v1/devices/A/commands` | `subscribe` | **ALLOW** | ✅ **ALLOW (PASS)** |
| **Device A** (`0194fe23-7a1b-7890-a123-456789abcdef`) | Device A | `eh/v1/devices/A/state` | `publish` | **ALLOW** | ✅ **ALLOW (PASS)** |
| **Device A** (`0194fe23-7a1b-7890-a123-456789abcdef`) | Device A | `eh/v1/devices/B/state` | `publish` | **DENY** | ✅ **DENY (PASS)** |
| **Device B** (`0194fe23-7a1b-7890-b456-123456fedcba`) | Device B | `eh/v1/devices/A/state` | `publish` | **DENY** | ✅ **DENY (PASS)** |
| **Device A** (`0194fe23-7a1b-7890-a123-456789abcdef`) | Device B (Spoof) | `eh/v1/devices/B/state` | `publish` | **DENY** | ✅ **DENY (PASS)** |
| **Device B** (`0194fe23-7a1b-7890-b456-123456fedcba`) | Device A (Spoof) | `eh/v1/devices/A/state` | `publish` | **DENY** | ✅ **DENY (PASS)** |

---

## 3. Monorepo Validation Results

- **Phase 13 Production Deployment Tests**: 6/6 Passed (`backend/tests/phase13-production-deployment.test.js`)
- **MQTT Authorizer Unit Tests**: 10/10 Passed (`backend/tests/mqtt-http-authorizer.test.js`)
- **Monorepo Suite Runner**: **24/24 Suites Passed (100% Green)** (`scripts/validate-repo.js`)
- **Flutter Analyzer & Tests**: 115/115 Passed, 0 issues
