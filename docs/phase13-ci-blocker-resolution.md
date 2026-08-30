# EH Home — Phase 13 Definitive EMQX CI Lifecycle & Certificate Resolution Report

**Baseline Commit**: `7670866`
**Feature Branch**: `feature/phase13-production-deployment`
**Date**: 2026-08-30

---

## 1. Definitive Root Cause & Resolution

### Root Cause
1. **Container Bind-Mount Invalidation**:
   - In previous CI runs, `setup-emqx-mtls.js` was invoked after container startup.
   - Calling `generateCerts()` deleted (`fs.rmSync`) and recreated `.local-certs/` on the host while the running container was holding an active bind mount.
   - This orphaned the container's mount at `/opt/emqx/etc/local-certs`, leading to `chmod ...: No such file or directory` and TLS handshake connection dropouts.
2. **Redundant Container Copies**:
   - Attempting `docker cp` into an already-mounted directory was unnecessary and unsafe.

### Clean Lifecycle Architecture
1. **Host Generation Once (`--generate-only`)**:
   - `node scripts/setup-emqx-mtls.js --generate-only` creates ephemeral certificates (`ca.crt`, `server.crt`, `server.key`, `device_a.crt`, `device_a.key`, `device_b.crt`, `device_b.key`) and `acl.conf`.
   - Checks that all 8 required files exist before launching the container.
2. **Read-Only Container Mount (`:ro`)**:
   - EMQX 5.8 is launched with `-v ${{ github.workspace }}/.local-certs:/opt/emqx/etc/local-certs:ro`.
   - Environment variables map TLS options directly:
     - `EMQX_LISTENERS__SSL__DEFAULT__SSL_OPTIONS__CACERTFILE=/opt/emqx/etc/local-certs/ca.crt`
     - `EMQX_LISTENERS__SSL__DEFAULT__SSL_OPTIONS__CERTFILE=/opt/emqx/etc/local-certs/server.crt`
     - `EMQX_LISTENERS__SSL__DEFAULT__SSL_OPTIONS__KEYFILE=/opt/emqx/etc/local-certs/server.key`
     - `EMQX_LISTENERS__SSL__DEFAULT__SSL_OPTIONS__VERIFY=verify_peer`
     - `EMQX_LISTENERS__SSL__DEFAULT__SSL_OPTIONS__FAIL_IF_NO_PEER_CERT=true`
     - `EMQX_AUTHORIZATION__NO_MATCH=deny`
     - `EMQX_AUTHORIZATION__CACHE__ENABLE=false`
3. **Runtime Configuration Mode (`--configure-only`)**:
   - `setup-emqx-mtls.js --configure-only` validates container file readability and configures runtime settings without regenerating host files.

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
