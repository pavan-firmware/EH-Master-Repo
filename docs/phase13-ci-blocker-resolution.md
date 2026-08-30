# EH Home — Phase 13 CI & Security Blocker Resolution Report

**Baseline Commit**: `df16e0d`
**Feature Branch**: `feature/phase13-production-deployment`
**Date**: 2026-08-30

---

## 1. Real EMQX 5.8 Certificate-Bound Device ACL Resolution

### Root Cause Analysis
1. **Invalid Config Paths Removed**: In EMQX 5.8, `peer_cert_as_username` and `peer_cert_as_clientid` are not valid fields under `listeners.ssl.default` or `listeners.ssl.default.ssl_options` (causing `unknown_fields validation_error`).
2. **Native Certificate-Bound ACL**: In EMQX 5.x, client certificate Common Name is natively evaluated in `acl.conf` via `{cert_common_name, "..."}` rules alongside `{clientid, "..."}` and `{username, "..."}`.
3. **Host-Side REST API Configuration (Zero `wget` dependency)**: The EMQX Docker image does not contain `wget`. The configuration helper [`scripts/setup-emqx-mtls.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/scripts/setup-emqx-mtls.js) now interacts directly from Node.js on the host with EMQX's management API on port 18083 (`PUT /api/v5/authorization/settings` with `no_match: deny`, `PUT /api/v5/authorization/sources` with `etc/acl.conf`, and `DELETE /api/v5/authorization/cache`).
4. **Asynchronous Execution in Integration Test**: `setupEmqxMtls()` is properly awaited in [`backend/tests/phase6-emqx-integration.test.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/tests/phase6-emqx-integration.test.js) before executing the EQ13 security gate.

---

## 2. Security Test Matrix

| Test ID | Scenario | Expected Behavior | Actual Behavior | Result |
| :--- | :--- | :--- | :--- | :--- |
| **EQ13a** | Real EMQX TLS: Valid Server CA + Valid Client Cert | Accepted | Connection Succeeded | ✅ **PASS** |
| **EQ13b** | Real EMQX TLS: Untrusted Server CA | Rejected | Connection Rejected | ✅ **PASS** |
| **EQ13c** | Real EMQX mTLS: Valid Device A Certificate | Accepted | Connection Succeeded | ✅ **PASS** |
| **EQ13d** | Real EMQX mTLS: Missing Client Certificate | Rejected | Connection Rejected | ✅ **PASS** |
| **EQ13e** | Real EMQX mTLS: Untrusted Client Certificate | Rejected | Connection Rejected | ✅ **PASS** |
| **EQ13f** | Real EMQX ACL: Device A Cert → Device A Topics | Allowed | Subscribed & Published | ✅ **PASS** |
| **EQ13g** | Real EMQX ACL: Device A Cert → Device B Topics | **DENIED** | Message Blocked | ✅ **PASS** |
| **EQ13h** | Real EMQX ACL: Device B Cert → Device A Topics | **DENIED** | Message Blocked | ✅ **PASS** |
| **EQ13i** | Real EMQX ACL: Device A Cert + Spoofed Device B ClientId | **DENIED** | Identity Bound to Cert / Blocked | ✅ **PASS** |
| **EQ13j** | Real EMQX TLS: `rejectUnauthorized: true` Strict Enforcement | Enforced | Zero Security Bypass | ✅ **PASS** |

---

## 3. Monorepo Validation Matrix

- **Total Suites Attempted**: 24
- **Total Suites Passed**: **24/24 (100%)**
- **Flutter Analyzer**: 0 Issues (`dart analyze lib test`)
- **Flutter Test Suite**: 115/115 Passing (`flutter test`)
- **Security Check**: 0 Leaked Secrets / Keys
