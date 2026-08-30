# EH Home — Phase 13 CI & Security Blocker Resolution Report

**Baseline Commit**: `b2a5b6b`
**Feature Branch**: `feature/phase13-production-deployment`
**Date**: 2026-08-30

---

## 1. Real EMQX 5.8 Certificate-Bound Device ACL Resolution

### Root Cause
1. **Config Path in EMQX 5.8**: In EMQX 5.8, `peer_cert_as_username` and `peer_cert_as_clientid` are scoped under `listeners.ssl.default.ssl_options` (not `listeners.ssl.default`), causing EMQX to reject them with `unknown_fields validation_error`.
2. **Authorization Sources Loading**: EMQX 5.8 requires the file authorization source to be activated via the REST API (`PUT /api/v5/authorization/sources`) or HOCON update with `no_match: deny`.
3. **Cache Cleanup**: Authorization cache is disabled via `emqx:update_config([authorization, cache, enable], false).` and REST settings.

### Fix Applied
1. Updated [`scripts/setup-emqx-mtls.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/scripts/setup-emqx-mtls.js) to:
   - Configure `listeners.ssl.default.ssl_options.peer_cert_as_username = cn`
   - Configure `listeners.ssl.default.ssl_options.peer_cert_as_clientid = cn`
   - Configure `authorization.no_match = deny`
   - Configure `authorization.cache.enable = false`
   - Activate `file` source via REST API (`PUT /api/v5/authorization/sources`) with `etc/acl.conf`
   - Include both `{clientid, "..."}` and `{username, "..."}` rules in `acl.conf` for Device A and Device B identities.
2. Verified:
   - **EQ13f** (Device A cert → Device A topic): **ALLOW / PASS**
   - **EQ13g** (Device A cert → Device B topic): **DENY / PASS**
   - **EQ13h** (Device B cert → Device A topic): **DENY / PASS**
   - **EQ13i** (Device A cert + Device B clientId spoof → Device B topic): **DENY / PASS**

---

## 2. Flutter CI Toolchain Resolution

### Root Cause
Job 1 in `.github/workflows/ci.yml` executed the 24-suite runner (`validate-repo.js`), which runs Flutter analyze/tests, but Job 1 only had Node configured and lacked Flutter & Java SDKs.

### Fix Applied
Added `Setup Java (temurin 17)` and `Setup Flutter 3.44.9` (`subosito/flutter-action@v2`) with `pip install cryptography` to Job 1 in [`.github/workflows/ci.yml`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/.github/workflows/ci.yml).

---

## 3. Regression & Test Matrix

- **Total Suites Attempted**: 24
- **Total Suites Passed**: **24/24 (100%)**
- **Flutter Analyzer**: 0 Issues (`dart analyze lib test`)
- **Flutter Test Suite**: 115/115 Passing (`flutter test`)
- **Security Check**: 0 Leaked Secrets / Keys
