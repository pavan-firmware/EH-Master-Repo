"use strict";
/**
 * EH Home Product Domain Service
 *
 * Business logic layer orchestrating product catalog queries,
 * static definition imports, and variant resolutions.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProductService = void 0;
const product_adapter_1 = require("./product.adapter");
class ProductService {
    repository;
    constructor(repository) {
        this.repository = repository;
    }
    /**
     * Retrieves paginated product summaries with optional filtering.
     */
    async listProducts(filters) {
        const result = await this.repository.listProducts(filters);
        return {
            items: result.items,
            total: result.total,
            limit: filters.limit,
            offset: filters.offset,
        };
    }
    /**
     * Retrieves complete product detail including variants and capabilities.
     */
    async getProduct(productId) {
        return this.repository.getProductById(productId);
    }
    /**
     * Retrieves single product variant details.
     */
    async getVariant(variantId) {
        return this.repository.getVariantById(variantId);
    }
    /**
     * Retrieves list of all variants.
     */
    async listVariants(filters = {}) {
        return this.repository.listVariants(filters);
    }
    /**
     * Lists available product families.
     */
    async listFamilies() {
        return this.repository.listProductFamilies();
    }
    /**
     * Explicit, deterministic, and idempotent static definition import.
     */
    async importStaticDefinition(metadata, assets, options = { dryRun: false, overwriteExisting: false }) {
        const canonical = (0, product_adapter_1.mapStaticDefinitionToCanonical)(metadata, assets);
        const result = await this.repository.upsertDefinition(canonical, options.dryRun);
        return {
            success: result.success,
            dryRun: result.dryRun,
            productId: canonical.product.id,
            variantId: canonical.variant.id,
            familyId: canonical.family.id,
        };
    }
    /**
     * Seeds database / memory cache from all filesystem static definitions.
     */
    async seedFromStaticDefinitions(options = {}) {
        const definitions = (0, product_adapter_1.loadAllStaticProductDefinitions)(options.baseDir);
        let count = 0;
        for (const def of definitions) {
            await this.repository.upsertDefinition(def, options.dryRun || false);
            count++;
        }
        return {
            total: definitions.length,
            imported: count,
            dryRun: options.dryRun || false,
        };
    }
    async createProduct(data) {
        return this.repository.createProduct(data);
    }
    async updateProduct(id, data) {
        return this.repository.updateProduct(id, data);
    }
    async createVariant(data) {
        return this.repository.createVariant(data);
    }
    async updateVariant(id, data) {
        return this.repository.updateVariant(id, data);
    }
}
exports.ProductService = ProductService;
//# sourceMappingURL=product.service.js.map