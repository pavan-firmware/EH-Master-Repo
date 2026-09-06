# Phase 42 — Production Security Hardening & Compliance

## 1. Overview & Objective

Phase 42 implements a comprehensive, production-grade security hardening pass across the entire EH Home smart home platform. This hardening phase directly reinforces and reuses established platform architecture from earlier phases without introducing competing frameworks:
- **Phase 32**: Device Identity & Trust Lifecycle
- **Phase 31**: Security Operations, Audit & Observability
- **Phase 36**: Authentication, Token Lifecycle & RBAC
- **Phase 34**: Runtime Configuration & Operational Readiness
- **Phase 37**: PostgreSQL Relational Persistence & Parameterized Queries
- **Phase 38**: Push Notifications & Remote Encrypted Backups
- **Phase 40**: Manufacturing Security & Hardware Provisioning
- **Phase 41**: Fleet Management & Safe OTA Rollouts

---

## 2. Threat Model

The platform security posture is designed against 14 primary attack vectors:

| # | Threat Vector | Description | Implemented Countermeasures & Controls |
|---|---|---|---|
| **1** | **Unauthenticated API Access** | Malicious callers invoking REST endpoints without credentials | JWT verification middleware (`RS256`), rejecting unauthenticated requests with `401 Unauthorized`. |
| **2** | **Privilege Escalation** | Regular users attempting to invoke administrative or operator-level capabilities | `RBACService` with strict permission and capability matrices, rejecting non-admin calls with `403 Forbidden`. |
| **3** | **Cross-Home / IDOR / BOLA** | Authenticated users accessing devices/automations in other homes by changing IDs | `HomeAuthorizationService` validating home membership and ownership on every entity access. |
| **4** | **Stolen / Expired / Revoked Tokens** | Replay of old JWTs or revoked refresh tokens | Token expiration checks (`exp`), single-use refresh token rotation with SHA-256 hash tracking and immediate revocation. |
| **5** | **Session / Token Replay & Confusion** | Algorithm confusion (`none`/`HS256`) or forged token claims | Explicit RS256 signature verification with public key, algorithm pinning (`alg: RS256`), and strict issuer/audience validation. |
| **6** | **Malicious Firmware Artifacts** | Deployment of compromised or tampered binary images | HTTPS transport enforcement, SHA-256 digest validation, Ed25519 signature verification, size bounds (1792KB), and anti-rollback. |
| **7** | **Compromised Device Identity** | Cloned MACs or revoked devices attempting to connect | `DeviceTrustService` enforcing immutable `fact_v2` hardware identity, hardware certificates, and blocking `REVOKED`/`DECOMMISSIONED` states. |
| **8** | **Secret Leakage** | Credentials accidentally committed, logged, or exposed in API errors | Recursive audit redaction (`AuditRedactionService`), zero plaintext secrets in backups, environment-variable secret injection. |
| **9** | **SQL Injection / Unsafe Queries** | Injection via crafted user inputs or entity IDs | 100% parameterized SQL queries via `pg` pool, strict identifier whitelist validation, and transactional boundaries. |
| **10** | **Backup Data Exposure** | Plaintext credential extraction from local or remote backups | Automatic redaction of private keys/tokens during backup generation; AES-256-GCM encryption on cloud backup exports. |
| **11** | **Malicious Manufacturing Input** | Ambiguous flashing targets or invalid NVS payloads | Factory provisioner validating silicon architecture, partition table layout, explicit serial ports, and immutable `fact_v2` preservation. |
| **12** | **CI/CD & Supply-Chain Compromise** | Dependency tampering or malicious workflow executions | Pinned dependencies via `package-lock.json` and `pubspec.lock`, SBOM inventory, minimal workflow token permissions. |
| **13** | **Rate-Abuse / Brute-Force** | Rapid brute-forcing of passwords, admin endpoints, or device commands | Configurable sliding-window rate limiters with distinct buckets (`auth`, `admin`, `commands`, `ota`, `password`). |
| **14** | **Information Leakage via Errors** | Production stack traces, database schemas, or paths leaking to clients | Production error sanitization stripping stacks, database error messages, query strings, and system paths. |

---

## 3. Trust Boundaries & Architecture

```
                       [ Untrusted Network / Clients ]
                                     |
                                HTTPS (TLS 1.3)
                                     v
                 +---------------------------------------+
                 |       Production Security Headers     |
                 | (HSTS, CSP, X-Frame, X-Content-Type)  |
                 +---------------------------------------+
                                     |
                                     v
                 +---------------------------------------+
                 |    Sliding-Window Rate Limiter        |
                 | (auth, admin, commands, ota, password)|
                 +---------------------------------------+
                                     |
                                     v
                 +---------------------------------------+
                 |       Authentication Gate (RS256)     |
                 |   (Token Validation, Blacklist Check) |
                 +---------------------------------------+
                                     |
                                     v
                 +---------------------------------------+
                 |  Home Authorization & RBAC Gate       |
                 | (IDOR Prevention, Role Capabilities)  |
                 +---------------------------------------+
                                     |
           +-------------------------+-------------------------+
           |                                                   |
           v                                                   v
+-------------------------+                         +-------------------------+
| Device Operations Layer |                         | Database & Storage      |
| - DeviceTrustService    |                         | - Parameterized SQL     |
| - MQTT mTLS Broker      |                         | - Encrypted Backups     |
| - OTA Ed25519 Validator |                         | - Redacted Audit Trail  |
+-------------------------+                         +-------------------------+
```

---

## 4. Authentication & RBAC Model

- **Token Signing**: Asymmetric RS256 with key pairs loaded from secure runtime environment or secrets manager.
- **Refresh Token Lifecycle**: High-entropy cryptographically secure random tokens stored as SHA-256 hashes. Single-use rotation ensures that if a token is reused, all downstream tokens are revoked.
- **Timing Attacks**: Token comparisons utilize `crypto.timingSafeEqual` to eliminate side-channel timing leaks.
- **RBAC Matrix**:
  - `admin`: Full system access, fleet operations, release publishing, operational configuration.
  - `operator`: Fleet status inspection, batch rollout scheduling, diagnostic retrieval.
  - `home_owner`: Full control of owned home entities, automations, scenes, member management.
  - `home_member`: Normal device operation, state reading within authorized home.
  - `guest`: Temporary / restricted device operation.

---

## 5. Device Identity & Trust Security

- **Immutable Identity**: Factory-flashed `fact_v2` partition contains the immutable device UUID, hardware model, serial number, and factory certificate.
- **Factory Reset Safety**: Resetting NVS only clears operational Wi-Fi/user state; `fact_v2` remains intact and cannot be altered via user-space commands.
- **Trust Evaluation**: Devices marked as `REVOKED` or `DECOMMISSIONED` are permanently rejected from MQTT broker connection, command dispatch, and OTA deployment.
- **Stale Trust Expiration**: Device credentials past their validity window are rejected until re-authenticated.

---

## 6. Secret Handling & Redaction

- **Zero Secrets in Repository**: Passwords, private keys, database credentials, and signing secrets are strictly excluded from source files, git tracking, test fixtures, and example configs.
- **Audit Redaction**: `AuditRedactionService` recursively sanitizes logs and audit event payloads across a comprehensive pattern match (`password`, `token`, `secret`, `private_key`, `authorization`, `signature`, `credential`, `database_url`, `cookie`, `pin`, etc.).
- **Backup Sanitization**: Backups exclude all raw credential secrets. Restoring a backup preserves security boundaries and does not resurrect revoked credentials.

---

## 7. Firmware & OTA Security

- **Transport**: HTTPS-only artifact delivery from trusted release domains.
- **Integrity**: SHA-256 64-hex digest validation before binary deployment.
- **Authenticity**: Ed25519 128-hex cryptographic signature verification against the manufacturer public key.
- **Anti-Rollback**: Version monotonicity checks prevent unauthorized downgrade attacks. Rollback is only permitted to explicitly signed, active, trusted previous release versions.
- **Partition Bounds**: Firmware images exceeding the flash partition allocation (1792 KB) are deterministically rejected before transmission.

---

## 8. API & Database Security

- **Security Headers**: Production HTTP responses include:
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains`
  - `Content-Security-Policy: frame-ancestors 'none'`
  - `Cache-Control: no-store, no-cache, must-revalidate`
- **SQL Parameterization**: All PostgreSQL queries use parameterized `$1, $2, ...` placeholders. Column and table names are validated against strict alphanumeric whitelists.
- **Error Redaction**: In production mode (`NODE_ENV=production`), internal stack traces, SQL error codes, and filesystem paths are replaced with a generic safe message and request correlation ID.

---

## 9. Mobile (Flutter) Security

- **Secure Storage**: Tokens and credentials are stored exclusively in platform hardware keychains (`flutter_secure_storage` using iOS Keychain and Android KeyStore/EncryptedSharedPreferences).
- **Session Termination**: Logout executes full memory, cache, and secure storage zeroization.
- **UI Gating**: Client-side UI element visibility is treated purely as user experience, never as a security boundary. All operations are strictly authenticated and authorized by the backend.
- **Zero Client Secrets**: No backend administrative API keys, signing private keys, or root database credentials exist in the client binary or assets.

---

## 10. Operator Security Responsibilities

1. **Secret Rotation**: Regularly rotate RS256 JWT private keys and database master passwords using environment-injected secret managers (e.g. AWS Secrets Manager, HashiCorp Vault).
2. **Firmware Signing Key Management**: Store Ed25519 release signing private keys in an offline HSM or air-gapped CI signing worker.
3. **Database Network Isolation**: Ensure PostgreSQL is deployed inside a private VPC with ingress restricted exclusively to backend service instances.
4. **Rate Limiter Configuration**: For multi-instance clustered deployments, configure a centralized Redis-backed rate limiter if process-local in-memory limits are insufficient for distributed traffic.

---

## 11. Known Limitations

- **Process-Local Rate Limiting**: The built-in rate limiter operates in-memory per Node.js process. In multi-pod container clusters, per-IP limits scale linearly with replica count unless backed by a distributed store.
- **Physical UART Access**: If an attacker gains physical access to the device with hardware debuggers, flash contents can be protected only if ESP32 Flash Encryption and Secure Boot are physically burned into eFuses.

---

## 12. Security Claim Boundary & Explicit Non-Claims

> [!WARNING]
> **Explicit Non-Claims Policy**
> The controls, audits, tests, and documentation implemented in Phase 42 represent production-grade engineering hardening and secure development best practices.
> 
> The repository **DOES NOT CLAIM**:
> - Formal SOC 2 Type I or Type II certification
> - ISO/IEC 27001 formal accreditation
> - Formal IEC 62443 industrial certification
> - Matter / CSA formal security certification
> - Third-party penetration testing certification
> - Zero vulnerabilities or mathematically proven security
> - Immunity to physical tampering or hardware fault injection without eFuse burning
