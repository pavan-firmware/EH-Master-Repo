import { NodePgDatabase } from 'drizzle-orm/node-postgres';
import { InventoryItem, NewInventoryItem, PackagingCarton, NewPackagingCarton, DualScanVerification, NewDualScanVerification, PackagingRecord, NewPackagingRecord, EhDatabase } from '@eh-home/db-schema';
export declare class InventoryRepository {
    private readonly db?;
    private memInventory;
    private memCartons;
    private memDualScans;
    private memPackingRecords;
    constructor(db?: (EhDatabase | NodePgDatabase<Record<string, unknown>>) | undefined);
    findInventoryItemByDeviceId(deviceId: string): Promise<InventoryItem | undefined>;
    findInventoryItemBySerialNumber(serialNumber: string): Promise<InventoryItem | undefined>;
    findInventoryItemBySerialSuffix(suffix: string): Promise<InventoryItem | undefined>;
    findInventoryItemByQrToken(qrToken: string): Promise<InventoryItem | undefined>;
    findInventoryItemByIdentifier(identifier: string): Promise<InventoryItem | undefined>;
    createInventoryItem(item: NewInventoryItem): Promise<InventoryItem>;
    updateInventoryStatus(deviceId: string, status: string, opts?: {
        cartonId?: string | null;
        verifiedAt?: Date | null;
        packedAt?: Date | null;
    }): Promise<InventoryItem | undefined>;
    findCartonById(id: string): Promise<PackagingCarton | undefined>;
    findCartonByCode(code: string): Promise<PackagingCarton | undefined>;
    createPackagingCarton(carton: NewPackagingCarton): Promise<PackagingCarton>;
    findDualScanVerificationById(id: string): Promise<DualScanVerification | undefined>;
    recordDualScanVerification(verification: NewDualScanVerification): Promise<DualScanVerification>;
    createPackagingRecord(record: NewPackagingRecord): Promise<PackagingRecord>;
    getPackingHistory(limit?: number, offset?: number): Promise<PackagingRecord[]>;
    /**
     * Concurrency-safe atomic packing completion.
     * Strictly enforces:
     * 1. Successful dual-scan verification for this exact device exists (DUAL_SCAN_NOT_FOUND)
     * 2. Device exists, is verified, not already packed, and passed QC
     * 3. Carton exists, is OPEN, has available capacity, and matches variant & hardware revision
     * 4. Updates inventory item status to PACKED and creates packaging audit record inside transaction
     */
    packDeviceAtomic(params: {
        deviceId: string;
        cartonId: string;
        verificationId: string;
        stationId: string;
        operatorUserId?: string;
        notes?: string;
    }): Promise<{
        item: InventoryItem;
        record: PackagingRecord;
        carton: PackagingCarton;
    }>;
    listInventoryItems(filters: {
        status?: string;
        productVariantId?: string;
        cartonId?: string;
        limit?: number;
        offset?: number;
    }): Promise<InventoryItem[]>;
    listCartons(filters?: {
        status?: string;
        limit?: number;
        offset?: number;
    }): Promise<PackagingCarton[]>;
    listQcRecords(filters?: {
        stationId?: string;
        deviceId?: string;
        limit?: number;
        offset?: number;
    }): Promise<DualScanVerification[]>;
    adjustInventory(deviceId: string, status: string, _notes?: string): Promise<InventoryItem | undefined>;
}
//# sourceMappingURL=inventory.repository.d.ts.map