# Phase 16 — Production Account, Home, Membership, Ownership & Access Control Platform

## 1. Overview & Architecture

Phase 16 establishes the production-grade identity, tenancy, membership, role-based capability access control (RBAC), and invitation platform across backend and mobile client surfaces.

```
+-----------------------------------------------------------------------------------+
|                            EH HOME ACCESS CONTROL MATRIX                          |
+-----------------------------------------------------------------------------------+
| Role     | Manage Home | Delete Home | Manage Members | Transfer Ownership | Control |
|----------+-------------+-------------+----------------+--------------------+---------|
| OWNER    |     YES     |     YES     |      YES       |        YES         |   YES   |
| ADMIN    |     YES     |     NO      |      YES       |        NO          |   YES   |
| MEMBER   |     NO      |     NO      |      NO        |        NO          |   YES   |
| VIEWER   |     NO      |     NO      |      NO        |        NO          |   NO    |
+-----------------------------------------------------------------------------------+
```

---

## 2. Key Modules & Implementations

### A. Database Migrations (Migration 009)
- **`user_profiles`**: Tracks user full name, phone number, avatar URL, timezone preference, and email verification status.
- **`home_invitations`**: Manages member invitations with secure 64-character entropy invite codes, role scoping, 7-day TTL expiration, and single-use acceptance state machine (`PENDING` -> `ACCEPTED` / `REJECTED` / `REVOKED` / `EXPIRED`).

### B. Canonical Contracts & Schemas
- **`packages/contracts/authorization/home-invitation.schema.json`**: JSON schema for invitation payloads and statuses.
- **`packages/contracts/authorization/index.ts`**: Canonical TypeScript interfaces for `HomeRole`, `InvitationStatus`, `HomeMembership`, `HomeInvitation`, `UserProfile`, `AccountSession`, and `HomePermissions`.

### C. Capability-Aware Guarding & Authorization
- **`backend/src/shared/home-authorization.js`**:
  - Implements the fine-grained `ROLE_PERMISSIONS` capability matrix.
  - Exposes `canControlDevices(role)`, `canExecuteAutomations(role)`, `canManageMembers(role)`, `canManageHome(role)`, `canDeleteHome(role)`, and `canTransferOwnership(role)`.
  - Integrated into API middleware and route handlers to block unauthorized operations with standard `403 Forbidden`.

### D. Multi-Home & Ownership Lifecycle
- **Ownership Transfer**: Owners can transfer primary ownership to another verified active member in the home. The previous owner is automatically demoted to `ADMIN`.
- **Sole-Owner Protection**: Sole owners cannot abandon a home without either transferring ownership or deleting the home.
- **Deletion Cascade**: Deleting a home cleanly unclaims and resets device authorizations, removes memberships, purges pending invitations, and records an authoritative audit event.

### E. Flutter Mobile Architecture
- **Models**: `UserAccountProfile`, `AccountSessionItem`, `HomeAccessPermissions`, `HomeSummaryItem`, `HomeMemberItem`, `HomeInviteItem` in `smart_home_application_v1/lib/core/models/access_control_models.dart`.
- **Repositories**: `AccountHomeRepository` and `CloudAccountHomeRepository`.
- **Presentation Pages**:
  - `AccountProfilePage`: User profile viewing/editing, session inspection, session revocation, password update dialog, and secure account deletion.
  - `HomeMembersPage`: Dual-tab member roster and pending invitation manager with role chips, invite modal, role adjustment, and member removal flows.

---

## 3. Verification & Compliance

- **Backend Integration Tests**: `backend/tests/phase16-access-control.test.js` (6/6 test groups passed).
- **Flutter Analysis**: `flutter analyze` completed with 0 errors/warnings.
- **Flutter Test Suite**: 132/132 tests passed (including `test/phase16_access_control_test.dart`).
- **Monorepo Validator**: 26/26 test suites passed.
