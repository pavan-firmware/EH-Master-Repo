import { InventoryRepository } from './inventory.repository';
import { RegisterInventoryRequest, RegisterInventoryResult, DualScanVerificationRequest, DualScanVerificationResult, CreateCartonRequest, CompletePackingRequest, CompletePackingResult, InventoryItem, PackagingCarton, PackagingRecord } from '@eh-home/contracts';
export declare class InventoryService {
    private readonly repository;
    constructor(repository: InventoryRepository);
    /**
     * Registers a bench-provisioned device into manufacturing inventory.
     * Enforces all 8 lifecycle and compatibility validation gates.
     */
    registerDevice(request: RegisterInventoryRequest): Promise<RegisterInventoryResult>;
    /**
     * Retrieves an inventory item by deviceId or serialNumber.
     */
    getDevice(identifier: string): Promise<InventoryItem | undefined>;
    /**
     * Executes dual-scan verification comparing a device's identity with a scanned label QR token/carton.
     */
    performDualScan(request: DualScanVerificationRequest): Promise<DualScanVerificationResult>;
    /**
     * Creates or retrieves a packaging carton.
     */
    createCarton(request: CreateCartonRequest): Promise<PackagingCarton>;
    getCarton(cartonId: string): Promise<PackagingCarton | undefined>;
    /**
     * Atomically finalizes the packing operation.
     */
    completePacking(request: CompletePackingRequest): Promise<CompletePackingResult>;
    getPackingHistory(limit?: number, offset?: number): Promise<PackagingRecord[]>;
    private mapToContractInventoryItem;
    private mapToContractCarton;
    private mapToContractPackagingRecord;
    listInventoryItems(filters: {
        status?: string;
        productVariantId?: string;
        cartonId?: string;
        limit?: number;
        offset?: number;
    }): Promise<any[]>;
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
    }): Promise<any[]>;
    recordQcOperation(data: {
        stationId: string;
        operatorUserId?: string;
        deviceId: string;
        serialNumber: string;
        scannedQrToken?: string;
        scannedQrUri?: string;
        isMatch: boolean;
        verificationStatus: string;
        rejectionReason?: string;
    }): Promise<any>;
    adjustInventory(deviceId: string, status: string, notes?: string): Promise<any>;
}
//# sourceMappingURL=inventory.service.d.ts.map