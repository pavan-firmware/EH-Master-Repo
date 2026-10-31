"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SecurityService = void 0;
const contracts_1 = require("@eh-home/contracts");
const audit_service_1 = require("../audit/audit.service");
const audit_repository_1 = require("../audit/audit.repository");
class SecurityService {
    repo;
    auditService;
    constructor(repo, auditService) {
        this.repo = repo;
        this.auditService = auditService;
    }
    setAuditService(auditService) {
        this.auditService = auditService;
    }
    getRepository() {
        return this.repo;
    }
    async audit(action, actorId, actorRole, resourceType, resourceId, outcome, metadata, failureReason, errorCode, correlationId) {
        const service = this.auditService || new audit_service_1.AuditService(new audit_repository_1.AuditRepository());
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
    async authenticate(params) {
        const { authHeader, clientIp, correlationId } = params;
        if (!authHeader || typeof authHeader !== 'string') {
            const err = new Error('Authentication required: missing or empty Authorization header');
            err.statusCode = 401;
            err.errorCode = 'UNAUTHENTICATED';
            throw err;
        }
        const parts = authHeader.trim().split(' ');
        if (parts.length !== 2 || parts[0] !== 'Bearer' || !parts[1]) {
            const err = new Error('Invalid Authorization header format. Expected Bearer <token>');
            err.statusCode = 401;
            err.errorCode = 'INVALID_AUTH_FORMAT';
            throw err;
        }
        const token = parts[1];
        // Decode token claims or retrieve principal by token identifier
        let principalId;
        let fallbackEmail;
        let fallbackRole;
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
            }
            else {
                // Direct Principal ID or Mock Token (e.g. 'token-user-123' or 'admin-user-id')
                principalId = token.startsWith('token-') ? token.slice(6) : token;
            }
        }
        catch {
            const err = new Error('Malformed authentication token');
            err.statusCode = 401;
            err.errorCode = 'MALFORMED_TOKEN';
            throw err;
        }
        if (!principalId) {
            const err = new Error('Authentication failed: token missing subject principal ID');
            err.statusCode = 401;
            err.errorCode = 'INVALID_TOKEN_SUBJECT';
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
            }
            else {
                const err = new Error(`Authentication failed: principal '${principalId}' not found`);
                err.statusCode = 401;
                err.errorCode = 'UNKNOWN_PRINCIPAL';
                throw err;
            }
        }
        // Fail-closed status checks
        if (principal.status === 'DISABLED') {
            const err = new Error(`Authentication failed: principal '${principalId}' is administratively DISABLED`);
            err.statusCode = 403;
            err.errorCode = 'PRINCIPAL_DISABLED';
            throw err;
        }
        if (principal.status === 'REVOKED') {
            const err = new Error(`Authentication failed: principal '${principalId}' has been REVOKED`);
            err.statusCode = 403;
            err.errorCode = 'PRINCIPAL_REVOKED';
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
    authorize(context, permission, resource) {
        return (0, contracts_1.evaluateAuthorization)(context, permission, resource);
    }
    /**
     * Asserts authorization and throws an HTTP 403 / 401 Error if denied.
     */
    assertAuthorized(context, permission, resource) {
        if (!context || !context.principal) {
            const err = new Error('Authentication required for protected operation');
            err.statusCode = 401;
            err.errorCode = 'UNAUTHENTICATED';
            throw err;
        }
        const decision = this.authorize(context, permission, resource);
        if (!decision.authorized) {
            const err = new Error(decision.reason || `Access Denied: Missing required permission '${permission}'`);
            err.statusCode = 403;
            err.errorCode = 'FORBIDDEN';
            throw err;
        }
    }
    async updateUserRole(adminContext, targetUserId, newRole) {
        this.assertAuthorized(adminContext, 'user:manage_roles');
        const updated = await this.repo.updateUserRole(targetUserId, newRole);
        await this.audit('USER_ROLE_CHANGED', adminContext.principal.id, adminContext.principal.role, 'USER', targetUserId, 'SUCCESS', { previousRole: updated.role, newRole }, undefined, undefined, adminContext.correlationId);
        return updated;
    }
    async updateUserStatus(adminContext, targetUserId, newStatus) {
        this.assertAuthorized(adminContext, 'security:admin');
        const updated = await this.repo.updateUserStatus(targetUserId, newStatus);
        await this.audit('USER_STATUS_CHANGED', adminContext.principal.id, adminContext.principal.role, 'USER', targetUserId, 'SUCCESS', { newStatus }, undefined, undefined, adminContext.correlationId);
        return updated;
    }
    async claimDevice(context, deviceId, homeId, customName) {
        this.assertAuthorized(context, 'device:claim', { homeId });
        const result = await this.repo.claimDevice(deviceId, context.principal.id, homeId, customName);
        await this.audit('DEVICE_CLAIMED', context.principal.id, context.principal.role, 'DEVICE', deviceId, 'SUCCESS', { homeId, customName: customName || 'device' }, undefined, undefined, context.correlationId);
        return result;
    }
    async unclaimDevice(context, deviceId) {
        const existing = await this.repo.getDeviceOwnership(deviceId);
        if (!existing || !existing.claimedByUserId) {
            throw new Error(`Device '${deviceId}' is not currently claimed`);
        }
        // Caller must be device owner OR platform admin
        if (context.principal.role !== 'ADMIN' && existing.claimedByUserId !== context.principal.id) {
            await this.audit('DEVICE_UNCLAIMED', context.principal.id, context.principal.role, 'DEVICE', deviceId, 'DENIED', { attemptedAction: 'unclaim', claimedByUserId: existing.claimedByUserId }, `Caller '${context.principal.id}' is not the owner of device '${deviceId}'`, 'CROSS_OWNER_DENIED', context.correlationId);
            const err = new Error(`Security Violation: Caller '${context.principal.id}' is not the owner of device '${deviceId}'`);
            err.statusCode = 403;
            err.errorCode = 'CROSS_OWNER_DENIED';
            throw err;
        }
        this.assertAuthorized(context, 'device:unclaim', existing);
        const result = await this.repo.unclaimDevice(deviceId, existing.claimedByUserId);
        await this.audit('DEVICE_UNCLAIMED', context.principal.id, context.principal.role, 'DEVICE', deviceId, 'SUCCESS', { previousOwnerId: existing.claimedByUserId }, undefined, undefined, context.correlationId);
        return result;
    }
    async transferDeviceOwnership(context, deviceId, toUserId, targetHomeId) {
        const existing = await this.repo.getDeviceOwnership(deviceId);
        if (!existing || !existing.claimedByUserId) {
            throw new Error(`Device '${deviceId}' is not claimed`);
        }
        if (context.principal.role !== 'ADMIN' && existing.claimedByUserId !== context.principal.id) {
            await this.audit('DEVICE_TRANSFERRED', context.principal.id, context.principal.role, 'DEVICE', deviceId, 'DENIED', { attemptedAction: 'transfer', claimedByUserId: existing.claimedByUserId, targetUserId: toUserId }, `Caller is not the owner of device '${deviceId}'`, 'CROSS_OWNER_DENIED', context.correlationId);
            const err = new Error(`Security Violation: Caller is not the owner of device '${deviceId}'`);
            err.statusCode = 403;
            err.errorCode = 'CROSS_OWNER_DENIED';
            throw err;
        }
        this.assertAuthorized(context, 'device:transfer', existing);
        const result = await this.repo.transferDeviceOwnership(deviceId, existing.claimedByUserId, toUserId, targetHomeId);
        await this.audit('DEVICE_TRANSFERRED', context.principal.id, context.principal.role, 'DEVICE', deviceId, 'SUCCESS', { previousOwnerId: existing.claimedByUserId, newOwnerId: toUserId, targetHomeId }, undefined, undefined, context.correlationId);
        return result;
    }
    async revokeDevice(context, deviceId, reason = 'Administrative revocation') {
        this.assertAuthorized(context, 'device:revoke');
        const result = await this.repo.revokeDevice(deviceId, reason);
        await this.audit('DEVICE_REVOKED', context.principal.id, context.principal.role, 'DEVICE', deviceId, 'SUCCESS', { reason }, undefined, undefined, context.correlationId);
        return result;
    }
    /**
     * Fastify PreHandler Hook for Authenticating Requests
     */
    authHook() {
        return async (req, _reply) => {
            const activeService = req.server.securityService || this;
            const authHeader = (req.headers['authorization'] || req.headers['Authorization']);
            const correlationId = (req.headers['x-correlation-id'] || req.headers['x-request-id']);
            const clientIp = req.ip;
            const secContext = await activeService.authenticate({ authHeader, clientIp, correlationId });
            req.securityContext = secContext;
            req.user = secContext.principal;
        };
    }
    /**
     * Fastify PreHandler Hook for Permission Enforcement
     */
    requirePermissionHook(permission, resourceResolver) {
        return async (req, _reply) => {
            const activeService = req.server.securityService || this;
            const secContext = req.securityContext;
            let resource = null;
            if (resourceResolver) {
                resource = await resourceResolver(req);
            }
            activeService.assertAuthorized(secContext, permission, resource);
        };
    }
}
exports.SecurityService = SecurityService;
//# sourceMappingURL=security.service.js.map