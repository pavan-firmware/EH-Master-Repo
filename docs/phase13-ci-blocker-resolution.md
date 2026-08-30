# EH Home — Phase 13 Deterministic EMQX Test Provisioning & Security Resolution Report

**Baseline Commit**: `b441006`
**Feature Branch**: `feature/phase13-production-deployment`
**Date**: 2026-08-30

---

## 1. Root Cause & Mount Strategy Diagnosis

### Why `unlinkat /opt/emqx/etc/certs/cacert.pem: device or resource busy` Occurred
1. **Direct File Bind Mount Conflict**:
   - Binding single files directly (`-v ca.crt:/opt/emqx/etc/certs/cacert.pem`) creates a kernel-level mountpoint on the specific file inode.
   - When a script subsequently executes `docker cp` or file replacement against that exact path, Linux/Docker fails with `EBUSY` (`unlinkat ...: device or resource busy`).
2. **Directory Mount & Clean Paths**:
   - Switched in CI to mounting the entire `.local-certs` directory to `/opt/emqx/etc/local-certs`.
   - Pointed EMQX listener configuration paths to `/opt/emqx/etc/local-certs/{ca.crt, server.crt, server.key}` at container boot.
   - In [`scripts/setup-emqx-mtls.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/scripts/setup-emqx-mtls.js), commands use dedicated paths (`/opt/emqx/etc/local-certs/`) and fail fast if any step returns an error.

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
