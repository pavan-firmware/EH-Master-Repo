/**
 * EH Home Product Domain Service
 *
 * Business logic layer orchestrating product catalog queries,
 * static definition imports, and variant resolutions.
 */
import { ProductRepository } from './product.repository';
import { ListProductsQuery, ProductDetail, ProductSummary, VariantDetail, ImportDefinitionOptions } from './product.schema';
import { MappedProductFamily } from './product.adapter';
export declare class ProductService {
    private repository;
    constructor(repository: ProductRepository);
    /**
     * Retrieves paginated product summaries with optional filtering.
     */
    listProducts(filters: ListProductsQuery): Promise<{
        items: ProductSummary[];
        total: number;
        limit: number;
        offset: number;
    }>;
    /**
     * Retrieves complete product detail including variants and capabilities.
     */
    getProduct(productId: string): Promise<ProductDetail | null>;
    /**
     * Retrieves single product variant details.
     */
    getVariant(variantId: string): Promise<VariantDetail | null>;
    /**
     * Retrieves list of all variants.
     */
    listVariants(filters?: {
        familyId?: string;
        productId?: string;
        limit?: number;
        offset?: number;
        databaseOnly?: boolean;
    }): Promise<{
        items: VariantDetail[];
        total: number;
    }>;
    /**
     * Lists available product families.
     */
    listFamilies(): Promise<MappedProductFamily[]>;
    /**
     * Explicit, deterministic, and idempotent static definition import.
     */
    importStaticDefinition(metadata: any, assets?: any, options?: ImportDefinitionOptions): Promise<{
        success: boolean;
        dryRun: boolean;
        productId: string;
        variantId: string;
        familyId: string;
    }>;
    /**
     * Seeds database / memory cache from all filesystem static definitions.
     */
    seedFromStaticDefinitions(options?: {
        dryRun?: boolean;
        baseDir?: string;
    }): Promise<{
        total: number;
        imported: number;
        dryRun: boolean;
    }>;
    createProduct(data: any): Promise<ProductDetail>;
    updateProduct(id: string, data: any): Promise<ProductDetail | null>;
    createVariant(data: any): Promise<VariantDetail>;
    updateVariant(id: string, data: any): Promise<VariantDetail | null>;
}
//# sourceMappingURL=product.service.d.ts.map