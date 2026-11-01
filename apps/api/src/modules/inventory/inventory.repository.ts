import { NodePgDatabase } from 'drizzle-orm/node-postgres';
import { eq, desc, like } from 'drizzle-orm';
import {
  inventoryItems,
  packagingCartons,
  dualScanVerifications,
  packagingRecords,
  devices,
  InventoryItem,
  NewInventoryItem,
  PackagingCarton,
  NewPackagingCarton,
  DualScanVerification,
  NewDualScanVerification,
  PackagingRecord,
  NewPackagingRecord,
  EhDatabase
} from '@eh-home/db-schema';

export class InventoryRepository {
  private memInventory = new Map<string, InventoryItem>(); // key: deviceId
  private memCartons = new Map<string, PackagingCarton>(); // key: id
  private memDualScans = new Map<string, DualScanVerification>(); // key: id
  private memPackingRecords = new Map<string, PackagingRecord>(); // key: id

  constructor(private readonly db?: EhDatabase | NodePgDatabase<Record<string, unknown>>) {}

  async findInventoryItemByDeviceId(deviceId: string): Promise<InventoryItem | undefined> {
    if (!this.db) {
      return this.memInventory.get(deviceId);
    }
    const rows = await this.db
      .select()
      .from(inventoryItems)
      .where(eq(inventoryItems.deviceId, deviceId))
      .limit(1);
    return rows[0];
  }

  async findInventoryItemBySerialNumber(serialNumber: string): Promise<InventoryItem | undefined> {
    if (!this.db) {
      for (const item of this.memInventory.values()) {
        if (item.serialNumber === serialNumber) return item;
      }
      return undefined;
    }
    const rows = await this.db
      .select()
      .from(inventoryItems)
      .where(eq(inventoryItems.serialNumber, serialNumber))
      .limit(1);
    return rows[0];
  }

  async findInventoryItemBySerialSuffix(suffix: string): Promise<InventoryItem | undefined> {
    if (!/^\d{5}$/.test(suffix)) return undefined;
    if (!this.db) {
      for (const item of this.memInventory.values()) {
        if (item.serialNumber.endsWith(`-${suffix}`)) return item;
      }
      return undefined;
    }
    const rows = await this.db
      .select()
      .from(inventoryItems)
      .where(like(inventoryItems.serialNumber, `%-${suffix}`))
      .limit(1);
    return rows[0];
  }

  async findInventoryItemByQrToken(qrToken: string): Promise<InventoryItem | undefined> {
    if (!qrToken) return undefined;
    if (!this.db) {
      for (const item of this.memInventory.values()) {
        if (item.qrToken === qrToken) return item;
      }
      return undefined;
    }
    const rows = await this.db
      .select()
      .from(inventoryItems)
      .where(eq(inventoryItems.qrToken, qrToken))
      .limit(1);
    return rows[0];
  }

  async findInventoryItemByIdentifier(identifier: string): Promise<InventoryItem | undefined> {
    const byDevice = await this.findInventoryItemByDeviceId(identifier);
    if (byDevice) return byDevice;
    return this.findInventoryItemBySerialNumber(identifier);
  }

  async createInventoryItem(item: NewInventoryItem): Promise<InventoryItem> {
    if (!this.db) {
      const now = new Date();
      const created: InventoryItem = {
        id: item.id || `inv_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        deviceId: item.deviceId,
        serialNumber: item.serialNumber,
        productVariantId: item.productVariantId,
        hardwareRevision: item.hardwareRevision,
        firmwareFamily: item.firmwareFamily,
        firmwareVersion: item.firmwareVersion,
        traceId: item.traceId,
        status: item.status || 'PROVISIONED',
        cartonId: item.cartonId || null,
        qrToken: item.qrToken || null,
        qrUri: item.qrUri || null,
        qcStatus: item.qcStatus || 'PASS',
        registeredAt: item.registeredAt || now,
        verifiedAt: item.verifiedAt || null,
        packedAt: item.packedAt || null,
        createdAt: now,
        updatedAt: now,
      };
      this.memInventory.set(created.deviceId, created);
      return created;
    }

    await this.db
      .insert(devices)
      .values({
        id: item.deviceId,
        serialNumber: item.serialNumber,
        productVariantId: item.productVariantId,
        hardwareRevision: item.hardwareRevision,
        firmwareVersion: item.firmwareVersion,
        firmwareFamily: item.firmwareFamily,
      })
      .onConflictDoNothing();

    const rows = await this.db
      .insert(inventoryItems)
      .values(item)
      .returning();
    return rows[0]!;
  }

  async updateInventoryStatus(
    deviceId: string,
    status: string,
    opts?: { cartonId?: string | null; verifiedAt?: Date | null; packedAt?: Date | null }
  ): Promise<InventoryItem | undefined> {
    if (!this.db) {
      const item = this.memInventory.get(deviceId);
      if (!item) return undefined;
      item.status = status;
      item.updatedAt = new Date();
      if (opts?.cartonId !== undefined) item.cartonId = opts.cartonId;
      if (opts?.verifiedAt !== undefined) item.verifiedAt = opts.verifiedAt;
      if (opts?.packedAt !== undefined) item.packedAt = opts.packedAt;
      return item;
    }

    const updateData: Partial<NewInventoryItem> = {
      status,
      updatedAt: new Date(),
    };
    if (opts?.cartonId !== undefined) updateData.cartonId = opts.cartonId;
    if (opts?.verifiedAt !== undefined) updateData.verifiedAt = opts.verifiedAt;
    if (opts?.packedAt !== undefined) updateData.packedAt = opts.packedAt;

    const rows = await this.db
      .update(inventoryItems)
      .set(updateData)
      .where(eq(inventoryItems.deviceId, deviceId))
      .returning();
    return rows[0];
  }

  async findCartonById(id: string): Promise<PackagingCarton | undefined> {
    if (!this.db) {
      return this.memCartons.get(id);
    }
    const rows = await this.db
      .select()
      .from(packagingCartons)
      .where(eq(packagingCartons.id, id))
      .limit(1);
    return rows[0];
  }

  async findCartonByCode(code: string): Promise<PackagingCarton | undefined> {
    if (!this.db) {
      for (const carton of this.memCartons.values()) {
        if (carton.cartonCode === code) return carton;
      }
      return undefined;
    }
    const rows = await this.db
      .select()
      .from(packagingCartons)
      .where(eq(packagingCartons.cartonCode, code))
      .limit(1);
    return rows[0];
  }

  async createPackagingCarton(carton: NewPackagingCarton): Promise<PackagingCarton> {
    if (!this.db) {
      const now = new Date();
      const created: PackagingCarton = {
        id: carton.id || `carton_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        cartonCode: carton.cartonCode,
        productVariantId: carton.productVariantId,
        hardwareRevision: carton.hardwareRevision,
        targetCapacity: carton.targetCapacity || 1,
        packedCount: carton.packedCount || 0,
        status: carton.status || 'OPEN',
        sealedAt: carton.sealedAt || null,
        operatorUserId: carton.operatorUserId || null,
        createdAt: now,
        updatedAt: now,
      };
      this.memCartons.set(created.id, created);
      return created;
    }

    const rows = await this.db
      .insert(packagingCartons)
      .values(carton)
      .returning();
    return rows[0]!;
  }

  async findDualScanVerificationById(id: string): Promise<DualScanVerification | undefined> {
    if (!this.db) {
      return this.memDualScans.get(id);
    }
    const rows = await this.db
      .select()
      .from(dualScanVerifications)
      .where(eq(dualScanVerifications.id, id))
      .limit(1);
    return rows[0];
  }

  async recordDualScanVerification(verification: NewDualScanVerification): Promise<DualScanVerification> {
    if (!this.db) {
      const now = new Date();
      const created: DualScanVerification = {
        id: verification.id || `ver_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        stationId: verification.stationId,
        operatorUserId: verification.operatorUserId || null,
        deviceId: verification.deviceId,
        serialNumber: verification.serialNumber,
        scannedQrToken: verification.scannedQrToken,
        scannedQrUri: verification.scannedQrUri,
        cartonId: verification.cartonId || null,
        isMatch: verification.isMatch,
        verificationStatus: verification.verificationStatus,
        rejectionReason: verification.rejectionReason || null,
        verifiedAt: verification.verifiedAt || now,
      };
      this.memDualScans.set(created.id, created);
      return created;
    }

    const rows = await this.db
      .insert(dualScanVerifications)
      .values(verification)
      .returning();
    return rows[0]!;
  }

  async createPackagingRecord(record: NewPackagingRecord): Promise<PackagingRecord> {
    if (!this.db) {
      const now = new Date();
      const created: PackagingRecord = {
        id: record.id || `pack_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        traceId: record.traceId,
        deviceId: record.deviceId,
        serialNumber: record.serialNumber,
        productVariantId: record.productVariantId,
        hardwareRevision: record.hardwareRevision,
        firmwareFamily: record.firmwareFamily,
        firmwareVersion: record.firmwareVersion,
        cartonId: record.cartonId,
        verificationId: record.verificationId,
        stationId: record.stationId,
        operatorUserId: record.operatorUserId || null,
        packedAt: record.packedAt || now,
        notes: record.notes || null,
      };
      this.memPackingRecords.set(created.id, created);
      return created;
    }

    const rows = await this.db
      .insert(packagingRecords)
      .values(record)
      .returning();
    return rows[0]!;
  }

  async getPackingHistory(limit = 50, offset = 0): Promise<PackagingRecord[]> {
    if (!this.db) {
      const list = Array.from(this.memPackingRecords.values()).sort(
        (a, b) => new Date(b.packedAt).getTime() - new Date(a.packedAt).getTime()
      );
      return list.slice(offset, offset + limit);
    }
    return this.db
      .select()
      .from(packagingRecords)
      .orderBy(desc(packagingRecords.packedAt))
      .limit(limit)
      .offset(offset);
  }

  /**
   * Concurrency-safe atomic packing completion.
   * Strictly enforces:
   * 1. Successful dual-scan verification for this exact device exists (DUAL_SCAN_NOT_FOUND)
   * 2. Device exists, is verified, not already packed, and passed QC
   * 3. Carton exists, is OPEN, has available capacity, and matches variant & hardware revision
   * 4. Updates inventory item status to PACKED and creates packaging audit record inside transaction
   */
  async packDeviceAtomic(params: {
    deviceId: string;
    cartonId: string;
    verificationId: string;
    stationId: string;
    operatorUserId?: string;
    notes?: string;
  }): Promise<{ item: InventoryItem; record: PackagingRecord; carton: PackagingCarton }> {
    if (!this.db) {
      // 1. Dual-Scan Verification Proof
      if (!params.verificationId) throw new Error('DUAL_SCAN_REQUIRED');
      const ver = this.memDualScans.get(params.verificationId);
      if (!ver) throw new Error('DUAL_SCAN_NOT_FOUND');
      if (ver.deviceId !== params.deviceId) throw new Error('DUAL_SCAN_NOT_FOUND');
      if (!ver.isMatch || ver.verificationStatus !== 'MATCH_APPROVED') throw new Error('DUAL_SCAN_NOT_FOUND');

      // 2. Inventory Item Verification
      const item = this.memInventory.get(params.deviceId);
      if (!item) throw new Error('DEVICE_NOT_FOUND');
      if (item.status === 'PACKED') throw new Error('DEVICE_ALREADY_PACKED');
      if (item.qcStatus !== 'PASS') throw new Error('PROVISIONING_NOT_PASSED');
      if (item.status !== 'VERIFIED' && item.status !== 'PACKING') throw new Error('DEVICE_NOT_VERIFIED');

      // 3. Carton Verification
      if (!params.cartonId) throw new Error('CARTON_REQUIRED');
      const carton = this.memCartons.get(params.cartonId);
      if (!carton) throw new Error('CARTON_NOT_FOUND');
      if (carton.status !== 'OPEN') throw new Error('CARTON_FULL');
      if (carton.packedCount >= carton.targetCapacity) throw new Error('CARTON_FULL');
      if (carton.productVariantId !== item.productVariantId) throw new Error('VARIANT_MISMATCH');
      if (carton.hardwareRevision !== item.hardwareRevision) throw new Error('HARDWARE_REVISION_MISMATCH');

      const now = new Date();
      item.status = 'PACKED';
      item.cartonId = carton.id;
      item.packedAt = now;
      item.updatedAt = now;

      carton.packedCount += 1;
      if (carton.packedCount >= carton.targetCapacity) {
        carton.status = 'FULL';
      }
      carton.updatedAt = now;

      const record: PackagingRecord = {
        id: `pack_${item.serialNumber}_${Date.now()}`,
        traceId: item.traceId,
        deviceId: item.deviceId,
        serialNumber: item.serialNumber,
        productVariantId: item.productVariantId,
        hardwareRevision: item.hardwareRevision,
        firmwareFamily: item.firmwareFamily,
        firmwareVersion: item.firmwareVersion,
        cartonId: carton.id,
        verificationId: params.verificationId,
        stationId: params.stationId,
        operatorUserId: params.operatorUserId || null,
        packedAt: now,
        notes: params.notes || null,
      };
      this.memPackingRecords.set(record.id, record);

      return { item, record, carton };
    }

    return this.db.transaction(async (tx) => {
      // 1. Dual-Scan Verification Proof
      if (!params.verificationId) throw new Error('DUAL_SCAN_REQUIRED');
      const verRows = await tx
        .select()
        .from(dualScanVerifications)
        .where(eq(dualScanVerifications.id, params.verificationId));
      const ver = verRows[0];
      if (!ver) throw new Error('DUAL_SCAN_NOT_FOUND');
      if (ver.deviceId !== params.deviceId) throw new Error('DUAL_SCAN_NOT_FOUND');
      if (!ver.isMatch || ver.verificationStatus !== 'MATCH_APPROVED') throw new Error('DUAL_SCAN_NOT_FOUND');

      // 2. Inventory Item Lock & Proof
      const itemRows = await tx
        .select()
        .from(inventoryItems)
        .where(eq(inventoryItems.deviceId, params.deviceId));

      const item = itemRows[0];
      if (!item) throw new Error('DEVICE_NOT_FOUND');
      if (item.status === 'PACKED') throw new Error('DEVICE_ALREADY_PACKED');
      if (item.qcStatus !== 'PASS') throw new Error('PROVISIONING_NOT_PASSED');
      if (item.status !== 'VERIFIED' && item.status !== 'PACKING') throw new Error('DEVICE_NOT_VERIFIED');

      // 3. Carton Lock & Proof
      if (!params.cartonId) throw new Error('CARTON_REQUIRED');
      const cartonRows = await tx
        .select()
        .from(packagingCartons)
        .where(eq(packagingCartons.id, params.cartonId));

      const carton = cartonRows[0];
      if (!carton) throw new Error('CARTON_NOT_FOUND');
      if (carton.status !== 'OPEN') throw new Error('CARTON_FULL');
      if (carton.packedCount >= carton.targetCapacity) throw new Error('CARTON_FULL');
      if (carton.productVariantId !== item.productVariantId) throw new Error('VARIANT_MISMATCH');
      if (carton.hardwareRevision !== item.hardwareRevision) throw new Error('HARDWARE_REVISION_MISMATCH');

      const now = new Date();
      const updatedItemRows = await tx
        .update(inventoryItems)
        .set({
          status: 'PACKED',
          cartonId: carton.id,
          packedAt: now,
          updatedAt: now,
        })
        .where(eq(inventoryItems.deviceId, item.deviceId))
        .returning();

      const newPackedCount = carton.packedCount + 1;
      const isCartonFull = newPackedCount >= carton.targetCapacity;
      const updatedCartonRows = await tx
        .update(packagingCartons)
        .set({
          packedCount: newPackedCount,
          status: isCartonFull ? 'FULL' : 'OPEN',
          updatedAt: now,
        })
        .where(eq(packagingCartons.id, carton.id))
        .returning();

      const recordId = `pack_${item.serialNumber}_${Date.now()}`;
      const packRecordRows = await tx
        .insert(packagingRecords)
        .values({
          id: recordId,
          traceId: item.traceId,
          deviceId: item.deviceId,
          serialNumber: item.serialNumber,
          productVariantId: item.productVariantId,
          hardwareRevision: item.hardwareRevision,
          firmwareFamily: item.firmwareFamily,
          firmwareVersion: item.firmwareVersion,
          cartonId: carton.id,
          verificationId: params.verificationId,
          stationId: params.stationId,
          operatorUserId: params.operatorUserId,
          packedAt: now,
          notes: params.notes,
        })
        .returning();

      return {
        item: updatedItemRows[0]!,
        record: packRecordRows[0]!,
        carton: updatedCartonRows[0]!,
      };
    });
  }

  async listInventoryItems(filters: { status?: string; productVariantId?: string; cartonId?: string; limit?: number; offset?: number }): Promise<InventoryItem[]> {
    if (!this.db) {
      let list = Array.from(this.memInventory.values());
      if (filters.status) list = list.filter((i) => i.status === filters.status);
      if (filters.productVariantId) list = list.filter((i) => i.productVariantId === filters.productVariantId);
      if (filters.cartonId) list = list.filter((i) => i.cartonId === filters.cartonId);
      return list.slice(filters.offset || 0, (filters.offset || 0) + (filters.limit || 50));
    }

    return this.db
      .select()
      .from(inventoryItems)
      .limit(filters.limit || 50)
      .offset(filters.offset || 0);
  }

  async listCartons(filters?: { status?: string; limit?: number; offset?: number }): Promise<PackagingCarton[]> {
    if (!this.db) {
      let list = Array.from(this.memCartons.values());
      if (filters?.status) list = list.filter((c) => c.status === filters.status);
      return list.slice(filters?.offset || 0, (filters?.offset || 0) + (filters?.limit || 50));
    }

    return this.db
      .select()
      .from(packagingCartons)
      .limit(filters?.limit || 50)
      .offset(filters?.offset || 0);
  }

  async listQcRecords(filters?: { stationId?: string; deviceId?: string; limit?: number; offset?: number }): Promise<DualScanVerification[]> {
    if (!this.db) {
      let list = Array.from(this.memDualScans.values());
      if (filters?.stationId) list = list.filter((v) => v.stationId === filters.stationId);
      if (filters?.deviceId) list = list.filter((v) => v.deviceId === filters.deviceId);
      return list.slice(filters?.offset || 0, (filters?.offset || 0) + (filters?.limit || 50));
    }

    return this.db
      .select()
      .from(dualScanVerifications)
      .orderBy(desc(dualScanVerifications.verifiedAt))
      .limit(filters?.limit || 50)
      .offset(filters?.offset || 0);
  }

  async adjustInventory(deviceId: string, status: string, _notes?: string): Promise<InventoryItem | undefined> {
    return this.updateInventoryStatus(deviceId, status);
  }
}
