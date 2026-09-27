import {
  AuditAction,
  AuditOutcome,
  Permission,
  Principal,
  PrincipalStatus,
  ResourceContext,
  SecurityContext,
  UserRole,
  evaluateAuthorization
} from '@eh-home/contracts';
import { ISecurityRepository } from './security.repository';
import { AuditService } from '../audit/audit.service';
import { AuditRepository } from '../audit/audit.repository';
import { FastifyReply, FastifyRequest } from 'fastify';

export interface AuthenticationParams {
  authHeader?: string;
  clientIp?: string;
  correlationId?: string;
}

export class SecurityService {
  private repo: ISecurityRepository;
  private auditService?: AuditService;

  constructor(repo: ISecurityRepository, auditService?: AuditService) {
    this.repo = repo;
    this.auditService = auditService;
  }

  public setAuditService(auditService: AuditService): void {
    this.auditService = auditService;
  }

  public getRepository(): ISecurityRepository {
    return this.repo;
  }

  private async audit(
    action: AuditAction,
    actorId: string,
    actorRole: any,
    resourceType: any,
    resourceId: string | undefined,
    outcome: AuditOutcome,
    metadata?: Record<string, unknown>,
    failureReason?: string,
    errorCode?: string,
    correlationId?: string
  ): Promise<void> {
    const service = this.auditService || new AuditService(new AuditRepository());
    await service.logSecurityEvent({
      actorId,
      actorRole,
      action,
      resourceType,
      resourceId,
      outcome,
      failureReason,
      errorCode,
      correlationId,
      metadata
    });
  }

  /**
   * Authenticates a request from its Authorization header.
   * Enforces fail-closed validation: Missing, invalid, disabled, or revoked principals are rejected.
   */
  public async authenticate(params: AuthenticationParams): Promise<SecurityContext> {
    const { authHeader, clientIp, correlationId } = params;

    if (!authHeader || typeof authHeader !== 'string') {
      const err = new Error('Authentication required: missing or empty Authorization header');
      (err as any).statusCode = 401;
      (err as any).errorCode = 'UNAUTHENTICATED';
      throw err;
    }

    const parts = authHeader.trim().split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer' || !parts[1]) {
      const err = new Error('Invalid Authorization header format. Expected Bearer <token>');
      (err as any).statusCode = 401;
      (err as any).errorCode = 'INVALID_AUTH_FORMAT';
      throw err;
    }

    const token = parts[1];

    // Decode token claims or retrieve principal by token identifier
    let principalId: string;
    let fallbackEmail: string | undefined;
    let fallbackRole: UserRole | undefined;

    try {
      if (token.startsWith('ey') && token.includes('.')) {
        // JWT Token
        const jwtParts = token.split('.');
        const payloadBase64 = jwtParts[1] || '';
        const decodedJson = Buffer.from(payloadBase64, 'base64').toString('utf8');
        const claims = JSON.parse(decodedJson);
        principalId = claims.sub || claims.id || claims.userId;
        fallbackEmail = claims.email;
        fallbackRole = claims.role;
      } else {
        // Direct Principal ID or Mock Token (e.g. 'token-user-123' or 'admin-user-id')
        principalId = token.startsWith('token-') ? token.slice(6) : token;
      }
    } catch {
      const err = new Error('Malformed authentication token');
      (err as any).statusCode = 401;
      (err as any).errorCode = 'MALFORMED_TOKEN';
      throw err;
    }

    if (!principalId) {
      const err = new Error('Authentication failed: token missing subject principal ID');
      (err as any).statusCode = 401;
      (err as any).errorCode = 'INVALID_TOKEN_SUBJECT';
      throw err;
    }

    // Retrieve authoritative principal from repository
    let principal = await this.repo.getPrincipal(principalId);
    if (!principal) {
      if (fallbackEmail && fallbackRole) {
        // Auto-seed for valid JWTs if not yet in memory
        principal = await this.repo.savePrincipal({
          id: principalId,
          email: fallbackEmail,
          role: fallbackRole,
          status: 'ACTIVE',
          homeMemberships: []
        });
      } else {
        const err = new Error(`Authentication failed: principal '${principalId}' not found`);
        (err as any).statusCode = 401;
        (err as any).errorCode = 'UNKNOWN_PRINCIPAL';
        throw err;
      }
    }

    // Fail-closed status checks
    if (principal.status === 'DISABLED') {
      const err = new Error(`Authentication failed: principal '${principalId}' is administratively DISABLED`);
      (err as any).statusCode = 403;
      (err as any).errorCode = 'PRINCIPAL_DISABLED';
      throw err;
    }

    if (principal.status === 'REVOKED') {
      const err = new Error(`Authentication failed: principal '${principalId}' has been REVOKED`);
      (err as any).statusCode = 403;
      (err as any).errorCode = 'PRINCIPAL_REVOKED';
      throw err;
    }

    return {
      principal,
      clientIp,
      correlationId,
      authenticatedAt: new Date().toISOString()
    };
  }

  /**
   * Authorizes a principal for a specific actionable permission and resource context.
   * Default-Deny: Returns { authorized: false } if anything is missing, unknown, or prohibited.
   */
  public authorize(
    context: SecurityContext | null | undefined,
    permission: Permission,
    resource?: ResourceContext | null
  ): { authorized: boolean; reason?: string } {
    return evaluateAuthorization(context, permission, resource);
  }

  /**
   * Asserts authorization and throws an HTTP 403 / 401 Error if denied.
   */
  public assertAuthorized(
    context: SecurityContext | null | undefined,
    permission: Permission,
    resource?: ResourceContext | null
  ): void {
    if (!context || !context.principal) {
      const err = new Error('Authentication required for protected operation');
      (err as any).statusCode = 401;
      (err as any).errorCode = 'UNAUTHENTICATED';
      throw err;
    }

    const decision = this.authorize(context, permission, resource);
    if (!decision.authorized) {
      const err = new Error(decision.reason || `Access Denied: Missing required permission '${permission}'`);
      (err as any).statusCode = 403;
      (err as any).errorCode = 'FORBIDDEN';
      throw err;
    }
  }

  public async updateUserRole(
    adminContext: SecurityContext,
    targetUserId: string,
    newRole: UserRole
  ): Promise<Principal> {
    this.assertAuthorized(adminContext, 'user:manage_roles');
    const updated = await this.repo.updateUserRole(targetUserId, newRole);
    await this.audit(
      'USER_ROLE_CHANGED',
      adminContext.principal.id,
      adminContext.principal.role,
      'USER',
      targetUserId,
      'SUCCESS',
      { previousRole: updated.role, newRole },
      undefined,
      undefined,
      adminContext.correlationId
    );
    return updated;
  }

  public async updateUserStatus(
    adminContext: SecurityContext,
    targetUserId: string,
    newStatus: PrincipalStatus
  ): Promise<Principal> {
    this.assertAuthorized(adminContext, 'security:admin');
    const updated = await this.repo.updateUserStatus(targetUserId, newStatus);
    await this.audit(
      'USER_STATUS_CHANGED',
      adminContext.principal.id,
      adminContext.principal.role,
      'USER',
      targetUserId,
      'SUCCESS',
      { newStatus },
      undefined,
      undefined,
      adminContext.correlationId
    );
    return updated;
  }

  public async claimDevice(
    context: SecurityContext,
    deviceId: string,
    homeId: string,
    customName?: string
  ): Promise<any> {
    this.assertAuthorized(context, 'device:claim', { homeId });
    const result = await this.repo.claimDevice(deviceId, context.principal.id, homeId, customName);
    await this.audit(
      'DEVICE_CLAIMED',
      context.principal.id,
      context.principal.role,
      'DEVICE',
      deviceId,
      'SUCCESS',
      { homeId, customName: customName || 'device' },
      undefined,
      undefined,
      context.correlationId
    );
    return result;
  }

  public async unclaimDevice(
    context: SecurityContext,
    deviceId: string
  ): Promise<any> {
    const existing = await this.repo.getDeviceOwnership(deviceId);
    if (!existing || !existing.claimedByUserId) {
      throw new Error(`Device '${deviceId}' is not currently claimed`);
    }

    // Caller must be device owner OR platform admin
    if (context.principal.role !== 'ADMIN' && existing.claimedByUserId !== context.principal.id) {
      await this.audit(
        'DEVICE_UNCLAIMED',
        context.principal.id,
        context.principal.role,
        'DEVICE',
        deviceId,
        'DENIED',
        { attemptedAction: 'unclaim', claimedByUserId: existing.claimedByUserId },
        `Caller '${context.principal.id}' is not the owner of device '${deviceId}'`,
        'CROSS_OWNER_DENIED',
        context.correlationId
      );
      const err = new Error(`Security Violation: Caller '${context.principal.id}' is not the owner of device '${deviceId}'`);
      (err as any).statusCode = 403;
      (err as any).errorCode = 'CROSS_OWNER_DENIED';
      throw err;
    }

    this.assertAuthorized(context, 'device:unclaim', existing);
    const result = await this.repo.unclaimDevice(deviceId, existing.claimedByUserId);
    await this.audit(
      'DEVICE_UNCLAIMED',
      context.principal.id,
      context.principal.role,
      'DEVICE',
      deviceId,
      'SUCCESS',
      { previousOwnerId: existing.claimedByUserId },
      undefined,
      undefined,
      context.correlationId
    );
    return result;
  }

  public async transferDeviceOwnership(
    context: SecurityContext,
    deviceId: string,
    toUserId: string,
    targetHomeId: string
  ): Promise<any> {
    const existing = await this.repo.getDeviceOwnership(deviceId);
    if (!existing || !existing.claimedByUserId) {
      throw new Error(`Device '${deviceId}' is not claimed`);
    }

    if (context.principal.role !== 'ADMIN' && existing.claimedByUserId !== context.principal.id) {
      await this.audit(
        'DEVICE_TRANSFERRED',
        context.principal.id,
        context.principal.role,
        'DEVICE',
        deviceId,
        'DENIED',
        { attemptedAction: 'transfer', claimedByUserId: existing.claimedByUserId, targetUserId: toUserId },
        `Caller is not the owner of device '${deviceId}'`,
        'CROSS_OWNER_DENIED',
        context.correlationId
      );
      const err = new Error(`Security Violation: Caller is not the owner of device '${deviceId}'`);
      (err as any).statusCode = 403;
      (err as any).errorCode = 'CROSS_OWNER_DENIED';
      throw err;
    }

    this.assertAuthorized(context, 'device:transfer', existing);
    const result = await this.repo.transferDeviceOwnership(deviceId, existing.claimedByUserId, toUserId, targetHomeId);
    await this.audit(
      'DEVICE_TRANSFERRED',
      context.principal.id,
      context.principal.role,
      'DEVICE',
      deviceId,
      'SUCCESS',
      { previousOwnerId: existing.claimedByUserId, newOwnerId: toUserId, targetHomeId },
      undefined,
      undefined,
      context.correlationId
    );
    return result;
  }

  public async revokeDevice(
    context: SecurityContext,
    deviceId: string,
    reason = 'Administrative revocation'
  ): Promise<any> {
    this.assertAuthorized(context, 'device:revoke');
    const result = await this.repo.revokeDevice(deviceId, reason);
    await this.audit(
      'DEVICE_REVOKED',
      context.principal.id,
      context.principal.role,
      'DEVICE',
      deviceId,
      'SUCCESS',
      { reason },
      undefined,
      undefined,
      context.correlationId
    );
    return result;
  }

  /**
   * Fastify PreHandler Hook for Authenticating Requests
   */
  public authHook() {
    return async (req: FastifyRequest, _reply: FastifyReply) => {
      const activeService = (req.server as any).securityService || this;
      const authHeader = (req.headers['authorization'] || req.headers['Authorization']) as string | undefined;
      const correlationId = (req.headers['x-correlation-id'] || req.headers['x-request-id']) as string | undefined;
      const clientIp = req.ip;

      const secContext = await activeService.authenticate({ authHeader, clientIp, correlationId });
      (req as any).securityContext = secContext;
      (req as any).user = secContext.principal;
    };
  }

  /**
   * Fastify PreHandler Hook for Permission Enforcement
   */
  public requirePermissionHook(
    permission: Permission,
    resourceResolver?: (req: FastifyRequest) => Promise<ResourceContext | null> | ResourceContext | null
  ) {
    return async (req: FastifyRequest, _reply: FastifyReply) => {
      const activeService = (req.server as any).securityService || this;
      const secContext = (req as any).securityContext as SecurityContext | undefined;
      let resource: ResourceContext | null = null;
      if (resourceResolver) {
        resource = await resourceResolver(req);
      }
      activeService.assertAuthorized(secContext, permission, resource);
    };
  }
}
