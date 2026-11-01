import { AuditRecord, AuditQueryFilter } from '@eh-home/contracts';
import { FastifyInstance } from 'fastify';
export interface IAuditRepository {
    createEvent(event: AuditRecord): Promise<AuditRecord>;
    queryEvents(filter: AuditQueryFilter): Promise<{
        records: AuditRecord[];
        total: number;
    }>;
}
export declare class AuditRepository implements IAuditRepository {
    protected _db: any;
    private static memoryEvents;
    private static sequenceCounter;
    constructor(app?: FastifyInstance);
    createEvent(event: AuditRecord): Promise<AuditRecord>;
    queryEvents(filter: AuditQueryFilter): Promise<{
        records: AuditRecord[];
        total: number;
    }>;
}
//# sourceMappingURL=audit.repository.d.ts.map