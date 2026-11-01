import { Permission, Principal, PrincipalStatus, ResourceContext, SecurityContext, UserRole } from '@eh-home/contracts';
import { ISecurityRepository } from './security.repository';
import { AuditService } from '../audit/audit.service';
import { FastifyReply, FastifyRequest } from 'fastify';
export interface AuthenticationParams {
    authHeader?: string;
    clientIp?: string;
    correlationId?: string;
}
export declare class SecurityService {
    private repo;
    private auditService?;
    constructor(repo: ISecurityRepository, auditService?: AuditService);
    setAuditService(auditService: AuditService): void;
    getRepository(): ISecurityRepository;
    private audit;
    /**
     * Authenticates a request from its Authorization header.
     * Enforces fail-closed validation: Missing, invalid, disabled, or revoked principals are rejected.
     */
    authenticate(params: AuthenticationParams): Promise<SecurityContext>;
    /**
     * Authorizes a principal for a specific actionable permission and resource context.
     * Default-Deny: Returns { authorized: false } if anything is missing, unknown, or prohibited.
     */
    authorize(context: SecurityContext | null | undefined, permission: Permission, resource?: ResourceContext | null): {
        authorized: boolean;
        reason?: string;
    };
    /**
     * Asserts authorization and throws an HTTP 403 / 401 Error if denied.
     */
    assertAuthorized(context: SecurityContext | null | undefined, permission: Permission, resource?: ResourceContext | null): void;
    updateUserRole(adminContext: SecurityContext, targetUserId: string, newRole: UserRole): Promise<Principal>;
    updateUserStatus(adminContext: SecurityContext, targetUserId: string, newStatus: PrincipalStatus): Promise<Principal>;
    claimDevice(context: SecurityContext, deviceId: string, homeId: string, customName?: string): Promise<any>;
    unclaimDevice(context: SecurityContext, deviceId: string): Promise<any>;
    transferDeviceOwnership(context: SecurityContext, deviceId: string, toUserId: string, targetHomeId: string): Promise<any>;
    revokeDevice(context: SecurityContext, deviceId: string, reason?: string): Promise<any>;
    /**
     * Fastify PreHandler Hook for Authenticating Requests
     */
    authHook(): (req: FastifyRequest, _reply: FastifyReply) => Promise<void>;
    /**
     * Fastify PreHandler Hook for Permission Enforcement
     */
    requirePermissionHook(permission: Permission, resourceResolver?: (req: FastifyRequest) => Promise<ResourceContext | null> | ResourceContext | null): (req: FastifyRequest, _reply: FastifyReply) => Promise<void>;
}
//# sourceMappingURL=security.service.d.ts.map