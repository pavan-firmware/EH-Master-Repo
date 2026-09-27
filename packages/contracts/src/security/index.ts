import { z } from 'zod';
import { IsoDateTimeSchema } from '../common';

/**
 * EH Home Canonical RBAC & Security Contracts (Part 14)
 * Single source of truth for platform roles, permissions, security contexts,
 * resource authorization, and fail-closed default-deny policies.
 */

// 1. Platform & System User Roles
export const UserRoleSchema = z.enum([
  'ADMIN',                 // Full administrative authority over platform & security
  'OPERATOR',              // Manufacturing, factory provisioning, QC, packing, inventory
  'RELEASE_ENGINEER',      // Firmware builds, artifact registration, approval, OTA rollout
  'AUDITOR',               // Compliance verification, read-only audit log inspection
  'USER',                  // Standard consumer user (subject to home memberships)
  'SERVICE'                // System background daemon / worker service
]);
export type UserRole = z.infer<typeof UserRoleSchema>;

// 2. Home-Level Membership Roles
export const HomeRoleSchema = z.enum([
  'OWNER',                 // Home creator/owner: delete home, transfer ownership, all perms
  'HOME_ADMIN',            // Home administrator: manage devices, members, automations
  'MEMBER',                // Standard member: control devices, execute scenes
  'GUEST',                 // Guest member: restricted device control, view status
  'VIEWER'                 // View-only member: no control or state mutation
]);
export type HomeRole = z.infer<typeof HomeRoleSchema>;

// 3. Principal Status
export const PrincipalStatusSchema = z.enum([
  'ACTIVE',                // Normal active principal
  'DISABLED',              // Administratively disabled (all requests denied)
  'REVOKED',               // Cryptographically or security-revoked (all requests denied)
  'PENDING_ACTIVATION'     // Account created but not yet verified
]);
export type PrincipalStatus = z.infer<typeof PrincipalStatusSchema>;

// 4. Actionable Platform Permissions
export const PermissionSchema = z.enum([
  // Products & Hardware BOM
  'product:read',
  'product:write',
  'hardware:read',
  'hardware:write',

  // Firmware & Binary Releases
  'firmware:read',
  'firmware:write',
  'firmware:approve',
  'firmware:release',
  'firmware:revoke',

  // OTA Updates
  'ota:read',
  'ota:authorize',
  'ota:execute',

  // Manufacturing, Factory & Inventory
  'manufacturing:provision',
  'manufacturing:qc',
  'manufacturing:pack',
  'manufacturing:inventory',
  'manufacturing:print',

  // Storage Operations
  'storage:read',
  'storage:write',
  'storage:delete',

  // Database & System Backups
  'backup:create',
  'backup:read',
  'backup:restore',
  'backup:delete',

  // Device Management & Control
  'device:read',
  'device:write',
  'device:control',
  'device:claim',
  'device:unclaim',
  'device:transfer',
  'device:revoke',
  'device:quarantine',

  // Home Management
  'home:read',
  'home:write',
  'home:delete',
  'home:manage_members',

  // User & Identity Administration
  'user:read',
  'user:write',
  'user:manage_roles',

  // Security & Audit Inspection
  'audit:read',
  'security:admin'
]);
export type Permission = z.infer<typeof PermissionSchema>;

// 5. Canonical Role-to-Permission Matrix
export const ROLE_PERMISSIONS_MAP: Record<UserRole, readonly Permission[]> = {
  ADMIN: [
    'product:read', 'product:write',
    'hardware:read', 'hardware:write',
    'firmware:read', 'firmware:write', 'firmware:approve', 'firmware:release', 'firmware:revoke',
    'ota:read', 'ota:authorize', 'ota:execute',
    'manufacturing:provision', 'manufacturing:qc', 'manufacturing:pack', 'manufacturing:inventory', 'manufacturing:print',
    'storage:read', 'storage:write', 'storage:delete',
    'backup:create', 'backup:read', 'backup:restore', 'backup:delete',
    'device:read', 'device:write', 'device:control', 'device:claim', 'device:unclaim', 'device:transfer', 'device:revoke', 'device:quarantine',
    'home:read', 'home:write', 'home:delete', 'home:manage_members',
    'user:read', 'user:write', 'user:manage_roles',
    'audit:read', 'security:admin'
  ],
  RELEASE_ENGINEER: [
    'product:read',
    'hardware:read',
    'firmware:read', 'firmware:write', 'firmware:approve', 'firmware:release', 'firmware:revoke',
    'ota:read', 'ota:authorize', 'ota:execute',
    'storage:read', 'storage:write',
    'device:read',
    'audit:read'
  ],
  OPERATOR: [
    'product:read',
    'hardware:read',
    'firmware:read',
    'manufacturing:provision', 'manufacturing:qc', 'manufacturing:pack', 'manufacturing:inventory', 'manufacturing:print',
    'storage:read', 'storage:write',
    'device:read', 'device:claim',
    'ota:read'
  ],
  AUDITOR: [
    'product:read',
    'hardware:read',
    'firmware:read',
    'ota:read',
    'storage:read',
    'backup:read',
    'device:read',
    'home:read',
    'user:read',
    'audit:read'
  ],
  USER: [
    'product:read',
    'device:read', 'device:control', 'device:claim', 'device:unclaim',
    'home:read', 'home:write', 'home:manage_members'
  ],
  SERVICE: [
    'product:read',
    'hardware:read',
    'firmware:read',
    'ota:read', 'ota:execute',
    'storage:read', 'storage:write',
    'backup:create', 'backup:read',
    'device:read', 'device:write', 'device:control',
    'manufacturing:inventory',
    'audit:read'
  ]
};

// 6. Home-Level Role-to-Permission Matrix
export const HOME_ROLE_PERMISSIONS_MAP: Record<HomeRole, readonly Permission[]> = {
  OWNER: [
    'home:read', 'home:write', 'home:delete', 'home:manage_members',
    'device:read', 'device:write', 'device:control', 'device:claim', 'device:unclaim', 'device:transfer'
  ],
  HOME_ADMIN: [
    'home:read', 'home:write', 'home:manage_members',
    'device:read', 'device:write', 'device:control', 'device:claim', 'device:unclaim'
  ],
  MEMBER: [
    'home:read',
    'device:read', 'device:control'
  ],
  GUEST: [
    'home:read',
    'device:read', 'device:control'
  ],
  VIEWER: [
    'home:read',
    'device:read'
  ]
};

// 7. Principal & Context Schemas
export const HomeMembershipInfoSchema = z.object({
  homeId: z.string().min(1),
  role: HomeRoleSchema
});
export type HomeMembershipInfo = z.infer<typeof HomeMembershipInfoSchema>;

export const PrincipalSchema = z.object({
  id: z.string().min(1),
  email: z.string().email(),
  role: UserRoleSchema,
  status: PrincipalStatusSchema.default('ACTIVE'),
  homeMemberships: z.array(HomeMembershipInfoSchema).default([])
});
export type Principal = z.infer<typeof PrincipalSchema>;

export const SecurityContextSchema = z.object({
  principal: PrincipalSchema,
  correlationId: z.string().optional(),
  clientIp: z.string().optional(),
  tokenClaims: z.record(z.unknown()).optional(),
  authenticatedAt: IsoDateTimeSchema.default(() => new Date().toISOString())
});
export type SecurityContext = z.infer<typeof SecurityContextSchema>;

export const ResourceContextSchema = z.object({
  homeId: z.string().optional(),
  ownerId: z.string().optional(),
  deviceId: z.string().optional(),
  deviceClaimStatus: z.enum(['CLAIMED', 'UNCLAIMED', 'REVOKED']).optional(),
  claimedByUserId: z.string().optional(),
  assignedHomeId: z.string().optional()
});
export type ResourceContext = z.infer<typeof ResourceContextSchema>;

export const AuthorizationDecisionSchema = z.object({
  authorized: booleanValue(),
  principalId: z.string(),
  role: UserRoleSchema,
  permission: PermissionSchema,
  resourceType: z.string().optional(),
  resourceId: z.string().optional(),
  reason: z.string().optional(),
  evaluatedAt: IsoDateTimeSchema
});
export type AuthorizationDecision = z.infer<typeof AuthorizationDecisionSchema>;

function booleanValue() {
  return z.boolean();
}

/**
 * Checks whether a platform user role possesses the required permission.
 * Default-deny: Returns false if role or permission is unknown or missing.
 */
export function hasRolePermission(role: UserRole | string | undefined | null, permission: Permission): boolean {
  if (!role || typeof role !== 'string') return false;
  const normalizedRole = role.toUpperCase() as UserRole;
  const allowedPerms = ROLE_PERMISSIONS_MAP[normalizedRole];
  if (!allowedPerms) return false;
  return allowedPerms.includes(permission);
}

/**
 * Checks whether a home membership role possesses the required home permission.
 */
export function hasHomeRolePermission(homeRole: HomeRole | string | undefined | null, permission: Permission): boolean {
  if (!homeRole || typeof homeRole !== 'string') return false;
  const normalizedRole = homeRole.toUpperCase() as HomeRole;
  const allowedPerms = HOME_ROLE_PERMISSIONS_MAP[normalizedRole];
  if (!allowedPerms) return false;
  return allowedPerms.includes(permission);
}

/**
 * Evaluates full authorization for a principal against a permission and optional resource context.
 * Strictly enforces default-deny and fail-closed security.
 */
export function evaluateAuthorization(
  context: SecurityContext | null | undefined,
  permission: Permission,
  resource?: ResourceContext | null
): { authorized: boolean; reason?: string } {
  // 1. Missing / Malformed Context -> DENY
  if (!context || !context.principal || !context.principal.id) {
    return { authorized: false, reason: 'Deny: Missing or unauthenticated security context' };
  }

  const { principal } = context;

  // 2. Disabled / Revoked Principal -> DENY
  if (principal.status !== 'ACTIVE') {
    return { authorized: false, reason: `Deny: Principal is in status '${principal.status}'` };
  }

  // 3. Platform Admin possesses universal platform authorization
  if (principal.role === 'ADMIN') {
    return { authorized: true };
  }

  // 4. Check Platform Role Permission
  const hasPlatformPerm = hasRolePermission(principal.role, permission);

  // 5. If operation is scoped to a Home Resource, evaluate home membership
  if (resource?.homeId) {
    const membership = principal.homeMemberships.find((m) => m.homeId === resource.homeId);
    if (!membership) {
      return { authorized: false, reason: `Deny: Principal is not a member of home '${resource.homeId}'` };
    }
    const hasHomePerm = hasHomeRolePermission(membership.role, permission);
    if (hasHomePerm) {
      return { authorized: true };
    }
    return {
      authorized: false,
      reason: `Deny: Home membership role '${membership.role}' lacks permission '${permission}' in home '${resource.homeId}'`
    };
  }

  // 6. If operation is scoped to a Device Resource with assigned home
  if (resource?.assignedHomeId) {
    const membership = principal.homeMemberships.find((m) => m.homeId === resource.assignedHomeId);
    if (!membership) {
      return { authorized: false, reason: `Deny: Principal is not a member of device's home '${resource.assignedHomeId}'` };
    }
    const hasHomePerm = hasHomeRolePermission(membership.role, permission);
    if (hasHomePerm) {
      return { authorized: true };
    }
    return {
      authorized: false,
      reason: `Deny: Home membership role '${membership.role}' lacks permission '${permission}' for device`
    };
  }

  // 7. If device is claimed by a specific user, enforce direct ownership
  if (resource?.claimedByUserId && resource.claimedByUserId !== principal.id) {
    return { authorized: false, reason: `Deny: Device is claimed by another user '${resource.claimedByUserId}'` };
  }

  // 8. General Platform Permission Evaluation
  if (!hasPlatformPerm) {
    return { authorized: false, reason: `Deny: Role '${principal.role}' lacks permission '${permission}'` };
  }

  return { authorized: true };
}
