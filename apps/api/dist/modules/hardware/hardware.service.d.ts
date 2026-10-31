/**
 * EH Home Hardware & BOM Domain Service
 *
 * Implements business logic and lifecycle state machine for
 * Hardware Revisions, Bill of Materials (BOM), and Component Substitutions.
 */
import { HardwareRepository } from './hardware.repository';
import { BOMDetail, CreateBOMSpecificationBody, CreateHardwareRevisionBody, HardwareRevisionDetail, ListHardwareRevisionsQuery } from './hardware.schema';
import { HardwareRevisionStatus } from '@eh-home/contracts';
export declare class HardwareService {
    private repository;
    constructor(repository: HardwareRepository);
    /**
     * Lists hardware revisions matching query filters.
     */
    listHardwareRevisions(filters: ListHardwareRevisionsQuery): Promise<{
        items: HardwareRevisionDetail[];
        total: number;
        limit: number;
        offset: number;
    }>;
    /**
     * Retrieves single hardware revision by ID.
     */
    getHardwareRevision(id: string): Promise<HardwareRevisionDetail | null>;
    /**
     * Retrieves single hardware revision by product variant ID and revision code.
     */
    getHardwareRevisionByVariantAndCode(productVariantId: string, revisionCode: string): Promise<HardwareRevisionDetail | null>;
    /**
     * Creates a new hardware revision.
     */
    createHardwareRevision(data: CreateHardwareRevisionBody): Promise<HardwareRevisionDetail>;
    /**
     * Governs allowed lifecycle transitions for hardware revisions.
     */
    updateLifecycleStatus(id: string, newStatus: HardwareRevisionStatus, _reason?: string): Promise<HardwareRevisionDetail>;
    /**
     * Retrieves the Bill of Materials for a hardware revision.
     */
    getBOM(hardwareRevisionId: string): Promise<BOMDetail | null>;
    /**
     * Creates a new BOM specification with items for a hardware revision.
     */
    createBOM(data: CreateBOMSpecificationBody): Promise<BOMDetail>;
}
//# sourceMappingURL=hardware.service.d.ts.map