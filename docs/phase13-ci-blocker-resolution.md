# EH Home — Phase 13 CI & Security Blocker Resolution Report

**Baseline Commit**: `5495519`
**Feature Branch**: `feature/phase13-production-deployment`
**Date**: 2026-08-30

---

## 1. Real EMQX 5.8 Certificate-Bound Device ACL Resolution

### Root Cause
1. **EMQX Configuration Loading**: In EMQX 5.8, updating `acl.conf` on disk does not reload in-memory rules unless `emqx:update_config([authorization, sources], ...)` is invoked.
2. **Setup Call in Test**: `setup-emqx-mtls.js` was imported into `phase6-emqx-integration.test.js`, but was not explicitly invoked immediately prior to running the EQ13 mTLS/ACL gate.
3. **Cache Cleanup Command**: `emqx ctl authz cache-clean all` was throwing `error,undef` in EMQX 5.8; in EMQX 5.8 authorization caching is disabled via `emqx:update_config([authorization, cache, enable], false).`

### Fix Applied
1. Updated [`scripts/setup-emqx-mtls.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/scripts/setup-emqx-mtls.js) to:
   - Use `emqx:update_config` for all listener and authorization parameters:
     - `peer_cert_as_clientid = cn`
     - `peer_cert_as_username = cn`
     - `authorization.no_match = deny`
     - `authorization.cache.enable = false`
     - `authorization.sources = [{type = file, path = "etc/acl.conf", enable = true}]`
   - Include both `{clientid, "..."}` and `{username, "..."}` rules in `acl.conf` for Device A and Device B identities.
   - Restart the `ssl:default` listener cleanly.
2. Updated [`backend/tests/phase6-emqx-integration.test.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/tests/phase6-emqx-integration.test.js) to ensure `setupEmqxMtls()` executes before running the EQ13 test suite.
3. Verified:
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
