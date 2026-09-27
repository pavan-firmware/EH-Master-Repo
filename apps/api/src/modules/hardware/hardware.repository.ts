/**
 * EH Home Hardware & BOM Repository
 *
 * Provides database persistence via @eh-home/db-schema and Drizzle ORM.
 * Supports fallback to memory cache for testing and disconnected environments.
 */

import { eq, and } from 'drizzle-orm';
import {
  EhDatabase,
  hardwareRevisions,
  bomSpecifications,
  bomItems,
  productVariantHardwareCompatibility,
} from '@eh-home/db-schema';
import {
  BOMDetail,
  CreateBOMSpecificationBody,
  CreateHardwareRevisionBody,
  HardwareRevisionDetail,
  ListHardwareRevisionsQuery,
} from './hardware.schema';
import { HardwareRevisionStatus } from '@eh-home/contracts';

export class HardwareRepository {
  private db?: EhDatabase;
  private memoryRevisions: Map<string, HardwareRevisionDetail> = new Map();
  private memoryBoms: Map<string, BOMDetail> = new Map();
  private initializedMemory = false;

  constructor(db?: EhDatabase) {
    this.db = db;
    this.ensureMemoryCache();
  }

  /**
   * Seeds memory cache with baseline hardware revisions for the canonical products.
   */
  private ensureMemoryCache(): void {
    if (this.initializedMemory) return;

    // Seed baseline smart-switch revisions
    const rev1_0: HardwareRevisionDetail = {
      id: 'hw_rev_switch_1x_1_0',
      revisionCode: 'HW_1_0',
      productVariantId: 'eh-smart-switch-1x',
      pcbName: 'smart_switch_3x',
      pcbRevision: 'v1.0',
      displayName: 'Smart Switch 1X Mainboard Rev 1.0',
      lifecycleStatus: 'ACTIVE',
      layerCount: 2,
      mcuFamily: 'esp32-c6',
      dimensionsMm: { width: 86.0, height: 86.0, thickness: 1.6 },
      pinMap: { relay_ch1: 18, switch_in_ch1: 4, bl0942_tx: 7, status_led: 8 },
      schematicAssetUrl: 'assets/hardware/smart_switch_3x/schematic.pdf',
      gerberAssetUrl: null,
      renderAssetUrl: 'assets/hardware/smart_switch_3x/render_top.png',
      designMetadata: { kicadProject: 'hardware/kicad/smart_switch_3x/smart_switch_3x.kicad_pro' },
      effectiveAt: '2026-01-01T00:00:00Z',
      deprecatedAt: null,
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
    };

    const rev1_1: HardwareRevisionDetail = {
      id: 'hw_rev_switch_1x_1_1',
      revisionCode: 'HW_1_1',
      productVariantId: 'eh-smart-switch-1x',
      pcbName: 'smart_switch_3x',
      pcbRevision: 'v1.1',
      displayName: 'Smart Switch 1X Mainboard Rev 1.1',
      lifecycleStatus: 'ACTIVE',
      layerCount: 2,
      mcuFamily: 'esp32-c6',
      dimensionsMm: { width: 86.0, height: 86.0, thickness: 1.6 },
      pinMap: { relay_ch1: 18, switch_in_ch1: 4, bl0942_tx: 7, status_led: 8 },
      schematicAssetUrl: 'assets/hardware/smart_switch_3x/schematic.pdf',
      gerberAssetUrl: null,
      renderAssetUrl: 'assets/hardware/smart_switch_3x/render_top.png',
      designMetadata: { kicadProject: 'hardware/kicad/smart_switch_3x/smart_switch_3x.kicad_pro' },
      effectiveAt: '2026-06-01T00:00:00Z',
      deprecatedAt: null,
      createdAt: '2026-06-01T00:00:00Z',
      updatedAt: '2026-06-01T00:00:00Z',
    };

    this.memoryRevisions.set(rev1_0.id, rev1_0);
    this.memoryRevisions.set(rev1_1.id, rev1_1);

    // Seed sample BOM for rev1_0
    const sampleBom: BOMDetail = {
      id: 'bom_switch_1x_v1_0_0',
      hardwareRevisionId: rev1_0.id,
      version: '1.0.0',
      lifecycleStatus: 'ACTIVE',
      totalUniqueComponents: 8,
      notes: 'Initial production BOM for Smart Switch Rev 1.0',
      effectiveDate: '2026-01-01T00:00:00Z',
      items: [
        {
          itemIndex: 1,
          referenceDesignator: 'U1',
          mpn: 'ESP32-C6-WROOM-1-N4',
          manufacturer: 'Espressif Systems',
          description: 'MCU Wi-Fi 6 / BLE 5 / 802.15.4 module',
          footprint: 'Module:ESP32-C6-WROOM-1',
          quantity: 1,
          isDnf: false,
        },
        {
          itemIndex: 2,
          referenceDesignator: 'U2',
          mpn: 'HLK-PM01',
          manufacturer: 'Hi-Link',
          description: 'Isolated AC-DC SMPS 220V to 5V 3W',
          footprint: 'Power:HLK-PM01',
          quantity: 1,
          isDnf: false,
        },
        {
          itemIndex: 3,
          referenceDesignator: 'U3',
          mpn: 'AP2112K-3.3',
          manufacturer: 'Diodes Inc',
          description: 'LDO 3.3V 600mA Low Dropout Regulator',
          footprint: 'Package_TO_SOT_SMD:SOT-23-5',
          quantity: 1,
          isDnf: false,
        },
        {
          itemIndex: 4,
          referenceDesignator: 'U4',
          mpn: 'BL0942',
          manufacturer: 'Shanghai Belling',
          description: 'Single-phase energy metering IC with UART',
          footprint: 'Package_SO:SOP-14',
          quantity: 1,
          isDnf: false,
        },
        {
          itemIndex: 5,
          referenceDesignator: 'K1',
          mpn: 'HF32F-G-005-HS',
          manufacturer: 'Hongfa',
          description: 'Power Relay 10A 250VAC 5VDC Coil',
          footprint: 'Relay:HF32F-G',
          quantity: 1,
          isDnf: false,
        },
        {
          itemIndex: 6,
          referenceDesignator: 'Q1',
          mpn: 'AO3400A',
          manufacturer: 'Alpha & Omega',
          description: 'N-Channel MOSFET 30V 5.7A',
          footprint: 'Package_TO_SOT_SMD:SOT-23',
          quantity: 1,
          isDnf: false,
        },
        {
          itemIndex: 7,
          referenceDesignator: 'MOV1',
          mpn: '14D561K',
          manufacturer: 'Bourns',
          description: 'Metal Oxide Varistor 350VAC 560V',
          footprint: 'Varistor:14D',
          quantity: 1,
          isDnf: false,
        },
        {
          itemIndex: 8,
          referenceDesignator: 'F1',
          mpn: '37212000411',
          manufacturer: 'Littelfuse',
          description: 'TR5 Fuse 2A 250V Time-Lag',
          footprint: 'Fuse:TR5',
          quantity: 1,
          isDnf: false,
        },
      ],
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
    };

    this.memoryBoms.set(sampleBom.id, sampleBom);
    this.initializedMemory = true;
  }

  /**
   * Lists hardware revisions with optional filtering.
   */
  async listHardwareRevisions(
    filters: ListHardwareRevisionsQuery
  ): Promise<{ items: HardwareRevisionDetail[]; total: number }> {
    if (this.db) {
      try {
        const conditions: any[] = [];
        if (filters.productVariantId) {
          conditions.push(eq(hardwareRevisions.productVariantId, filters.productVariantId));
        }
        if (filters.status) {
          conditions.push(eq(hardwareRevisions.lifecycleStatus, filters.status));
        }
        if (filters.revisionCode) {
          conditions.push(eq(hardwareRevisions.revisionCode, filters.revisionCode));
        }
        if (filters.mcuFamily) {
          conditions.push(eq(hardwareRevisions.mcuFamily, filters.mcuFamily));
        }

        const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

        const rows = await this.db
          .select()
          .from(hardwareRevisions)
          .where(whereClause)
          .limit(filters.limit)
          .offset(filters.offset);

        if (rows.length > 0) {
          const items: HardwareRevisionDetail[] = rows.map((r) => ({
            id: r.id,
            revisionCode: r.revisionCode,
            productVariantId: r.productVariantId,
            pcbName: r.pcbName,
            pcbRevision: r.pcbRevision,
            displayName: r.displayName,
            lifecycleStatus: r.lifecycleStatus as HardwareRevisionStatus,
            layerCount: r.layerCount,
            mcuFamily: r.mcuFamily,
            dimensionsMm: (r.dimensionsMm as Record<string, unknown>) || null,
            pinMap: (r.pinMap as Record<string, number>) || {},
            schematicAssetUrl: r.schematicAssetUrl,
            gerberAssetUrl: r.gerberAssetUrl,
            renderAssetUrl: r.renderAssetUrl,
            designMetadata: (r.designMetadata as Record<string, unknown>) || {},
            effectiveAt: r.effectiveAt?.toISOString() || null,
            deprecatedAt: r.deprecatedAt?.toISOString() || null,
            createdAt: r.createdAt.toISOString(),
            updatedAt: r.updatedAt.toISOString(),
          }));
          return { items, total: items.length };
        }
      } catch {
        // Fall back to memory
      }
    }

    let items = Array.from(this.memoryRevisions.values());
    if (filters.productVariantId) {
      items = items.filter((r) => r.productVariantId === filters.productVariantId);
    }
    if (filters.status) {
      items = items.filter((r) => r.lifecycleStatus === filters.status);
    }
    if (filters.revisionCode) {
      items = items.filter((r) => r.revisionCode === filters.revisionCode);
    }
    if (filters.mcuFamily) {
      items = items.filter((r) => r.mcuFamily === filters.mcuFamily);
    }

    const total = items.length;
    items = items.slice(filters.offset, filters.offset + filters.limit);
    return { items, total };
  }

  /**
   * Retrieves single hardware revision by ID.
   */
  async getHardwareRevisionById(id: string): Promise<HardwareRevisionDetail | null> {
    if (this.db) {
      try {
        const rows = await this.db
          .select()
          .from(hardwareRevisions)
          .where(eq(hardwareRevisions.id, id))
          .limit(1);
        const r = rows[0];
        if (r) {
          return {
            id: r.id,
            revisionCode: r.revisionCode,
            productVariantId: r.productVariantId,
            pcbName: r.pcbName,
            pcbRevision: r.pcbRevision,
            displayName: r.displayName,
            lifecycleStatus: r.lifecycleStatus as HardwareRevisionStatus,
            layerCount: r.layerCount,
            mcuFamily: r.mcuFamily,
            dimensionsMm: (r.dimensionsMm as Record<string, unknown>) || null,
            pinMap: (r.pinMap as Record<string, number>) || {},
            schematicAssetUrl: r.schematicAssetUrl,
            gerberAssetUrl: r.gerberAssetUrl,
            renderAssetUrl: r.renderAssetUrl,
            designMetadata: (r.designMetadata as Record<string, unknown>) || {},
            effectiveAt: r.effectiveAt?.toISOString() || null,
            deprecatedAt: r.deprecatedAt?.toISOString() || null,
            createdAt: r.createdAt.toISOString(),
            updatedAt: r.updatedAt.toISOString(),
          };
        }
      } catch {
        // Fall back to memory
      }
    }

    return this.memoryRevisions.get(id) || null;
  }

  /**
   * Retrieves single hardware revision by variant ID and revision code.
   */
  async getHardwareRevisionByVariantAndCode(
    productVariantId: string,
    revisionCode: string
  ): Promise<HardwareRevisionDetail | null> {
    if (this.db) {
      try {
        const rows = await this.db
          .select()
          .from(hardwareRevisions)
          .where(
            and(
              eq(hardwareRevisions.productVariantId, productVariantId),
              eq(hardwareRevisions.revisionCode, revisionCode)
            )
          )
          .limit(1);
        const r = rows[0];
        if (r) {
          return {
            id: r.id,
            revisionCode: r.revisionCode,
            productVariantId: r.productVariantId,
            pcbName: r.pcbName,
            pcbRevision: r.pcbRevision,
            displayName: r.displayName,
            lifecycleStatus: r.lifecycleStatus as HardwareRevisionStatus,
            layerCount: r.layerCount,
            mcuFamily: r.mcuFamily,
            dimensionsMm: (r.dimensionsMm as Record<string, unknown>) || null,
            pinMap: (r.pinMap as Record<string, number>) || {},
            schematicAssetUrl: r.schematicAssetUrl,
            gerberAssetUrl: r.gerberAssetUrl,
            renderAssetUrl: r.renderAssetUrl,
            designMetadata: (r.designMetadata as Record<string, unknown>) || {},
            effectiveAt: r.effectiveAt?.toISOString() || null,
            deprecatedAt: r.deprecatedAt?.toISOString() || null,
            createdAt: r.createdAt.toISOString(),
            updatedAt: r.updatedAt.toISOString(),
          };
        }
      } catch {
        // Fall back to memory
      }
    }

    for (const r of this.memoryRevisions.values()) {
      if (r.productVariantId === productVariantId && r.revisionCode === revisionCode) {
        return r;
      }
    }
    return null;
  }

  /**
   * Creates a new hardware revision record.
   */
  async createHardwareRevision(data: CreateHardwareRevisionBody): Promise<HardwareRevisionDetail> {
    const id = data.id || `hw_${data.productVariantId}_${data.revisionCode.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;

    const newRev: HardwareRevisionDetail = {
      id,
      revisionCode: data.revisionCode,
      productVariantId: data.productVariantId,
      pcbName: data.pcbName,
      pcbRevision: data.pcbRevision || 'v1.0',
      displayName: data.displayName,
      lifecycleStatus: data.lifecycleStatus || 'DRAFT',
      layerCount: data.layerCount || 2,
      mcuFamily: data.mcuFamily || 'esp32-c6',
      dimensionsMm: (data.dimensionsMm as Record<string, unknown>) || null,
      pinMap: data.pinMap || {},
      schematicAssetUrl: data.schematicAssetUrl || null,
      gerberAssetUrl: data.gerberAssetUrl || null,
      renderAssetUrl: data.renderAssetUrl || null,
      designMetadata: data.designMetadata || {},
      effectiveAt: null,
      deprecatedAt: null,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    if (this.db) {
      try {
        await this.db.insert(hardwareRevisions).values({
          id: newRev.id,
          revisionCode: newRev.revisionCode,
          productVariantId: newRev.productVariantId,
          pcbName: newRev.pcbName,
          pcbRevision: newRev.pcbRevision,
          displayName: newRev.displayName,
          lifecycleStatus: newRev.lifecycleStatus,
          layerCount: newRev.layerCount,
          mcuFamily: newRev.mcuFamily,
          dimensionsMm: newRev.dimensionsMm,
          pinMap: newRev.pinMap,
          schematicAssetUrl: newRev.schematicAssetUrl,
          gerberAssetUrl: newRev.gerberAssetUrl,
          renderAssetUrl: newRev.renderAssetUrl,
          designMetadata: newRev.designMetadata,
        });

        // Also create product_variant_hardware_compatibility entry
        await this.db
          .insert(productVariantHardwareCompatibility)
          .values({
            id: `compat_${newRev.productVariantId}_${newRev.id}`,
            productVariantId: newRev.productVariantId,
            hardwareRevisionId: newRev.id,
            isPrimary: true,
          })
          .onConflictDoNothing();
      } catch (err: any) {
        if (err.code === '23505') {
          throw new Error(`Hardware revision '${data.revisionCode}' already exists for product variant '${data.productVariantId}'`);
        }
        throw err;
      }
    }

    this.memoryRevisions.set(id, newRev);
    return newRev;
  }

  /**
   * Updates lifecycle status for an existing hardware revision.
   */
  async updateHardwareRevisionStatus(
    id: string,
    status: HardwareRevisionStatus
  ): Promise<HardwareRevisionDetail | null> {
    const existing = await this.getHardwareRevisionById(id);
    if (!existing) return null;

    const updated: HardwareRevisionDetail = {
      ...existing,
      lifecycleStatus: status,
      effectiveAt: status === 'ACTIVE' ? new Date().toISOString() : existing.effectiveAt,
      deprecatedAt: status === 'DEPRECATED' || status === 'RETIRED' ? new Date().toISOString() : existing.deprecatedAt,
      updatedAt: new Date().toISOString(),
    };

    if (this.db) {
      try {
        await this.db
          .update(hardwareRevisions)
          .set({
            lifecycleStatus: status,
            effectiveAt: updated.effectiveAt ? new Date(updated.effectiveAt) : undefined,
            deprecatedAt: updated.deprecatedAt ? new Date(updated.deprecatedAt) : undefined,
            updatedAt: new Date(),
          })
          .where(eq(hardwareRevisions.id, id));
      } catch {
        // Fall back to memory
      }
    }

    this.memoryRevisions.set(id, updated);
    return updated;
  }

  /**
   * Retrieves BOM specification for a given hardware revision ID.
   */
  async getBOMByHardwareRevisionId(hardwareRevisionId: string): Promise<BOMDetail | null> {
    if (this.db) {
      try {
        const bomRows = await this.db
          .select()
          .from(bomSpecifications)
          .where(eq(bomSpecifications.hardwareRevisionId, hardwareRevisionId))
          .limit(1);

        const b = bomRows[0];
        if (b) {
          const itemRows = await this.db
            .select()
            .from(bomItems)
            .where(eq(bomItems.bomId, b.id));

          return {
            id: b.id,
            hardwareRevisionId: b.hardwareRevisionId,
            version: b.version,
            lifecycleStatus: b.lifecycleStatus as any,
            totalUniqueComponents: b.totalUniqueComponents,
            notes: b.notes,
            effectiveDate: b.effectiveDate?.toISOString() || null,
            items: itemRows.map((it) => ({
              itemIndex: it.itemIndex,
              referenceDesignator: it.referenceDesignator,
              mpn: it.mpn,
              internalPartNumber: it.internalPartNumber || undefined,
              manufacturer: it.manufacturer || undefined,
              description: it.description,
              footprint: it.footprint,
              quantity: it.quantity,
              unit: it.unit,
              isDnf: it.isDnf,
              vendorPartNumber: it.vendorPartNumber || undefined,
              unitCostInr: it.unitCostInr ? Number(it.unitCostInr) : undefined,
            })),
            createdAt: b.createdAt.toISOString(),
            updatedAt: b.updatedAt.toISOString(),
          };
        }
      } catch {
        // Fall back to memory
      }
    }

    for (const b of this.memoryBoms.values()) {
      if (b.hardwareRevisionId === hardwareRevisionId) {
        return b;
      }
    }
    return null;
  }

  /**
   * Creates a new BOM specification with items.
   */
  async createBOM(data: CreateBOMSpecificationBody): Promise<BOMDetail> {
    const id = data.id || `bom_${data.hardwareRevisionId}_${data.version.replace(/\./g, '_')}`;

    const newBom: BOMDetail = {
      id,
      hardwareRevisionId: data.hardwareRevisionId,
      version: data.version,
      lifecycleStatus: data.lifecycleStatus || 'DRAFT',
      totalUniqueComponents: data.items.length,
      notes: data.notes || null,
      effectiveDate: data.effectiveDate || null,
      items: data.items,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    if (this.db) {
      await this.db.transaction(async (tx) => {
        await tx.insert(bomSpecifications).values({
          id: newBom.id,
          hardwareRevisionId: newBom.hardwareRevisionId,
          version: newBom.version,
          lifecycleStatus: newBom.lifecycleStatus,
          totalUniqueComponents: newBom.totalUniqueComponents,
          notes: newBom.notes,
          effectiveDate: newBom.effectiveDate ? new Date(newBom.effectiveDate) : undefined,
        });

        for (const item of newBom.items) {
          await tx.insert(bomItems).values({
            id: `item_${newBom.id}_${item.itemIndex}`,
            bomId: newBom.id,
            itemIndex: item.itemIndex,
            referenceDesignator: item.referenceDesignator,
            mpn: item.mpn,
            internalPartNumber: (item as any).internalPartNumber || null,
            manufacturer: item.manufacturer,
            description: item.description,
            footprint: item.footprint,
            quantity: item.quantity,
            isDnf: item.isDnf,
            vendorPartNumber: item.vendorPartNumber,
            unitCostInr: item.unitCostInr ? String(item.unitCostInr) : undefined,
          });
        }
      });
    }

    this.memoryBoms.set(id, newBom);
    return newBom;
  }
}
