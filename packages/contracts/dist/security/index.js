"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthorizationDecisionSchema = exports.ResourceContextSchema = exports.SecurityContextSchema = exports.PrincipalSchema = exports.HomeMembershipInfoSchema = exports.HOME_ROLE_PERMISSIONS_MAP = exports.ROLE_PERMISSIONS_MAP = exports.PermissionSchema = exports.PrincipalStatusSchema = exports.HomeRoleSchema = exports.UserRoleSchema = void 0;
exports.hasRolePermission = hasRolePermission;
exports.hasHomeRolePermission = hasHomeRolePermission;
exports.evaluateAuthorization = evaluateAuthorization;
const zod_1 = require("zod");
const common_1 = require("../common");
/**
 * EH Home Canonical RBAC & Security Contracts (Part 14)
 * Single source of truth for platform roles, permissions, security contexts,
 * resource authorization, and fail-closed default-deny policies.
 */
// 1. Platform & System User Roles
exports.UserRoleSchema = zod_1.z.enum([
    'ADMIN', // Full administrative authority over platform & security
    'OPERATOR', // Manufacturing, factory provisioning, QC, packing, inventory
    'RELEASE_ENGINEER', // Firmware builds, artifact registration, approval, OTA rollout
    'AUDITOR', // Compliance verification, read-only audit log inspection
    'USER', // Standard consumer user (subject to home memberships)
    'SERVICE' // System background daemon / worker service
]);
// 2. Home-Level Membership Roles
exports.HomeRoleSchema = zod_1.z.enum([
    'OWNER', // Home creator/owner: delete home, transfer ownership, all perms
    'HOME_ADMIN', // Home administrator: manage devices, members, automations
    'MEMBER', // Standard member: control devices, execute scenes
    'GUEST', // Guest member: restricted device control, view status
    'VIEWER' // View-only member: no control or state mutation
]);
// 3. Principal Status
exports.PrincipalStatusSchema = zod_1.z.enum([
    'ACTIVE', // Normal active principal
    'DISABLED', // Administratively disabled (all requests denied)
    'REVOKED', // Cryptographically or security-revoked (all requests denied)
    'PENDING_ACTIVATION' // Account created but not yet verified
]);
// 4. Actionable Platform Permissions
exports.PermissionSchema = zod_1.z.enum([
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
// 5. Canonical Role-to-Permission Matrix
exports.ROLE_PERMISSIONS_MAP = {
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
exports.HOME_ROLE_PERMISSIONS_MAP = {
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
exports.HomeMembershipInfoSchema = zod_1.z.object({
    homeId: zod_1.z.string().min(1),
    role: exports.HomeRoleSchema
});
exports.PrincipalSchema = zod_1.z.object({
    id: zod_1.z.string().min(1),
    email: zod_1.z.string().email(),
    role: exports.UserRoleSchema,
    status: exports.PrincipalStatusSchema.default('ACTIVE'),
    homeMemberships: zod_1.z.array(exports.HomeMembershipInfoSchema).default([])
});
exports.SecurityContextSchema = zod_1.z.object({
    principal: exports.PrincipalSchema,
    correlationId: zod_1.z.string().optional(),
    clientIp: zod_1.z.string().optional(),
    tokenClaims: zod_1.z.record(zod_1.z.unknown()).optional(),
    authenticatedAt: common_1.IsoDateTimeSchema.default(() => new Date().toISOString())
});
exports.ResourceContextSchema = zod_1.z.object({
    homeId: zod_1.z.string().optional(),
    ownerId: zod_1.z.string().optional(),
    deviceId: zod_1.z.string().optional(),
    deviceClaimStatus: zod_1.z.enum(['CLAIMED', 'UNCLAIMED', 'REVOKED']).optional(),
    claimedByUserId: zod_1.z.string().optional(),
    assignedHomeId: zod_1.z.string().optional()
});
exports.AuthorizationDecisionSchema = zod_1.z.object({
    authorized: booleanValue(),
    principalId: zod_1.z.string(),
    role: exports.UserRoleSchema,
    permission: exports.PermissionSchema,
    resourceType: zod_1.z.string().optional(),
    resourceId: zod_1.z.string().optional(),
    reason: zod_1.z.string().optional(),
    evaluatedAt: common_1.IsoDateTimeSchema
});
function booleanValue() {
    return zod_1.z.boolean();
}
/**
 * Checks whether a platform user role possesses the required permission.
 * Default-deny: Returns false if role or permission is unknown or missing.
 */
function hasRolePermission(role, permission) {
    if (!role || typeof role !== 'string')
        return false;
    const normalizedRole = role.toUpperCase();
    const allowedPerms = exports.ROLE_PERMISSIONS_MAP[normalizedRole];
    if (!allowedPerms)
        return false;
    return allowedPerms.includes(permission);
}
/**
 * Checks whether a home membership role possesses the required home permission.
 */
function hasHomeRolePermission(homeRole, permission) {
    if (!homeRole || typeof homeRole !== 'string')
        return false;
    const normalizedRole = homeRole.toUpperCase();
    const allowedPerms = exports.HOME_ROLE_PERMISSIONS_MAP[normalizedRole];
    if (!allowedPerms)
        return false;
    return allowedPerms.includes(permission);
}
/**
 * Evaluates full authorization for a principal against a permission and optional resource context.
 * Strictly enforces default-deny and fail-closed security.
 */
function evaluateAuthorization(context, permission, resource) {
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
//# sourceMappingURL=index.js.map