/**
 * EH Home Product Repository
 *
 * Provides database persistence via @eh-home/db-schema and Drizzle ORM.
 * Supports fallback to loaded static definitions for test and disconnected environments.
 */
import { EhDatabase } from '@eh-home/db-schema';
import { CanonicalMappedProductDefinition, MappedProductFamily } from './product.adapter';
import { ListProductsQuery, ProductDetail, ProductSummary, VariantDetail } from './product.schema';
export declare class ProductRepository {
    private db?;
    private memoryCache;
    private initializedFromStatic;
    constructor(db?: EhDatabase);
    /**
     * Seeds memory cache from filesystem static definitions as fallback.
     */
    private ensureMemoryCache;
    /**
     * Lists products matching query criteria.
     */
    listProducts(filters: ListProductsQuery): Promise<{
        items: ProductSummary[];
        total: number;
    }>;
    /**
     * Retrieves single product by its primary ID.
     */
    getProductById(productId: string): Promise<ProductDetail | null>;
    /**
     * Retrieves single product variant by variant ID.
     */
    getVariantById(variantId: string): Promise<VariantDetail | null>;
    /**
     * Lists all available product families.
     */
    listProductFamilies(): Promise<MappedProductFamily[]>;
    private listFromDatabase;
    private getProductFromDatabase;
    private getVariantFromDatabase;
    private listFromMemory;
    private getProductFromMemory;
    private getVariantFromMemory;
    /**
     * Idempotently saves a canonical mapped definition into the database.
     */
    upsertDefinition(def: CanonicalMappedProductDefinition, dryRun?: boolean): Promise<{
        success: boolean;
        dryRun: boolean;
    }>;
    /**
     * Lists all product variants with optional filters.
     */
    listVariants(filters?: {
        familyId?: string;
        productId?: string;
        limit?: number;
        offset?: number;
    }): Promise<{
        items: VariantDetail[];
        total: number;
    }>;
    createProduct(data: {
        id?: string;
        productId?: string;
        familyId?: string;
        displayName?: string;
        name?: string;
        description?: string;
        status?: any;
    }): Promise<ProductDetail>;
    updateProduct(id: string, data: {
        displayName?: string;
        name?: string;
        description?: string;
        status?: any;
        familyId?: string;
    }): Promise<ProductDetail | null>;
    createVariant(data: any): Promise<VariantDetail>;
    updateVariant(id: string, data: any): Promise<VariantDetail | null>;
}
//# sourceMappingURL=product.repository.d.ts.map