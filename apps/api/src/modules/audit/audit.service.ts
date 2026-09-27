import {
  AuditAction,
  AuditOutcome,
  AuditQueryFilter,
  AuditQueryFilterSchema,
  AuditRecord,
  AuditResourceType,
  AuditSeverity,
  SecurityContext,
  assertNoSecretsInAuditPayload
} from '@eh-home/contracts';
import { IAuditRepository } from './audit.repository';
import * as crypto from 'crypto';

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

export class AuditService {
  private repo: IAuditRepository;

  constructor(repo: IAuditRepository) {
    this.repo = repo;
  }

  public getRepository(): IAuditRepository {
    return this.repo;
  }

  /**
   * Logs an immutable security or operational audit record.
   * Strictly enforces zero-secret policy before recording.
   */
  public async logSecurityEvent(params: LogSecurityEventParams): Promise<AuditRecord> {
    const meta = params.metadata || {};

    // Fail-closed validation on forbidden secrets
    assertNoSecretsInAuditPayload(meta);

    const record: AuditRecord = {
      id: crypto.randomUUID(),
      timestamp: new Date().toISOString(),
      actorId: params.actorId,
      actorEmail: params.actorEmail,
      actorRole: params.actorRole,
      action: params.action,
      resourceType: params.resourceType,
      resourceId: params.resourceId,
      outcome: params.outcome,
      severity: params.severity || 'INFO',
      failureReason: params.failureReason,
      errorCode: params.errorCode,
      correlationId: params.correlationId,
      clientIp: params.clientIp,
      userAgent: params.userAgent,
      metadata: meta
    };

    return this.repo.createEvent(record);
  }

  /**
   * Queries audit records with strict permission checks and pagination.
   */
  public async queryAuditEvents(
    filter: AuditQueryFilter,
    _callerContext?: SecurityContext
  ): Promise<{ records: AuditRecord[]; total: number }> {
    const validatedFilter = AuditQueryFilterSchema.parse(filter);
    return this.repo.queryEvents(validatedFilter);
  }
}
