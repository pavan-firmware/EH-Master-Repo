# EH Home — Phase 13 EMQX 5.8 Deterministic Authorization Resolution Report

**Baseline Commit**: `439676c`
**Feature Branch**: `feature/phase13-production-deployment`
**Date**: 2026-08-30

---

## 1. Root Cause Analysis & Resolution

### Root Cause
1. **Runtime `emqx_authz function_clause`**:
   - Calling `emqx:update_config([authorization, sources], ...)` on a live EMQX 5.8 instance failed with `{error,{pre_config_update,emqx_authz,function_clause}}` because the `emqx_authz` configuration schema expects raw HOCON binary string keys and internal record structs, not dynamic Erlang maps.
2. **Container `wget` Dependency**:
   - The official EMQX 5.8 Alpine/Debian image does not ship with `wget`.
3. **Invalid Client Match Condition**:
   - The file authorizer (`authz:file`) in EMQX 5.8 does not support `{cert_common_name, ...}` as an inline client matcher.

### Architectural Resolution
1. **Deterministic Broker Boot Configuration**:
   - In CI ([`.github/workflows/ci.yml`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/.github/workflows/ci.yml)), EMQX 5.8 is launched with volume-mounted certificates (`ca.crt`, `server.crt`, `server.key`) and pre-configured ACL (`acl.conf`), along with environment variables:
     - `EMQX_LISTENERS__SSL__DEFAULT__SSL_OPTIONS__VERIFY=verify_peer`
     - `EMQX_LISTENERS__SSL__DEFAULT__SSL_OPTIONS__FAIL_IF_NO_PEER_CERT=true`
     - `EMQX_AUTHORIZATION__NO_MATCH=deny`
     - `EMQX_AUTHORIZATION__CACHE__ENABLE=false`
2. **Synchronous Helper & Runtime Reload**:
   - [`scripts/setup-emqx-mtls.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/scripts/setup-emqx-mtls.js) generates certificates, prepares `acl.conf`, synchronizes files if the container is running, and triggers `emqx_authz:reload()`.
3. **Dedicated Authorizer Service**:
   - [`backend/src/services/mqtt-http-authorizer.service.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/src/services/mqtt-http-authorizer.service.js) provides pure-function device certificate identity evaluation.

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
- **Monorepo Test Suite**: **24/24 Suites Passed (100% Green)** (`scripts/validate-repo.js`)
- **Flutter Analyzer & Tests**: 115/115 Passed, 0 issues
