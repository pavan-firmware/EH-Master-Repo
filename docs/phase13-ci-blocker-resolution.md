# EH Home — Phase 13 EMQX Eval & CI Resolution Report

**Baseline Commit**: `5710c3a`
**Feature Branch**: `feature/phase13-production-deployment`
**Date**: 2026-08-30

---

## 1. Root Cause Analysis & Resolution

### Root Cause
1. **Undefined Erlang Function Call (`emqx_authz:reload`)**:
   - `emqx_authz:reload().` failed with `{error, undef}` because EMQX 5.8 does not export a zero-arity `reload/0` in the `emqx_authz` module.
   - ACL rules in `/opt/emqx/etc/local-certs/acl.conf` are loaded at container startup via boot environment variables and volume mounts.
2. **Clean Runtime Execution**:
   - Removed the undefined `emqx_authz:reload().` call.
   - Retained verified settings updates (`verify_peer`, `fail_if_no_peer_cert = true`, `no_match = deny`, `cache = false`, `ssl:clear_pem_cache().`, and listener restart).

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
