import { AuditAction, AuditOutcome, AuditQueryFilter, AuditRecord, AuditResourceType, AuditSeverity, SecurityContext } from '@eh-home/contracts';
import { IAuditRepository } from './audit.repository';
export interface LogSecurityEventParams {
    actorId: string;
    actorEmail?: string;
    actorRole?: any;
    action: AuditAction;
    resourceType: AuditResourceType;
    resourceId?: string;
    outcome: AuditOutcome;
    severity?: AuditSeverity;
    failureReason?: string;
    errorCode?: string;
    correlationId?: string;
    clientIp?: string;
    userAgent?: string;
    metadata?: Record<string, unknown>;
}
export declare class AuditService {
    private repo;
    constructor(repo: IAuditRepository);
    getRepository(): IAuditRepository;
    /**
     * Logs an immutable security or operational audit record.
     * Strictly enforces zero-secret policy before recording.
     */
    logSecurityEvent(params: LogSecurityEventParams): Promise<AuditRecord>;
    /**
     * Queries audit records with strict permission checks and pagination.
     */
    queryAuditEvents(filter: AuditQueryFilter, _callerContext?: SecurityContext): Promise<{
        records: AuditRecord[];
        total: number;
    }>;
}
//# sourceMappingURL=audit.service.d.ts.map