# ADR-003: Phase 7A Production Backend Authentication & Authorization Architecture

- **Status:** `ACCEPTED`
- **Date:** 2026-08-26
- **Author:** EH Home Security & Backend Platform Team
- **Relevant Components:** `backend/src/services/auth.service.js`, `backend/src/shared/auth-middleware.js`, `backend/src/shared/home-authorization.js`, `backend/src/api/auth.router.js`, `packages/contracts`

---

## 1. Context & Problem Statement

Prior to Phase 7A, backend endpoints relied on development stubs or `mockAuthMiddleware` reading an unverified `X-Actor-Context` header.
Production deployment requires:
1. **Strong User Authentication**: Cryptographically signed access tokens for HTTP API calls.
2. **Short-Lived Access Tokens**: Mitigate token theft risk via 15-minute access token expiration.
3. **Secure Refresh Token Rotation**: Long-lived sessions (30 days) with strict single-use refresh token rotation to detect token theft.
4. **Home Membership Authorization**: Fine-grained authorization scoping every home/device access to validated `HomeMembership` records.
5. **No Production Header Bypass**: Complete removal of `X-Actor-Context` authentication in production execution paths.

---

## 2. Decision

We adopt the **Phase 7A Authentication & Authorization Architecture**:

### A. Access Tokens (RS256 JWT)
- **Algorithm**: **RS256** (Asymmetric RSA-SHA256 signature).
- **Token Claims**:
  - `sub`: User UUID (`userId`)
  - `email`: User email address
  - `type`: `"access"`
  - `iss`: `"eh-home-auth"`
  - `aud`: `"eh-home-api"`
  - `iat`: Timestamp (seconds)
  - `exp`: Timestamp (seconds) — 15 minutes default TTL
- **Key Management**: Environment-configured RS256 key pair. In local/test environments, ephemeral RSA 2048-bit key pairs are generated automatically. Private keys are NEVER committed to version control.

### B. Refresh Tokens & Rotation Strategy
- **Token Generation**: High-entropy 256-bit cryptographically secure random token (hex-encoded string).
- **Persistence & Hashing**: Refresh tokens are stored in the database (`refresh_tokens` table) as SHA-256 hashes (`token_hash`), never in plaintext.
- **Rotation on Use**: When `POST /api/v1/auth/refresh` is called:
  1. The incoming refresh token is verified against the database.
  2. If valid, the old refresh token is **immediately deleted** (revoked).
  3. A new access token AND a new refresh token are generated and returned.
- **Single-Use Violation Detection (Replay Protection)**: If an already-used or revoked refresh token is presented, all refresh tokens for that user are invalidated immediately as a security precaution against token theft.

### C. Password Hashing
- Passwords are hashed using salted cryptographic hash (PBKDF2/scrypt with 32-byte salt, or bcrypt-compatible algorithm).
- Plaintext passwords are never logged, stored, or returned.

### D. Rate Limiting & Protection
- Abuse protection on sensitive auth endpoints (`/register`, `/login`, `/refresh`) using a bounded sliding-window rate limiter.

### E. Home Membership Isolation
- Middleware `requireHomeMembership()` verifies that the authenticated user (`req.user.id`) holds an active membership (`OWNER`, `ADMIN`, `MEMBER`, `GUEST`) in the requested home before allowing access to homes, floors, rooms, members, devices, or device commands.

---

## 3. Rationale

- **RS256 Asymmetric Signing**: Allows internal microservices or edge gateways to verify JWT access tokens using only the public key without needing access to the signing secret.
- **Refresh Token Rotation & Replay Protection**: Single-use rotation prevents stolen refresh tokens from remaining valid indefinitely.
- **Complete Elimination of Development Headers**: Removing `X-Actor-Context` guarantees zero auth bypass vulnerability in production.

---

## 4. Status & Compatibility

- **Status**: `ACCEPTED` — Implemented in Phase 7A branch `feature/phase-7a-backend-auth-foundation`.
