/**
 * EH Home Hardware & BOM Repository
 *
 * Provides database persistence via @eh-home/db-schema and Drizzle ORM.
 * Supports fallback to memory cache for testing and disconnected environments.
 */
import { EhDatabase } from '@eh-home/db-schema';
import { BOMDetail, CreateBOMSpecificationBody, CreateHardwareRevisionBody, HardwareRevisionDetail, ListHardwareRevisionsQuery } from './hardware.schema';
import { HardwareRevisionStatus } from '@eh-home/contracts';
export declare class HardwareRepository {
    private db?;
    private memoryRevisions;
    private memoryBoms;
    private initializedMemory;
    constructor(db?: EhDatabase);
    /**
     * Seeds memory cache with baseline hardware revisions for the canonical products.
     */
    private ensureMemoryCache;
    /**
     * Lists hardware revisions with optional filtering.
     */
    listHardwareRevisions(filters: ListHardwareRevisionsQuery): Promise<{
        items: HardwareRevisionDetail[];
        total: number;
    }>;
    /**
     * Retrieves single hardware revision by ID.
     */
    getHardwareRevisionById(id: string): Promise<HardwareRevisionDetail | null>;
    /**
     * Retrieves single hardware revision by variant ID and revision code.
     */
    getHardwareRevisionByVariantAndCode(productVariantId: string, revisionCode: string): Promise<HardwareRevisionDetail | null>;
    /**
     * Creates a new hardware revision record.
     */
    createHardwareRevision(data: CreateHardwareRevisionBody): Promise<HardwareRevisionDetail>;
    /**
     * Updates lifecycle status for an existing hardware revision.
     */
    updateHardwareRevisionStatus(id: string, status: HardwareRevisionStatus): Promise<HardwareRevisionDetail | null>;
    /**
     * Retrieves BOM specification for a given hardware revision ID.
     */
    getBOMByHardwareRevisionId(hardwareRevisionId: string): Promise<BOMDetail | null>;
    /**
     * Creates a new BOM specification with items.
     */
    createBOM(data: CreateBOMSpecificationBody): Promise<BOMDetail>;
}
//# sourceMappingURL=hardware.repository.d.ts.map