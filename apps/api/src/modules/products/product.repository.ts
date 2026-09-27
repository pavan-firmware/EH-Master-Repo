/**
 * EH Home Product Repository
 *
 * Provides database persistence via @eh-home/db-schema and Drizzle ORM.
 * Supports fallback to loaded static definitions for test and disconnected environments.
 */

import { eq, and } from 'drizzle-orm';
import {
  EhDatabase,
  products,
  productVariants,
  productFamilies,
  productImages,
  productCapabilities,
} from '@eh-home/db-schema';
import {
  CanonicalMappedProductDefinition,
  loadAllStaticProductDefinitions,
  MappedProduct,
  MappedProductFamily,
  MappedProductVariant,
} from './product.adapter';
import { ListProductsQuery, ProductAsset, ProductDetail, ProductSummary, VariantDetail } from './product.schema';

export class ProductRepository {
  private db?: EhDatabase;
  private memoryCache: Map<string, CanonicalMappedProductDefinition> = new Map();
  private initializedFromStatic = false;

  constructor(db?: EhDatabase) {
    this.db = db;
    this.ensureMemoryCache();
  }

  /**
   * Seeds memory cache from filesystem static definitions as fallback.
   */
  private ensureMemoryCache(): void {
    if (this.initializedFromStatic) return;
    try {
      const defs = loadAllStaticProductDefinitions();
      for (const def of defs) {
        this.memoryCache.set(def.variant.id, def);
      }
      this.initializedFromStatic = true;
    } catch {
      // Memory fallback load error ignored
    }
  }

  /**
   * Lists products matching query criteria.
   */
  async listProducts(filters: ListProductsQuery): Promise<{ items: ProductSummary[]; total: number }> {
    if (this.db) {
      try {
        return await this.listFromDatabase(filters);
      } catch (err) {
        // If DB table is empty or error occurs, fall back to memory cache
        return this.listFromMemory(filters);
      }
    }
    return this.listFromMemory(filters);
  }

  /**
   * Retrieves single product by its primary ID.
   */
  async getProductById(productId: string): Promise<ProductDetail | null> {
    if (this.db) {
      try {
        const fromDb = await this.getProductFromDatabase(productId);
        if (fromDb) return fromDb;
      } catch {
        // Fall back to memory
      }
    }
    return this.getProductFromMemory(productId);
  }

  /**
   * Retrieves single product variant by variant ID.
   */
  async getVariantById(variantId: string): Promise<VariantDetail | null> {
    if (this.db) {
      try {
        const fromDb = await this.getVariantFromDatabase(variantId);
        if (fromDb) return fromDb;
      } catch {
        // Fall back to memory
      }
    }
    return this.getVariantFromMemory(variantId);
  }

  /**
   * Lists all available product families.
   */
  async listProductFamilies(): Promise<MappedProductFamily[]> {
    if (this.db) {
      try {
        const dbFamilies = await this.db.select().from(productFamilies);
        if (dbFamilies.length > 0) {
          return dbFamilies.map((f) => ({
            id: f.id,
            slug: f.slug,
            displayName: f.displayName,
            description: f.description || '',
          }));
        }
      } catch {
        // Fall back to memory
      }
    }

    const familiesMap = new Map<string, MappedProductFamily>();
    for (const def of this.memoryCache.values()) {
      familiesMap.set(def.family.id, def.family);
    }
    return Array.from(familiesMap.values());
  }

  // ── DATABASE PERSISTENCE HELPERS ──────────────────────────────────────

  private async listFromDatabase(filters: ListProductsQuery): Promise<{ items: ProductSummary[]; total: number }> {
    if (!this.db) throw new Error('Database not configured');

    const conditions: any[] = [];
    if (filters.familyId) {
      conditions.push(eq(products.familyId, filters.familyId));
    }
    if (filters.status) {
      conditions.push(eq(products.status, filters.status));
    }

    const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

    const dbProducts = await this.db
      .select()
      .from(products)
      .where(whereClause)
      .limit(filters.limit)
      .offset(filters.offset);

    if (dbProducts.length === 0) {
      // If DB has no products seeded, allow fallback to memory
      return this.listFromMemory(filters);
    }

    const items: ProductSummary[] = [];

    for (const p of dbProducts) {
      const variants = await this.db
        .select()
        .from(productVariants)
        .where(eq(productVariants.productId, p.id));

      const allCapabilities = new Set<string>();
      const variantIds: string[] = [];
      let thumbnailUrl: string | null = null;

      for (const v of variants) {
        variantIds.push(v.id);
        if (Array.isArray(v.capabilities)) {
          v.capabilities.forEach((c) => allCapabilities.add(String(c)));
        }
      }

      // Check capability filter
      if (filters.capability && !allCapabilities.has(filters.capability)) {
        continue;
      }

      // Check connectivity filter
      if (filters.connectivity) {
        const hasConnectivity = variants.some((v: any) => {
          const conn = v.connectivityProfile;
          if (!conn) return false;
          if (filters.connectivity === 'wifi') return !!conn.supportsWifi;
          if (filters.connectivity === 'ble') return !!conn.supportsBle;
          if (filters.connectivity === 'thread') return !!conn.supportsThread;
          if (filters.connectivity === 'matter') return !!conn.supportsMatter;
          return false;
        });
        if (!hasConnectivity) continue;
      }

      // Look up hero/thumbnail image if available
      if (variantIds.length > 0) {
        const firstVariantId = variantIds[0];
        if (firstVariantId) {
          const firstVariantImg = await this.db
            .select()
            .from(productImages)
            .where(eq(productImages.productVariantId, firstVariantId))
            .limit(1);
          if (firstVariantImg.length > 0 && firstVariantImg[0]) {
            thumbnailUrl = firstVariantImg[0].url;
          }
        }
      }

      items.push({
        id: p.id,
        familyId: p.familyId,
        displayName: p.displayName,
        description: p.description,
        status: p.status as any,
        variantCount: variants.length,
        variantIds,
        capabilities: Array.from(allCapabilities),
        thumbnailUrl,
        createdAt: p.createdAt.toISOString(),
        updatedAt: p.updatedAt.toISOString(),
      });
    }

    return { items, total: items.length };
  }

  private async getProductFromDatabase(productId: string): Promise<ProductDetail | null> {
    if (!this.db) return null;

    const pResult = await this.db.select().from(products).where(eq(products.id, productId)).limit(1);
    const p = pResult[0];
    if (!p) return null;

    const variants = await this.db
      .select()
      .from(productVariants)
      .where(eq(productVariants.productId, p.id));

    const allCapabilities = new Set<string>();
    const variantDetails: VariantDetail[] = [];

    for (const v of variants) {
      if (Array.isArray(v.capabilities)) {
        v.capabilities.forEach((c) => allCapabilities.add(String(c)));
      }

      const imgRows = await this.db
        .select()
        .from(productImages)
        .where(eq(productImages.productVariantId, v.id));

      const assets: ProductAsset[] = imgRows.map((img) => ({
        assetId: img.id,
        productVariantId: img.productVariantId,
        kind: img.kind as any,
        purpose: img.kind === 'thumbnail' ? 'catalog' : 'marketing',
        url: img.url,
        sortOrder: img.sortOrder,
        isPublished: true,
      }));

      variantDetails.push({
        variantId: v.id,
        productId: v.productId,
        variantSlug: v.variantSlug,
        displayName: v.displayName,
        channelCount: v.channelCount,
        channels: (v.channels as any[]) || [],
        hardwareProfile: v.hardwareProfile as any,
        connectivityProfile: v.connectivityProfile as any,
        capabilities: (v.capabilities as string[]) || [],
        electricalSpecifications: (v.electricalSpecifications as Record<string, any>) || {},
        firmwareFamily: v.firmwareFamily,
        supportedHardwareRevisions: (v.supportedHardwareRevisions as string[]) || [],
        assets,
        createdAt: v.createdAt.toISOString(),
      });
    }

    return {
      id: p.id,
      familyId: p.familyId,
      displayName: p.displayName,
      description: p.description,
      schemaVersion: p.schemaVersion,
      status: p.status as any,
      variants: variantDetails,
      capabilities: Array.from(allCapabilities),
      createdAt: p.createdAt.toISOString(),
      updatedAt: p.updatedAt.toISOString(),
    };
  }

  private async getVariantFromDatabase(variantId: string): Promise<VariantDetail | null> {
    if (!this.db) return null;

    const vResult = await this.db
      .select()
      .from(productVariants)
      .where(eq(productVariants.id, variantId))
      .limit(1);

    const v = vResult[0];
    if (!v) return null;

    const imgRows = await this.db
      .select()
      .from(productImages)
      .where(eq(productImages.productVariantId, v.id));

    const assets: ProductAsset[] = imgRows.map((img) => ({
      assetId: img.id,
      productVariantId: img.productVariantId,
      kind: img.kind as any,
      purpose: img.kind === 'thumbnail' ? 'catalog' : 'marketing',
      url: img.url,
      sortOrder: img.sortOrder,
      isPublished: true,
    }));

    return {
      variantId: v.id,
      productId: v.productId,
      variantSlug: v.variantSlug,
      displayName: v.displayName,
      channelCount: v.channelCount,
      channels: (v.channels as any[]) || [],
      hardwareProfile: v.hardwareProfile as any,
      connectivityProfile: v.connectivityProfile as any,
      capabilities: (v.capabilities as string[]) || [],
      electricalSpecifications: (v.electricalSpecifications as Record<string, any>) || {},
      firmwareFamily: v.firmwareFamily,
      supportedHardwareRevisions: (v.supportedHardwareRevisions as string[]) || [],
      assets,
      createdAt: v.createdAt.toISOString(),
    };
  }

  // ── IN-MEMORY / STATIC DEFINITION CACHE HELPERS ───────────────────────

  private listFromMemory(filters: ListProductsQuery): { items: ProductSummary[]; total: number } {
    const productsMap = new Map<string, { product: MappedProduct; variants: MappedProductVariant[]; assets: ProductAsset[] }>();

    for (const def of this.memoryCache.values()) {
      let entry = productsMap.get(def.product.id);
      if (!entry) {
        entry = { product: def.product, variants: [], assets: [] };
        productsMap.set(def.product.id, entry);
      }
      entry.variants.push(def.variant);
      entry.assets.push(...def.assets);
    }

    let items: ProductSummary[] = [];

    for (const [prodId, data] of productsMap.entries()) {
      if (filters.familyId && data.product.familyId !== filters.familyId) continue;
      if (filters.status && data.product.status !== filters.status) continue;

      const allCapabilities = new Set<string>();
      const variantIds: string[] = [];

      for (const v of data.variants) {
        variantIds.push(v.id);
        v.capabilities.forEach((c) => allCapabilities.add(c));
      }

      if (filters.capability && !allCapabilities.has(filters.capability)) {
        continue;
      }

      if (filters.connectivity) {
        const matchesConnectivity = data.variants.some((v) => {
          const conn = v.connectivityProfile;
          if (!conn) return false;
          if (filters.connectivity === 'wifi') return !!conn.supportsWifi;
          if (filters.connectivity === 'ble') return !!conn.supportsBle;
          if (filters.connectivity === 'thread') return !!conn.supportsThread;
          if (filters.connectivity === 'matter') return !!conn.supportsMatter;
          return false;
        });
        if (!matchesConnectivity) continue;
      }

      const thumb = data.assets.find((a) => a.kind === 'thumbnail' || a.kind === 'hero')?.url || null;

      items.push({
        id: prodId,
        familyId: data.product.familyId,
        displayName: data.product.displayName,
        description: data.product.description,
        status: data.product.status,
        variantCount: data.variants.length,
        variantIds,
        capabilities: Array.from(allCapabilities),
        thumbnailUrl: thumb,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });
    }

    const total = items.length;
    items = items.slice(filters.offset, filters.offset + filters.limit);
    return { items, total };
  }

  private getProductFromMemory(productId: string): ProductDetail | null {
    const matchingDefs: CanonicalMappedProductDefinition[] = [];
    for (const def of this.memoryCache.values()) {
      if (def.product.id === productId) {
        matchingDefs.push(def);
      }
    }

    const firstDef = matchingDefs[0];
    if (!firstDef) return null;

    const base = firstDef.product;
    const allCapabilities = new Set<string>();
    const variants: VariantDetail[] = [];

    for (const def of matchingDefs) {
      def.variant.capabilities.forEach((c) => allCapabilities.add(c));
      variants.push({
        variantId: def.variant.id,
        productId: def.variant.productId,
        variantSlug: def.variant.variantSlug,
        displayName: def.variant.displayName,
        channelCount: def.variant.channelCount,
        channels: def.variant.channels,
        hardwareProfile: def.variant.hardwareProfile,
        connectivityProfile: def.variant.connectivityProfile,
        capabilities: def.variant.capabilities,
        electricalSpecifications: def.variant.electricalSpecifications,
        firmwareFamily: def.variant.firmwareFamily,
        supportedHardwareRevisions: def.variant.supportedHardwareRevisions,
        assets: def.assets,
        createdAt: new Date().toISOString(),
      });
    }

    return {
      id: base.id,
      familyId: base.familyId,
      displayName: base.displayName,
      description: base.description,
      schemaVersion: base.schemaVersion,
      status: base.status,
      variants,
      capabilities: Array.from(allCapabilities),
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
  }

  private getVariantFromMemory(variantId: string): VariantDetail | null {
    const def = this.memoryCache.get(variantId);
    if (!def) return null;

    return {
      variantId: def.variant.id,
      productId: def.variant.productId,
      variantSlug: def.variant.variantSlug,
      displayName: def.variant.displayName,
      channelCount: def.variant.channelCount,
      channels: def.variant.channels,
      hardwareProfile: def.variant.hardwareProfile,
      connectivityProfile: def.variant.connectivityProfile,
      capabilities: def.variant.capabilities,
      electricalSpecifications: def.variant.electricalSpecifications,
      firmwareFamily: def.variant.firmwareFamily,
      supportedHardwareRevisions: def.variant.supportedHardwareRevisions,
      assets: def.assets,
      createdAt: new Date().toISOString(),
    };
  }

  // ── UPSERT / IMPORT TRANSACTIONS ──────────────────────────────────────

  /**
   * Idempotently saves a canonical mapped definition into the database.
   */
  async upsertDefinition(def: CanonicalMappedProductDefinition, dryRun = false): Promise<{ success: boolean; dryRun: boolean }> {
    if (dryRun || !this.db) {
      this.memoryCache.set(def.variant.id, def);
      return { success: true, dryRun };
    }

    const { family, product, variant, assets, capabilities } = def;

    // Execute in transaction for consistency
    await this.db.transaction(async (tx) => {
      // 1. Family
      await tx
        .insert(productFamilies)
        .values({
          id: family.id,
          slug: family.slug,
          displayName: family.displayName,
          description: family.description,
        })
        .onConflictDoNothing();

      // 2. Product
      await tx
        .insert(products)
        .values({
          id: product.id,
          familyId: product.familyId,
          displayName: product.displayName,
          description: product.description,
          schemaVersion: product.schemaVersion,
          status: product.status,
        })
        .onConflictDoUpdate({
          target: products.id,
          set: {
            displayName: product.displayName,
            description: product.description,
            updatedAt: new Date(),
          },
        });

      // 3. Variant
      await tx
        .insert(productVariants)
        .values({
          id: variant.id,
          productId: variant.productId,
          variantSlug: variant.variantSlug,
          displayName: variant.displayName,
          channelCount: variant.channelCount,
          channels: variant.channels,
          hardwareProfile: variant.hardwareProfile,
          connectivityProfile: variant.connectivityProfile,
          capabilities: variant.capabilities,
          electricalSpecifications: variant.electricalSpecifications,
          firmwareFamily: variant.firmwareFamily,
          supportedHardwareRevisions: variant.supportedHardwareRevisions,
        })
        .onConflictDoUpdate({
          target: productVariants.id,
          set: {
            displayName: variant.displayName,
            channels: variant.channels,
            hardwareProfile: variant.hardwareProfile,
            connectivityProfile: variant.connectivityProfile,
            capabilities: variant.capabilities,
            electricalSpecifications: variant.electricalSpecifications,
            firmwareFamily: variant.firmwareFamily,
            supportedHardwareRevisions: variant.supportedHardwareRevisions,
          },
        });

      // 4. Images/Assets
      for (const asset of assets) {
        await tx
          .insert(productImages)
          .values({
            id: asset.assetId,
            productVariantId: asset.productVariantId,
            kind: asset.kind,
            url: asset.url,
            sortOrder: asset.sortOrder,
          })
          .onConflictDoUpdate({
            target: productImages.id,
            set: {
              url: asset.url,
              sortOrder: asset.sortOrder,
            },
          });
      }

      // 5. Capabilities
      for (const cap of capabilities) {
        await tx
          .insert(productCapabilities)
          .values({
            productVariantId: cap.productVariantId,
            capabilityId: cap.capabilityId,
            channelIndex: cap.channelIndex,
            config: cap.config,
          })
          .onConflictDoNothing();
      }
    });

    this.memoryCache.set(def.variant.id, def);
    return { success: true, dryRun: false };
  }
}
