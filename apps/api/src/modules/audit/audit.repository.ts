import {
  AuditRecord,
  AuditRecordSchema,
  AuditQueryFilter,
  assertNoSecretsInAuditPayload
} from '@eh-home/contracts';
import { FastifyInstance } from 'fastify';

export interface IAuditRepository {
  createEvent(event: AuditRecord): Promise<AuditRecord>;
  queryEvents(filter: AuditQueryFilter): Promise<{ records: AuditRecord[]; total: number }>;
}

export class AuditRepository implements IAuditRepository {
  protected _db: any = null;
  private static memoryEvents: AuditRecord[] = [];
  private static sequenceCounter = 1;

  constructor(app?: FastifyInstance) {
    if (app && (app as any).db) {
      this._db = (app as any).db;
    }
  }

  public async createEvent(event: AuditRecord): Promise<AuditRecord> {
    // Assert zero secrets before storage
    assertNoSecretsInAuditPayload(event.metadata);

    const validated = AuditRecordSchema.parse(event);
    validated.sequenceNumber = AuditRepository.sequenceCounter++;

    AuditRepository.memoryEvents.push(validated);
    return validated;
  }

  public async queryEvents(filter: AuditQueryFilter): Promise<{ records: AuditRecord[]; total: number }> {
    let filtered = [...AuditRepository.memoryEvents];

    if (filter.actorId) {
      filtered = filtered.filter((e) => e.actorId === filter.actorId);
    }
    if (filter.action) {
      filtered = filtered.filter((e) => e.action === filter.action);
    }
    if (filter.resourceType) {
      filtered = filtered.filter((e) => e.resourceType === filter.resourceType);
    }
    if (filter.resourceId) {
      filtered = filtered.filter((e) => e.resourceId === filter.resourceId);
    }
    if (filter.outcome) {
      filtered = filtered.filter((e) => e.outcome === filter.outcome);
    }
    if (filter.severity) {
      filtered = filtered.filter((e) => e.severity === filter.severity);
    }
    if (filter.correlationId) {
      filtered = filtered.filter((e) => e.correlationId === filter.correlationId);
    }
    if (filter.startDate) {
      const startMs = new Date(filter.startDate).getTime();
      filtered = filtered.filter((e) => new Date(e.timestamp).getTime() >= startMs);
    }
    if (filter.endDate) {
      const endMs = new Date(filter.endDate).getTime();
      filtered = filtered.filter((e) => new Date(e.timestamp).getTime() <= endMs);
    }

    // Sort descending by timestamp / sequenceNumber
    filtered.sort((a, b) => (b.sequenceNumber || 0) - (a.sequenceNumber || 0));

    const total = filtered.length;
    const limit = filter.limit || 50;
    const offset = filter.offset || 0;
    const paginated = filtered.slice(offset, offset + limit);

    return { records: paginated, total };
  }
}
