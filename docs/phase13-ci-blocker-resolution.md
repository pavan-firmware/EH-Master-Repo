# EH Home — Phase 13 CI Blocker Resolution Report

**Baseline Commit**: `5495519`
**Feature Branch**: `feature/phase13-production-deployment`
**Date**: 2026-08-30

---

## 1. EMQX ACL Isolation Resolution

### Root Cause
In EMQX 5.8.0, file-based ACLs in `/opt/emqx/etc/acl.conf` require explicit declaration in `authorization.sources` and an explicit reload trigger (`emqx_authz:reload_sources()`). Without explicitly setting `authorization.sources = [{type = file, path = "etc/acl.conf"}]` and clearing cache, EMQX 5.8 was not enforcing the newly mounted `acl.conf` rules.

### Fix Applied
1. Updated [`scripts/setup-emqx-mtls.js`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/scripts/setup-emqx-mtls.js) to:
   - Configure `authorization.sources` via `emqx_config:put([authorization, sources], [#{type => file, enable => true, path => <<"etc/acl.conf">>}]).`
   - Include both `{clientid, "..."}` and `{username, "..."}` rules in `acl.conf` for Device A and Device B identities.
   - Invoke `emqx_authz:reload_sources()` and `emqx ctl authz reload`.
2. Verified:
   - **EQ13f** (Device A cert → Device A topics): **PASS**
   - **EQ13g** (Device A cert → Device B topics): **DENIED / PASS**
   - **EQ13h** (Device B cert → Device A topics): **DENIED / PASS**
   - **EQ13i** (Device A cert with Spoofed ClientId): **DENIED / PASS**

---

## 2. Flutter CI Toolchain Resolution

### Root Cause
Job 1 in `.github/workflows/ci.yml` ran the full 24-suite runner (`node scripts/validate-repo.js`), which executes `flutter analyze` and `flutter test`, but Job 1 only had Node 20 configured and lacked Flutter SDK / Java toolchains in its environment.

### Fix Applied
Added `Setup Java (temurin 17)` and `Setup Flutter 3.44.9` (`subosito/flutter-action@v2`) with `pip install cryptography` to Job 1 in [`.github/workflows/ci.yml`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/.github/workflows/ci.yml).

---

## 3. Regression & Test Matrix

- **Total Suites Attempted**: 24
- **Total Suites Passed**: **24/24 (100%)**
- **Flutter Analyzer**: 0 Issues
- **Flutter Test Suite**: 115/115 Passing
- **Security Check**: 0 Leaked Secrets / Keys
