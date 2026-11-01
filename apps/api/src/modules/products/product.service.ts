/**
 * EH Home Product Domain Service
 *
 * Business logic layer orchestrating product catalog queries,
 * static definition imports, and variant resolutions.
 */

import { ProductRepository } from './product.repository';
import {
  ListProductsQuery,
  ProductDetail,
  ProductSummary,
  VariantDetail,
  ImportDefinitionOptions,
} from './product.schema';
import {
  mapStaticDefinitionToCanonical,
  loadAllStaticProductDefinitions,
  MappedProductFamily,
} from './product.adapter';

export class ProductService {
  private repository: ProductRepository;

  constructor(repository: ProductRepository) {
    this.repository = repository;
  }

  /**
   * Retrieves paginated product summaries with optional filtering.
   */
  async listProducts(
    filters: ListProductsQuery
  ): Promise<{ items: ProductSummary[]; total: number; limit: number; offset: number }> {
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
  async getProduct(productId: string): Promise<ProductDetail | null> {
    return this.repository.getProductById(productId);
  }

  /**
   * Retrieves single product variant details.
   */
  async getVariant(variantId: string): Promise<VariantDetail | null> {
    return this.repository.getVariantById(variantId);
  }

  /**
   * Retrieves list of all variants.
   */
  async listVariants(filters: { familyId?: string; productId?: string; limit?: number; offset?: number } = {}): Promise<{ items: VariantDetail[]; total: number }> {
    return this.repository.listVariants(filters);
  }

  /**
   * Lists available product families.
   */
  async listFamilies(): Promise<MappedProductFamily[]> {
    return this.repository.listProductFamilies();
  }

  /**
   * Explicit, deterministic, and idempotent static definition import.
   */
  async importStaticDefinition(
    metadata: any,
    assets?: any,
    options: ImportDefinitionOptions = { dryRun: false, overwriteExisting: false }
  ): Promise<{
    success: boolean;
    dryRun: boolean;
    productId: string;
    variantId: string;
    familyId: string;
  }> {
    const canonical = mapStaticDefinitionToCanonical(metadata, assets);
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
  async seedFromStaticDefinitions(
    options: { dryRun?: boolean; baseDir?: string } = {}
  ): Promise<{ total: number; imported: number; dryRun: boolean }> {
    const definitions = loadAllStaticProductDefinitions(options.baseDir);
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

  async createProduct(data: any): Promise<ProductDetail> {
    return this.repository.createProduct(data);
  }

  async updateProduct(id: string, data: any): Promise<ProductDetail | null> {
    return this.repository.updateProduct(id, data);
  }

  async createVariant(data: any): Promise<VariantDetail> {
    return this.repository.createVariant(data);
  }

  async updateVariant(id: string, data: any): Promise<VariantDetail | null> {
    return this.repository.updateVariant(id, data);
  }
}

