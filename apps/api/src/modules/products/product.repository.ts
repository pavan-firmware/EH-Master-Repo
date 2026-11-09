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

// The original product_images table was created by the frozen legacy
// migration and stores uppercase media kinds. The API contract uses the
// descriptive lowercase names. Keep this compatibility boundary here so new
// uploads work against existing databases without weakening the DB constraint.
const API_TO_DB_ASSET_KIND: Record<string, string> = {
  hero: 'HERO',
  front: 'FRONT',
  rear: 'BACK',
  installed: 'INSTALL',
  packaging: 'INSTALL',
  technicalDiagram: 'WIRING',
  diagram: 'WIRING',
  render: 'HERO',
  icon: 'THUMB',
  thumbnail: 'THUMB',
};

const DB_TO_API_ASSET_KIND: Record<string, ProductAsset['kind']> = {
  HERO: 'hero',
  FRONT: 'front',
  BACK: 'rear',
  INSTALL: 'installed',
  WIRING: 'technicalDiagram',
  THUMB: 'thumbnail',
};

function databaseAssetKind(kind: string): string {
  return API_TO_DB_ASSET_KIND[kind] || kind.toUpperCase();
}

function apiAssetKind(kind: string): ProductAsset['kind'] {
  return DB_TO_API_ASSET_KIND[kind] || (kind as ProductAsset['kind']);
}

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
        kind: apiAssetKind(img.kind),
        purpose: apiAssetKind(img.kind) === 'thumbnail' ? 'catalog' : 'marketing',
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
      kind: apiAssetKind(img.kind),
      purpose: apiAssetKind(img.kind) === 'thumbnail' ? 'catalog' : 'marketing',
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
            kind: databaseAssetKind(asset.kind),
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

  /**
   * Lists all product variants with optional filters.
   */
  async listVariants(filters: { familyId?: string; productId?: string; limit?: number; offset?: number; databaseOnly?: boolean } = {}): Promise<{ items: VariantDetail[]; total: number }> {
    if (filters.databaseOnly && !this.db) return { items: [], total: 0 };
    if (this.db) {
      try {
        const query = this.db.select().from(productVariants);
        let rows = await (filters.productId ? query.where(eq(productVariants.productId, filters.productId)) : query);
        if (filters.familyId) {
          const families = await this.db.select().from(productFamilies);
          const family = families.find((f) => f.id === filters.familyId || f.slug === filters.familyId || f.id.replace(/_/g, '-') === filters.familyId);
          if (family) {
            const familyProducts = await this.db.select().from(products).where(eq(products.familyId, family.id));
            const productIds = new Set(familyProducts.map((product) => product.id));
            rows = rows.filter((row) => productIds.has(row.productId));
          } else {
            rows = [];
          }
        }
        if (rows.length > 0) {
          const items: VariantDetail[] = [];
          for (const v of rows) {
            const imgRows = await this.db.select().from(productImages).where(eq(productImages.productVariantId, v.id));
            items.push({
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
              assets: imgRows.map((img) => ({ assetId: img.id, productVariantId: img.productVariantId, kind: apiAssetKind(img.kind), purpose: apiAssetKind(img.kind) === 'thumbnail' ? 'catalog' : 'marketing', url: img.url, sortOrder: img.sortOrder, isPublished: true })),
              createdAt: v.createdAt.toISOString(),
            });
          }
          return { items, total: items.length };
        }
      } catch {
        if (filters.databaseOnly) return { items: [], total: 0 };
        // Fall back to memory
      }
    }

    if (filters.databaseOnly) return { items: [], total: 0 };

    const items: VariantDetail[] = [];
    for (const def of this.memoryCache.values()) {
      if (filters.productId && def.product.id !== filters.productId) continue;
      if (filters.familyId && def.family.id !== filters.familyId && def.family.slug !== filters.familyId) continue;
      items.push({
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
    return { items, total: items.length };
  }

  async createProduct(data: { id?: string; productId?: string; familyId?: string; displayName?: string; name?: string; description?: string; status?: any }): Promise<ProductDetail> {
    const now = new Date();
    const id = data.id || data.productId || (data.displayName || data.name ? (data.displayName || data.name)!.toLowerCase().replace(/[^a-z0-9]+/g, '-') : `prod_${Date.now()}`);
    const inputFamily = data.familyId || 'smart-switch';
    const displayName = data.displayName || data.name || id;
    const description = data.description || null;
    const status = data.status || 'PUBLISHED';

    let resolvedFamilyId = inputFamily;

    if (this.db) {
      try {
        const families = await this.db.select().from(productFamilies);
        const match = families.find((f) => f.id === inputFamily || f.slug === inputFamily);
        if (match) {
          resolvedFamilyId = match.id;
        } else {
          // Provision family safely
          const famSlug = inputFamily.toLowerCase().replace(/[^a-z0-9]+/g, '-');
          const famId = inputFamily.toLowerCase().replace(/[^a-z0-9]+/g, '_');
          try {
            await this.db
              .insert(productFamilies)
              .values({
                id: famId,
                slug: famSlug,
                displayName: inputFamily.replace(/[-_]/g, ' ').replace(/\b\w/g, (c: string) => c.toUpperCase()),
                description: `Product Family: ${inputFamily}`,
                createdAt: now,
              })
              .onConflictDoNothing();
          } catch {
            // Ignored
          }
          resolvedFamilyId = famId;
        }
      } catch {
        // Fallback
      }

      try {
        await this.db
          .insert(products)
          .values({
            id,
            familyId: resolvedFamilyId,
            displayName,
            description,
            status,
            createdAt: now,
            updatedAt: now,
          })
          .onConflictDoUpdate({
            target: products.id,
            set: {
              displayName,
              description,
              status,
              updatedAt: now,
            },
          });
        const detail = await this.getProductById(id);
        if (detail) return detail;
      } catch {
        // Fall back to memory return
      }
    }

    return {
      id,
      familyId: resolvedFamilyId,
      displayName,
      description,
      schemaVersion: 1,
      status,
      variants: [],
      capabilities: [],
      createdAt: now.toISOString(),
      updatedAt: now.toISOString(),
    };
  }

  async updateProduct(id: string, data: { displayName?: string; name?: string; description?: string; status?: any; familyId?: string }): Promise<ProductDetail | null> {
    const now = new Date();
    const updateFields: Record<string, any> = { updatedAt: now };
    if (data.displayName || data.name) updateFields.displayName = data.displayName || data.name;
    if (data.description !== undefined) updateFields.description = data.description;
    if (data.status) updateFields.status = data.status;
    if (data.familyId) updateFields.familyId = data.familyId;

    if (this.db) {
      try {
        await this.db
          .update(products)
          .set(updateFields)
          .where(eq(products.id, id));
        return await this.getProductById(id);
      } catch {
        // Fall back to memory
      }
    }
    return this.getProductById(id);
  }

  async createVariant(data: any): Promise<VariantDetail> {
    const now = new Date();
    const id = data.id || data.variantId || data.variantSlug || (data.name ? data.name.toLowerCase().replace(/[^a-z0-9]+/g, '-') : `var_${Date.now()}`);
    const variantSlug = data.variantSlug || data.variantId || id;
    const displayName = data.displayName || data.name || variantSlug;
    
    // Determine or provision parent productId
    let productId = data.productId;
    if (!productId) {
      if (variantSlug.includes('switch')) productId = 'eh-smart-switch';
      else if (variantSlug.includes('socket')) productId = 'eh-smart-socket';
      else if (variantSlug.includes('fan')) productId = 'eh-smart-fan';
      else if (variantSlug.includes('light')) productId = 'eh-smart-light';
      else if (variantSlug.includes('hub')) productId = 'eh-smart-hub';
      else if (variantSlug.includes('sensor')) productId = 'eh-sensor-node';
      else productId = 'eh-smart-switch';
    }

    const channelCount = Number(data.channelCount) || 1;
    const firmwareFamily = data.firmwareFamily || (productId.includes('socket') ? 'esp32c6-socket-platform' : productId.includes('fan') ? 'esp32c6-fan-platform' : productId.includes('light') ? 'esp32c6-light-platform' : productId.includes('hub') ? 'esp32s3-hub-platform' : productId.includes('sensor') ? 'esp32c6-sensor-platform' : 'esp32c6-switch-platform');
    const supportedHardwareRevisions = Array.isArray(data.supportedHardwareRevisions) && data.supportedHardwareRevisions.length > 0
      ? data.supportedHardwareRevisions
      : ['HW_1_0', 'HW_1_1'];

    const channels = data.channels || Array.from({ length: channelCount }, (_, i) => ({
      channelIndex: i + 1,
      defaultLabel: `Channel ${i + 1}`,
      capabilities: ['switch', 'relay', 'local_switch', 'energy', 'ota'],
    }));

    const hardwareProfile = data.hardwareProfile || {
      schemaVersion: 1,
      mcuFamily: (data.targetMcu || 'ESP32-C6').toLowerCase(),
      flashSizeBytes: 4194304,
      psramSizeBytes: null,
      hasEnergyMetering: true,
      energyMeterChip: 'BL0942',
      maxRelayAmpsPerChannel: 10.0,
      maxTotalAmps: 16.0,
      gpioMap: {},
    };

    const connectivityProfile = data.connectivityProfile || {
      schemaVersion: 1,
      supportsWifi: true,
      wifiStandards: ['802.11b', '802.11g', '802.11n', '802.11ax'],
      supportsBle: true,
      bleVersion: '5.0',
      supportsThread: false,
      threadVersion: null,
      supportsMatter: false,
      matterDeviceType: null,
    };

    const capabilities = Array.isArray(data.capabilities) && data.capabilities.length > 0
      ? data.capabilities
      : ['switch', 'relay', 'local_switch', 'energy', 'voltage', 'current', 'power', 'ota', 'automation'];

    const electricalSpecifications = data.electricalSpecifications || {
      voltageRange: '90V - 250V AC',
      frequencyHz: '50/60Hz',
      maxCurrentPerChannelAmps: 10.0,
      maxTotalCurrentAmps: 16.0,
    };

    if (this.db) {
      // Ensure parent product exists in DB before inserting variant
      try {
        await this.createProduct({
          id: productId,
          familyId: productId.replace(/^eh-/, '').replace(/-/g, '_'),
          displayName: productId.replace(/-/g, ' ').replace(/\b\w/g, (c: string) => c.toUpperCase()),
          status: 'PUBLISHED',
        });
      } catch {
        // Ignored
      }

      try {
        await this.db
          .insert(productVariants)
          .values({
            id,
            productId,
            variantSlug,
            displayName,
            channelCount,
            channels,
            hardwareProfile,
            connectivityProfile,
            capabilities,
            electricalSpecifications,
            firmwareFamily,
            supportedHardwareRevisions,
            createdAt: now,
          })
          .onConflictDoUpdate({
            target: productVariants.id,
            set: {
              displayName,
              channelCount,
              channels,
              hardwareProfile,
              connectivityProfile,
              capabilities,
              electricalSpecifications,
              firmwareFamily,
              supportedHardwareRevisions,
            },
          });
        const detail = await this.getVariantById(id);
        if (detail) return detail;
      } catch {
        // Fallback to memory
      }
    }

    // Sync memory cache
    const mockDef: CanonicalMappedProductDefinition = {
      product: {
        id: productId,
        familyId: productId.replace(/^eh-/, '').replace(/-/g, '_'),
        displayName: productId.replace(/-/g, ' ').replace(/\b\w/g, (c: string) => c.toUpperCase()),
        description: `Product platform for ${productId}`,
        schemaVersion: 1,
        status: 'PUBLISHED',
      },
      family: {
        id: productId.replace(/^eh-/, '').replace(/-/g, '_'),
        slug: productId.replace(/^eh-/, '').replace(/_/g, '-'),
        displayName: productId.replace(/^eh-/, '').replace(/[-_]/g, ' ').replace(/\b\w/g, (c: string) => c.toUpperCase()),
        description: `Family for ${productId}`,
      },
      variant: {
        id,
        productId,
        variantSlug,
        displayName,
        channelCount,
        channels,
        hardwareProfile: hardwareProfile as any,
        connectivityProfile: connectivityProfile as any,
        capabilities,
        electricalSpecifications,
        firmwareFamily,
        supportedHardwareRevisions,
      },
      assets: [],
      capabilities: capabilities.map((c: string) => ({
        productVariantId: id,
        capabilityId: c,
        config: {},
      })),
    };
    this.memoryCache.set(id, mockDef);

    return {
      variantId: id,
      productId,
      variantSlug,
      displayName,
      channelCount,
      channels,
      hardwareProfile: hardwareProfile as any,
      connectivityProfile: connectivityProfile as any,
      capabilities,
      electricalSpecifications,
      firmwareFamily,
      supportedHardwareRevisions,
      assets: [],
      createdAt: now.toISOString(),
    };
  }

  async updateVariant(id: string, data: any): Promise<VariantDetail | null> {
    const updateFields: Record<string, any> = {};
    if (data.displayName || data.name) updateFields.displayName = data.displayName || data.name;
    if (data.channelCount !== undefined) updateFields.channelCount = Number(data.channelCount);
    if (data.channels) updateFields.channels = data.channels;
    if (data.hardwareProfile) updateFields.hardwareProfile = data.hardwareProfile;
    if (data.connectivityProfile) updateFields.connectivityProfile = data.connectivityProfile;
    if (data.capabilities) updateFields.capabilities = data.capabilities;
    if (data.electricalSpecifications) updateFields.electricalSpecifications = data.electricalSpecifications;
    if (data.firmwareFamily) updateFields.firmwareFamily = data.firmwareFamily;
    if (data.supportedHardwareRevisions) updateFields.supportedHardwareRevisions = data.supportedHardwareRevisions;
    if (data.variantSlug) updateFields.variantSlug = data.variantSlug;

    if (this.db) {
      try {
        if (Object.keys(updateFields).length > 0) {
          await this.db
            .update(productVariants)
            .set(updateFields)
            .where(eq(productVariants.id, id));
        }
        const updated = await this.getVariantById(id);
        if (updated) return updated;
      } catch {
        // Fall back to memory
      }
    }

    const def = this.memoryCache.get(id);
    if (def) {
      if (updateFields.displayName) def.variant.displayName = updateFields.displayName;
      if (updateFields.channelCount) def.variant.channelCount = updateFields.channelCount;
      if (updateFields.firmwareFamily) def.variant.firmwareFamily = updateFields.firmwareFamily;
      if (updateFields.hardwareProfile) def.variant.hardwareProfile = updateFields.hardwareProfile;
      if (updateFields.connectivityProfile) def.variant.connectivityProfile = updateFields.connectivityProfile;
      if (updateFields.channels) def.variant.channels = updateFields.channels;
      if (updateFields.electricalSpecifications) def.variant.electricalSpecifications = updateFields.electricalSpecifications;
      this.memoryCache.set(id, def);
      return this.getVariantFromMemory(id);
    }
    return this.getVariantById(id);
  }

  async createVariantAsset(asset: { id: string; productVariantId: string; kind: string; url: string; sortOrder?: number }): Promise<ProductAsset> {
    if (this.db) {
      // One active presentation asset per kind keeps consumer resolution
      // deterministic (a newly approved hero replaces the previous hero).
      const dbKind = databaseAssetKind(asset.kind);
      await this.db.delete(productImages).where(and(eq(productImages.productVariantId, asset.productVariantId), eq(productImages.kind, dbKind)));
      await this.db.insert(productImages).values({
        id: asset.id,
        productVariantId: asset.productVariantId,
        kind: dbKind,
        url: asset.url,
        sortOrder: asset.sortOrder || 0,
      });
    }
    const existing = this.memoryCache.get(asset.productVariantId);
    if (existing) {
      existing.assets = existing.assets.filter((entry) => entry.kind !== asset.kind);
      existing.assets.push({ assetId: asset.id, productVariantId: asset.productVariantId, kind: asset.kind as any, purpose: asset.kind === 'thumbnail' ? 'catalog' : 'marketing', url: asset.url, sortOrder: asset.sortOrder || 0, isPublished: true });
    }
    return { assetId: asset.id, productVariantId: asset.productVariantId, kind: asset.kind as any, purpose: asset.kind === 'thumbnail' ? 'catalog' : 'marketing', url: asset.url, sortOrder: asset.sortOrder || 0, isPublished: true };
  }

  async listVariantAssets(variantId: string): Promise<ProductAsset[]> {
    if (!this.db) return [];
    const rows = await this.db.select().from(productImages).where(eq(productImages.productVariantId, variantId));
    return rows.map((img) => ({
      assetId: img.id,
      productVariantId: img.productVariantId,
      kind: apiAssetKind(img.kind),
      purpose: apiAssetKind(img.kind) === 'thumbnail' ? 'catalog' : 'marketing',
      url: img.url,
      sortOrder: img.sortOrder,
      isPublished: true,
    }));
  }

  async getVariantAsset(variantId: string, assetId: string): Promise<ProductAsset | null> {
    if (this.db) {
      const rows = await this.db.select().from(productImages).where(and(eq(productImages.productVariantId, variantId), eq(productImages.id, assetId))).limit(1);
      const row = rows[0];
      if (row) {
        const kind = apiAssetKind(row.kind);
        return { assetId: row.id, productVariantId: row.productVariantId, kind, purpose: kind === 'thumbnail' ? 'catalog' : 'marketing', url: row.url, sortOrder: row.sortOrder, isPublished: true };
      }
    }
    return this.memoryCache.get(variantId)?.assets.find((a) => a.assetId === assetId) || null;
  }

  async deleteVariantAsset(variantId: string, assetId: string): Promise<boolean> {
    const asset = await this.getVariantAsset(variantId, assetId);
    if (!asset) return false;
    if (this.db) await this.db.delete(productImages).where(and(eq(productImages.productVariantId, variantId), eq(productImages.id, assetId)));
    const cached = this.memoryCache.get(variantId);
    if (cached) cached.assets = cached.assets.filter((a) => a.assetId !== assetId);
    return true;
  }
}

