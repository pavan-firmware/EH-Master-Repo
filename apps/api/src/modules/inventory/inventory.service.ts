import { InventoryRepository } from './inventory.repository';
import {
  RegisterInventoryRequest,
  RegisterInventoryResult,
  DualScanVerificationRequest,
  DualScanVerificationResult,
  CreateCartonRequest,
  CompletePackingRequest,
  CompletePackingResult,
  InventoryItem,
  PackagingCarton,
  PackagingRecord,
  evaluateDualScan,
  isValidInventoryStateTransition,
  BenchProvisioningTraceabilityRecordSchema,
  CANONICAL_APPROVED_VARIANTS,
  isCanonicalProductHardwareSupported,
  getCanonicalProductDefinition,
  assertNoSecretsInRecord
} from '@eh-home/contracts';

export class InventoryService {
  constructor(private readonly repository: InventoryRepository) {}

  /**
   * Registers a bench-provisioned device into manufacturing inventory.
   * Enforces all 8 lifecycle and compatibility validation gates.
   */
  async registerDevice(request: RegisterInventoryRequest): Promise<RegisterInventoryResult> {
    const record = request.traceabilityRecord;
    assertNoSecretsInRecord(record);

    // 1. Validate Traceability Record Schema
    const parse = BenchProvisioningTraceabilityRecordSchema.safeParse(record);
    if (!parse.success) {
      return {
        success: false,
        errorCode: 'PACKING_VALIDATION_FAILED',
        errorMessage: `Invalid traceability record: ${parse.error.message}`,
        registeredAt: new Date().toISOString(),
      };
    }

    // 2. Validate Provisioning Success
    if (record.flashStatus !== 'PASS' || record.verificationStatus !== 'PASS' || record.provisioningStatus !== 'PASS') {
      return {
        success: false,
        errorCode: 'PROVISIONING_NOT_PASSED',
        errorMessage: `Device provisioning was not successful (flash=${record.flashStatus}, verify=${record.verificationStatus}, prov=${record.provisioningStatus}).`,
        registeredAt: new Date().toISOString(),
      };
    }

    // 3. Validate Canonical Product Variant
    if (!CANONICAL_APPROVED_VARIANTS.has(record.productVariantId)) {
      return {
        success: false,
        errorCode: 'PRODUCT_MISMATCH',
        errorMessage: `Product variant '${record.productVariantId}' is not canonical.`,
        registeredAt: new Date().toISOString(),
      };
    }

    // 4. Validate Hardware Revision Compatibility
    if (!isCanonicalProductHardwareSupported(record.productVariantId, record.hardwareRevision)) {
      return {
        success: false,
        errorCode: 'HARDWARE_REVISION_MISMATCH',
        errorMessage: `Hardware revision '${record.hardwareRevision}' is not supported for variant '${record.productVariantId}'.`,
        registeredAt: new Date().toISOString(),
      };
    }

    // 5. Validate Firmware Family Consistency
    const prodDef = getCanonicalProductDefinition(record.productVariantId);
    if (!prodDef || prodDef.firmwareFamily !== record.firmwareFamily) {
      return {
        success: false,
        errorCode: 'FIRMWARE_FAMILY_MISMATCH',
        errorMessage: `Firmware family '${record.firmwareFamily}' does not match product definition '${prodDef?.firmwareFamily}'.`,
        registeredAt: new Date().toISOString(),
      };
    }

    // 6. Idempotency check: Check if device is already registered
    const existing = await this.repository.findInventoryItemByDeviceId(record.deviceId);
    if (existing) {
      return {
        success: true,
        inventoryItem: this.mapToContractInventoryItem(existing),
        registeredAt: existing.registeredAt.toISOString(),
      };
    }

    const qrToken = request.qrToken;
    const qrUri = qrToken ? `eh://p/v1?t=${qrToken}` : null;
    const now = new Date();

    const created = await this.repository.createInventoryItem({
      id: `inv_${record.deviceId}`,
      deviceId: record.deviceId,
      serialNumber: record.serialNumber,
      productVariantId: record.productVariantId,
      hardwareRevision: record.hardwareRevision,
      firmwareFamily: record.firmwareFamily,
      firmwareVersion: record.firmwareVersion,
      traceId: record.traceId,
      status: 'PROVISIONED',
      qrToken: qrToken || null,
      qrUri: qrUri || null,
      qcStatus: 'PASS',
      registeredAt: now,
      createdAt: now,
      updatedAt: now,
    });

    return {
      success: true,
      inventoryItem: this.mapToContractInventoryItem(created),
      registeredAt: now.toISOString(),
    };
  }

  /**
   * Retrieves an inventory item by deviceId or serialNumber.
   */
  async getDevice(identifier: string): Promise<InventoryItem | undefined> {
    const item = await this.repository.findInventoryItemByIdentifier(identifier);
    if (!item) return undefined;
    return this.mapToContractInventoryItem(item);
  }

  /**
   * Executes dual-scan verification comparing a device's identity with a scanned label QR token/carton.
   */
  async performDualScan(request: DualScanVerificationRequest): Promise<DualScanVerificationResult> {
    const item = await this.repository.findInventoryItemBySerialNumber(request.deviceSerial);
    if (!item) {
      return {
        schemaVersion: 1,
        success: false,
        isMatch: false,
        status: 'DEVICE_NOT_FOUND',
        deviceSerial: request.deviceSerial,
        rejectionReason: `Device with serial '${request.deviceSerial}' was not found in inventory.`,
        errorCode: 'DEVICE_NOT_FOUND',
        verifiedAt: new Date().toISOString(),
      };
    }

    const contractItem = this.mapToContractInventoryItem(item);
    let carton: PackagingCarton | null = null;
    if (request.cartonId) {
      const dbCarton = await this.repository.findCartonById(request.cartonId);
      if (dbCarton) {
        carton = this.mapToContractCarton(dbCarton);
      }
    }

    const evaluation = evaluateDualScan({
      item: contractItem,
      scannedTokenOrUri: request.boxTokenOrUri,
      carton,
      stationId: request.stationId,
      operatorUserId: request.operatorUserId,
    });

    // Record verification event in database
    const verificationId = `ver_${item.serialNumber}_${Date.now()}`;
    await this.repository.recordDualScanVerification({
      id: verificationId,
      deviceId: item.deviceId,
      serialNumber: item.serialNumber,
      scannedQrToken: evaluation.boxToken || request.boxTokenOrUri.slice(0, 64),
      scannedQrUri: request.boxTokenOrUri.startsWith('eh://p/v1?t=') ? request.boxTokenOrUri : `eh://p/v1?t=${evaluation.boxToken || request.boxTokenOrUri}`,
      cartonId: carton?.id || null,
      isMatch: evaluation.isMatch,
      verificationStatus: evaluation.status,
      rejectionReason: evaluation.rejectionReason || null,
      stationId: request.stationId,
      operatorUserId: request.operatorUserId || null,
      verifiedAt: new Date(),
    });

    // If match approved, update status to VERIFIED or PACKING
    if (evaluation.success && evaluation.isMatch) {
      const nextStatus = carton ? 'PACKING' : 'VERIFIED';
      if (isValidInventoryStateTransition(item.status as any, nextStatus)) {
        await this.repository.updateInventoryStatus(item.deviceId, nextStatus, {
          cartonId: carton?.id || null,
          verifiedAt: new Date(),
        });
      }
    }

    return {
      ...evaluation,
      verificationId,
    };
  }

  /**
   * Creates or retrieves a packaging carton.
   */
  async createCarton(request: CreateCartonRequest): Promise<PackagingCarton> {
    const existing = await this.repository.findCartonByCode(request.cartonCode);
    if (existing) {
      return this.mapToContractCarton(existing);
    }

    const now = new Date();
    const id = `carton_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const created = await this.repository.createPackagingCarton({
      id,
      cartonCode: request.cartonCode,
      productVariantId: request.productVariantId,
      hardwareRevision: request.hardwareRevision,
      targetCapacity: request.targetCapacity || 1,
      packedCount: 0,
      status: 'OPEN',
      operatorUserId: request.operatorUserId || null,
      createdAt: now,
      updatedAt: now,
    });

    return this.mapToContractCarton(created);
  }

  async getCarton(cartonId: string): Promise<PackagingCarton | undefined> {
    const carton = await this.repository.findCartonById(cartonId);
    if (!carton) return undefined;
    return this.mapToContractCarton(carton);
  }

  /**
   * Atomically finalizes the packing operation.
   */
  async completePacking(request: CompletePackingRequest): Promise<CompletePackingResult> {
    try {
      const result = await this.repository.packDeviceAtomic({
        deviceId: request.deviceId,
        cartonId: request.cartonId,
        verificationId: request.verificationId,
        stationId: request.stationId,
        operatorUserId: request.operatorUserId,
        notes: request.notes,
      });

      return {
        success: true,
        packagingRecord: this.mapToContractPackagingRecord(result.record),
        inventoryItem: this.mapToContractInventoryItem(result.item),
        carton: this.mapToContractCarton(result.carton),
        packedAt: result.record.packedAt.toISOString(),
      };
    } catch (err: any) {
      const errMessage = err.message || 'PACKING_VALIDATION_FAILED';
      return {
        success: false,
        errorCode: (errMessage as any) || 'PACKING_VALIDATION_FAILED',
        errorMessage: `Packing failed: ${errMessage}`,
        packedAt: new Date().toISOString(),
      };
    }
  }

  async getPackingHistory(limit = 50, offset = 0): Promise<PackagingRecord[]> {
    const rows = await this.repository.getPackingHistory(limit, offset);
    return rows.map((r) => this.mapToContractPackagingRecord(r));
  }

  // ── Helper Mappers ───────────────────────────────────────────────────

  private mapToContractInventoryItem(dbItem: any): InventoryItem {
    return {
      id: dbItem.id,
      deviceId: dbItem.deviceId,
      serialNumber: dbItem.serialNumber,
      productVariantId: dbItem.productVariantId,
      hardwareRevision: dbItem.hardwareRevision,
      firmwareFamily: dbItem.firmwareFamily,
      firmwareVersion: dbItem.firmwareVersion,
      traceId: dbItem.traceId,
      status: dbItem.status,
      cartonId: dbItem.cartonId,
      qrToken: dbItem.qrToken,
      qrUri: dbItem.qrUri,
      qcStatus: dbItem.qcStatus,
      registeredAt: dbItem.registeredAt instanceof Date ? dbItem.registeredAt.toISOString() : dbItem.registeredAt,
      verifiedAt: dbItem.verifiedAt instanceof Date ? dbItem.verifiedAt.toISOString() : dbItem.verifiedAt,
      packedAt: dbItem.packedAt instanceof Date ? dbItem.packedAt.toISOString() : dbItem.packedAt,
    };
  }

  private mapToContractCarton(dbCarton: any): PackagingCarton {
    return {
      id: dbCarton.id,
      cartonCode: dbCarton.cartonCode,
      productVariantId: dbCarton.productVariantId,
      hardwareRevision: dbCarton.hardwareRevision,
      targetCapacity: dbCarton.targetCapacity,
      packedCount: dbCarton.packedCount,
      status: dbCarton.status,
      sealedAt: dbCarton.sealedAt instanceof Date ? dbCarton.sealedAt.toISOString() : dbCarton.sealedAt,
      operatorUserId: dbCarton.operatorUserId,
      createdAt: dbCarton.createdAt instanceof Date ? dbCarton.createdAt.toISOString() : dbCarton.createdAt,
      updatedAt: dbCarton.updatedAt instanceof Date ? dbCarton.updatedAt.toISOString() : dbCarton.updatedAt,
    };
  }

  private mapToContractPackagingRecord(dbRecord: any): PackagingRecord {
    return {
      id: dbRecord.id,
      traceId: dbRecord.traceId,
      deviceId: dbRecord.deviceId,
      serialNumber: dbRecord.serialNumber,
      productVariantId: dbRecord.productVariantId,
      hardwareRevision: dbRecord.hardwareRevision,
      firmwareFamily: dbRecord.firmwareFamily,
      firmwareVersion: dbRecord.firmwareVersion,
      cartonId: dbRecord.cartonId,
      verificationId: dbRecord.verificationId,
      stationId: dbRecord.stationId,
      operatorUserId: dbRecord.operatorUserId,
      packedAt: dbRecord.packedAt instanceof Date ? dbRecord.packedAt.toISOString() : dbRecord.packedAt,
      notes: dbRecord.notes,
    };
  }
}
