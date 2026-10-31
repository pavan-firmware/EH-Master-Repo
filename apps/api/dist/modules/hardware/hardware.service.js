"use strict";
/**
 * EH Home Hardware & BOM Domain Service
 *
 * Implements business logic and lifecycle state machine for
 * Hardware Revisions, Bill of Materials (BOM), and Component Substitutions.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.HardwareService = void 0;
class HardwareService {
    repository;
    constructor(repository) {
        this.repository = repository;
    }
    /**
     * Lists hardware revisions matching query filters.
     */
    async listHardwareRevisions(filters) {
        const result = await this.repository.listHardwareRevisions(filters);
        return {
            items: result.items,
            total: result.total,
            limit: filters.limit,
            offset: filters.offset,
        };
    }
    /**
     * Retrieves single hardware revision by ID.
     */
    async getHardwareRevision(id) {
        return this.repository.getHardwareRevisionById(id);
    }
    /**
     * Retrieves single hardware revision by product variant ID and revision code.
     */
    async getHardwareRevisionByVariantAndCode(productVariantId, revisionCode) {
        return this.repository.getHardwareRevisionByVariantAndCode(productVariantId, revisionCode);
    }
    /**
     * Creates a new hardware revision.
     */
    async createHardwareRevision(data) {
        // Check for duplicate revision code within the same variant
        const existing = await this.repository.getHardwareRevisionByVariantAndCode(data.productVariantId, data.revisionCode);
        if (existing) {
            throw new Error(`Hardware revision '${data.revisionCode}' already exists for product variant '${data.productVariantId}'`);
        }
        return this.repository.createHardwareRevision(data);
    }
    /**
     * Governs allowed lifecycle transitions for hardware revisions.
     */
    async updateLifecycleStatus(id, newStatus, _reason) {
        const revision = await this.repository.getHardwareRevisionById(id);
        if (!revision) {
            throw new Error(`Hardware revision '${id}' not found`);
        }
        const currentStatus = revision.lifecycleStatus;
        const allowedTransitions = {
            DRAFT: ['VALIDATION', 'RETIRED', 'DEPRECATED'],
            VALIDATION: ['APPROVED', 'DRAFT', 'RETIRED'],
            APPROVED: ['ACTIVE', 'DEPRECATED', 'RETIRED'],
            ACTIVE: ['DEPRECATED', 'RETIRED'],
            DEPRECATED: ['RETIRED', 'ACTIVE'],
            RETIRED: [],
            PROTOTYPE: ['VALIDATION', 'ACTIVE', 'DEPRECATED', 'RETIRED'],
            OBSOLETE: [],
        };
        const validNextStates = allowedTransitions[currentStatus] || [];
        if (!validNextStates.includes(newStatus) && currentStatus !== newStatus) {
            throw new Error(`Invalid lifecycle transition from '${currentStatus}' to '${newStatus}'. Allowed: ${validNextStates.join(', ')}`);
        }
        const updated = await this.repository.updateHardwareRevisionStatus(id, newStatus);
        if (!updated) {
            throw new Error(`Failed to update hardware revision status for '${id}'`);
        }
        return updated;
    }
    /**
     * Retrieves the Bill of Materials for a hardware revision.
     */
    async getBOM(hardwareRevisionId) {
        return this.repository.getBOMByHardwareRevisionId(hardwareRevisionId);
    }
    /**
     * Creates a new BOM specification with items for a hardware revision.
     */
    async createBOM(data) {
        const revision = await this.repository.getHardwareRevisionById(data.hardwareRevisionId);
        if (!revision) {
            throw new Error(`Hardware revision '${data.hardwareRevisionId}' does not exist`);
        }
        // Validate unique reference designators and positive quantities
        const seenDesignators = new Set();
        for (const item of data.items) {
            if (item.quantity <= 0) {
                throw new Error(`Item ${item.referenceDesignator} has invalid quantity (${item.quantity}). Must be > 0.`);
            }
            if (seenDesignators.has(item.referenceDesignator)) {
                throw new Error(`Duplicate reference designator '${item.referenceDesignator}' found in BOM`);
            }
            seenDesignators.add(item.referenceDesignator);
        }
        return this.repository.createBOM(data);
    }
}
exports.HardwareService = HardwareService;
//# sourceMappingURL=hardware.service.js.map