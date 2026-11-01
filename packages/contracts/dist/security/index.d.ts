import { z } from 'zod';
/**
 * EH Home Canonical RBAC & Security Contracts (Part 14)
 * Single source of truth for platform roles, permissions, security contexts,
 * resource authorization, and fail-closed default-deny policies.
 */
export declare const UserRoleSchema: z.ZodEnum<["ADMIN", "OPERATOR", "RELEASE_ENGINEER", "AUDITOR", "USER", "SERVICE"]>;
export type UserRole = z.infer<typeof UserRoleSchema>;
export declare const HomeRoleSchema: z.ZodEnum<["OWNER", "HOME_ADMIN", "MEMBER", "GUEST", "VIEWER"]>;
export type HomeRole = z.infer<typeof HomeRoleSchema>;
export declare const PrincipalStatusSchema: z.ZodEnum<["ACTIVE", "DISABLED", "REVOKED", "PENDING_ACTIVATION"]>;
export type PrincipalStatus = z.infer<typeof PrincipalStatusSchema>;
export declare const PermissionSchema: z.ZodEnum<["product:read", "product:write", "hardware:read", "hardware:write", "firmware:read", "firmware:write", "firmware:approve", "firmware:release", "firmware:revoke", "ota:read", "ota:authorize", "ota:execute", "manufacturing:provision", "manufacturing:qc", "manufacturing:pack", "manufacturing:inventory", "manufacturing:print", "storage:read", "storage:write", "storage:delete", "backup:create", "backup:read", "backup:restore", "backup:delete", "device:read", "device:write", "device:control", "device:claim", "device:unclaim", "device:transfer", "device:revoke", "device:quarantine", "home:read", "home:write", "home:delete", "home:manage_members", "user:read", "user:write", "user:manage_roles", "audit:read", "security:admin"]>;
export type Permission = z.infer<typeof PermissionSchema>;
export declare const ROLE_PERMISSIONS_MAP: Record<UserRole, readonly Permission[]>;
export declare const HOME_ROLE_PERMISSIONS_MAP: Record<HomeRole, readonly Permission[]>;
export declare const HomeMembershipInfoSchema: z.ZodObject<{
    homeId: z.ZodString;
    role: z.ZodEnum<["OWNER", "HOME_ADMIN", "MEMBER", "GUEST", "VIEWER"]>;
}, "strip", z.ZodTypeAny, {
    role: "OWNER" | "HOME_ADMIN" | "MEMBER" | "GUEST" | "VIEWER";
    homeId: string;
}, {
    role: "OWNER" | "HOME_ADMIN" | "MEMBER" | "GUEST" | "VIEWER";
    homeId: string;
}>;
export type HomeMembershipInfo = z.infer<typeof HomeMembershipInfoSchema>;
export declare const PrincipalSchema: z.ZodObject<{
    id: z.ZodString;
    email: z.ZodString;
    role: z.ZodEnum<["ADMIN", "OPERATOR", "RELEASE_ENGINEER", "AUDITOR", "USER", "SERVICE"]>;
    status: z.ZodDefault<z.ZodEnum<["ACTIVE", "DISABLED", "REVOKED", "PENDING_ACTIVATION"]>>;
    homeMemberships: z.ZodDefault<z.ZodArray<z.ZodObject<{
        homeId: z.ZodString;
        role: z.ZodEnum<["OWNER", "HOME_ADMIN", "MEMBER", "GUEST", "VIEWER"]>;
    }, "strip", z.ZodTypeAny, {
        role: "OWNER" | "HOME_ADMIN" | "MEMBER" | "GUEST" | "VIEWER";
        homeId: string;
    }, {
        role: "OWNER" | "HOME_ADMIN" | "MEMBER" | "GUEST" | "VIEWER";
        homeId: string;
    }>, "many">>;
}, "strip", z.ZodTypeAny, {
    status: "ACTIVE" | "REVOKED" | "DISABLED" | "PENDING_ACTIVATION";
    id: string;
    role: "ADMIN" | "OPERATOR" | "RELEASE_ENGINEER" | "AUDITOR" | "USER" | "SERVICE";
    email: string;
    homeMemberships: {
        role: "OWNER" | "HOME_ADMIN" | "MEMBER" | "GUEST" | "VIEWER";
        homeId: string;
    }[];
}, {
    id: string;
    role: "ADMIN" | "OPERATOR" | "RELEASE_ENGINEER" | "AUDITOR" | "USER" | "SERVICE";
    email: string;
    status?: "ACTIVE" | "REVOKED" | "DISABLED" | "PENDING_ACTIVATION" | undefined;
    homeMemberships?: {
        role: "OWNER" | "HOME_ADMIN" | "MEMBER" | "GUEST" | "VIEWER";
        homeId: string;
    }[] | undefined;
}>;
export type Principal = z.infer<typeof PrincipalSchema>;
export declare const SecurityContextSchema: z.ZodObject<{
    principal: z.ZodObject<{
        id: z.ZodString;
        email: z.ZodString;
        role: z.ZodEnum<["ADMIN", "OPERATOR", "RELEASE_ENGINEER", "AUDITOR", "USER", "SERVICE"]>;
        status: z.ZodDefault<z.ZodEnum<["ACTIVE", "DISABLED", "REVOKED", "PENDING_ACTIVATION"]>>;
        homeMemberships: z.ZodDefault<z.ZodArray<z.ZodObject<{
            homeId: z.ZodString;
            role: z.ZodEnum<["OWNER", "HOME_ADMIN", "MEMBER", "GUEST", "VIEWER"]>;
        }, "strip", z.ZodTypeAny, {
            role: "OWNER" | "HOME_ADMIN" | "MEMBER" | "GUEST" | "VIEWER";
            homeId: string;
        }, {
            role: "OWNER" | "HOME_ADMIN" | "MEMBER" | "GUEST" | "VIEWER";
            homeId: string;
        }>, "many">>;
    }, "strip", z.ZodTypeAny, {
        status: "ACTIVE" | "REVOKED" | "DISABLED" | "PENDING_ACTIVATION";
        id: string;
        role: "ADMIN" | "OPERATOR" | "RELEASE_ENGINEER" | "AUDITOR" | "USER" | "SERVICE";
        email: string;
        homeMemberships: {
            role: "OWNER" | "HOME_ADMIN" | "MEMBER" | "GUEST" | "VIEWER";
            homeId: string;
        }[];
    }, {
        id: string;
        role: "ADMIN" | "OPERATOR" | "RELEASE_ENGINEER" | "AUDITOR" | "USER" | "SERVICE";
        email: string;
        status?: "ACTIVE" | "REVOKED" | "DISABLED" | "PENDING_ACTIVATION" | undefined;
        homeMemberships?: {
            role: "OWNER" | "HOME_ADMIN" | "MEMBER" | "GUEST" | "VIEWER";
            homeId: string;
        }[] | undefined;
    }>;
    correlationId: z.ZodOptional<z.ZodString>;
    clientIp: z.ZodOptional<z.ZodString>;
    tokenClaims: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
    authenticatedAt: z.ZodDefault<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    principal: {
        status: "ACTIVE" | "REVOKED" | "DISABLED" | "PENDING_ACTIVATION";
        id: string;
        role: "ADMIN" | "OPERATOR" | "RELEASE_ENGINEER" | "AUDITOR" | "USER" | "SERVICE";
        email: string;
        homeMemberships: {
            role: "OWNER" | "HOME_ADMIN" | "MEMBER" | "GUEST" | "VIEWER";
            homeId: string;
        }[];
    };
    authenticatedAt: string;
    correlationId?: string | undefined;
    clientIp?: string | undefined;
    tokenClaims?: Record<string, unknown> | undefined;
}, {
    principal: {
        id: string;
        role: "ADMIN" | "OPERATOR" | "RELEASE_ENGINEER" | "AUDITOR" | "USER" | "SERVICE";
        email: string;
        status?: "ACTIVE" | "REVOKED" | "DISABLED" | "PENDING_ACTIVATION" | undefined;
        homeMemberships?: {
            role: "OWNER" | "HOME_ADMIN" | "MEMBER" | "GUEST" | "VIEWER";
            homeId: string;
        }[] | undefined;
    };
    correlationId?: string | undefined;
    clientIp?: string | undefined;
    tokenClaims?: Record<string, unknown> | undefined;
    authenticatedAt?: string | undefined;
}>;
export type SecurityContext = z.infer<typeof SecurityContextSchema>;
export declare const ResourceContextSchema: z.ZodObject<{
    homeId: z.ZodOptional<z.ZodString>;
    ownerId: z.ZodOptional<z.ZodString>;
    deviceId: z.ZodOptional<z.ZodString>;
    deviceClaimStatus: z.ZodOptional<z.ZodEnum<["CLAIMED", "UNCLAIMED", "REVOKED"]>>;
    claimedByUserId: z.ZodOptional<z.ZodString>;
    assignedHomeId: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    deviceId?: string | undefined;
    homeId?: string | undefined;
    ownerId?: string | undefined;
    deviceClaimStatus?: "REVOKED" | "CLAIMED" | "UNCLAIMED" | undefined;
    claimedByUserId?: string | undefined;
    assignedHomeId?: string | undefined;
}, {
    deviceId?: string | undefined;
    homeId?: string | undefined;
    ownerId?: string | undefined;
    deviceClaimStatus?: "REVOKED" | "CLAIMED" | "UNCLAIMED" | undefined;
    claimedByUserId?: string | undefined;
    assignedHomeId?: string | undefined;
}>;
export type ResourceContext = z.infer<typeof ResourceContextSchema>;
export declare const AuthorizationDecisionSchema: z.ZodObject<{
    authorized: z.ZodBoolean;
    principalId: z.ZodString;
    role: z.ZodEnum<["ADMIN", "OPERATOR", "RELEASE_ENGINEER", "AUDITOR", "USER", "SERVICE"]>;
    permission: z.ZodEnum<["product:read", "product:write", "hardware:read", "hardware:write", "firmware:read", "firmware:write", "firmware:approve", "firmware:release", "firmware:revoke", "ota:read", "ota:authorize", "ota:execute", "manufacturing:provision", "manufacturing:qc", "manufacturing:pack", "manufacturing:inventory", "manufacturing:print", "storage:read", "storage:write", "storage:delete", "backup:create", "backup:read", "backup:restore", "backup:delete", "device:read", "device:write", "device:control", "device:claim", "device:unclaim", "device:transfer", "device:revoke", "device:quarantine", "home:read", "home:write", "home:delete", "home:manage_members", "user:read", "user:write", "user:manage_roles", "audit:read", "security:admin"]>;
    resourceType: z.ZodOptional<z.ZodString>;
    resourceId: z.ZodOptional<z.ZodString>;
    reason: z.ZodOptional<z.ZodString>;
    evaluatedAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    role: "ADMIN" | "OPERATOR" | "RELEASE_ENGINEER" | "AUDITOR" | "USER" | "SERVICE";
    evaluatedAt: string;
    authorized: boolean;
    principalId: string;
    permission: "product:read" | "product:write" | "hardware:read" | "hardware:write" | "firmware:read" | "firmware:write" | "firmware:approve" | "firmware:release" | "firmware:revoke" | "ota:read" | "ota:authorize" | "ota:execute" | "manufacturing:provision" | "manufacturing:qc" | "manufacturing:pack" | "manufacturing:inventory" | "manufacturing:print" | "storage:read" | "storage:write" | "storage:delete" | "backup:create" | "backup:read" | "backup:restore" | "backup:delete" | "device:read" | "device:write" | "device:control" | "device:claim" | "device:unclaim" | "device:transfer" | "device:revoke" | "device:quarantine" | "home:read" | "home:write" | "home:delete" | "home:manage_members" | "user:read" | "user:write" | "user:manage_roles" | "audit:read" | "security:admin";
    reason?: string | undefined;
    resourceType?: string | undefined;
    resourceId?: string | undefined;
}, {
    role: "ADMIN" | "OPERATOR" | "RELEASE_ENGINEER" | "AUDITOR" | "USER" | "SERVICE";
    evaluatedAt: string;
    authorized: boolean;
    principalId: string;
    permission: "product:read" | "product:write" | "hardware:read" | "hardware:write" | "firmware:read" | "firmware:write" | "firmware:approve" | "firmware:release" | "firmware:revoke" | "ota:read" | "ota:authorize" | "ota:execute" | "manufacturing:provision" | "manufacturing:qc" | "manufacturing:pack" | "manufacturing:inventory" | "manufacturing:print" | "storage:read" | "storage:write" | "storage:delete" | "backup:create" | "backup:read" | "backup:restore" | "backup:delete" | "device:read" | "device:write" | "device:control" | "device:claim" | "device:unclaim" | "device:transfer" | "device:revoke" | "device:quarantine" | "home:read" | "home:write" | "home:delete" | "home:manage_members" | "user:read" | "user:write" | "user:manage_roles" | "audit:read" | "security:admin";
    reason?: string | undefined;
    resourceType?: string | undefined;
    resourceId?: string | undefined;
}>;
export type AuthorizationDecision = z.infer<typeof AuthorizationDecisionSchema>;
/**
 * Checks whether a platform user role possesses the required permission.
 * Default-deny: Returns false if role or permission is unknown or missing.
 */
export declare function hasRolePermission(role: UserRole | string | undefined | null, permission: Permission): boolean;
/**
 * Checks whether a home membership role possesses the required home permission.
 */
export declare function hasHomeRolePermission(homeRole: HomeRole | string | undefined | null, permission: Permission): boolean;
/**
 * Evaluates full authorization for a principal against a permission and optional resource context.
 * Strictly enforces default-deny and fail-closed security.
 */
export declare function evaluateAuthorization(context: SecurityContext | null | undefined, permission: Permission, resource?: ResourceContext | null): {
    authorized: boolean;
    reason?: string;
};
//# sourceMappingURL=index.d.ts.map