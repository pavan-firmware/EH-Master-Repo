"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.InventoryService = void 0;
const contracts_1 = require("@eh-home/contracts");
function compactFactoryBarcode(item) {
    const variant = item.productVariantId;
    const variantCode = variant.includes('smart-switch')
        ? `S${variant.match(/[1-4]x/)?.[0]?.[0] || '3'}`
        : variant.includes('smart-socket') ? 'K1'
            : variant.includes('smart-fan') ? 'F1'
                : variant.includes('smart-light') ? 'L1'
                    : variant.includes('sensor') ? 'N1'
                        : variant.includes('hub') ? 'B1'
                            : 'X1';
    const hardware = item.hardwareRevision.match(/\d/)?.[0] || '0';
    const firmware = item.firmwareVersion.match(/\d/)?.[0] || '0';
    const sequence = item.serialNumber.split('-').pop() || '00000';
    return `E1${variantCode}H${hardware}F${firmware}-${sequence}`;
}
class InventoryService {
    repository;
    constructor(repository) {
        this.repository = repository;
    }
    /**
     * Registers a bench-provisioned device into manufacturing inventory.
     * Enforces all 8 lifecycle and compatibility validation gates.
     */
    async registerDevice(request) {
        const record = request.traceabilityRecord;
        (0, contracts_1.assertNoSecretsInRecord)(record);
        // 1. Validate Traceability Record Schema
        const parse = contracts_1.BenchProvisioningTraceabilityRecordSchema.safeParse(record);
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
        if (!contracts_1.CANONICAL_APPROVED_VARIANTS.has(record.productVariantId)) {
            return {
                success: false,
                errorCode: 'PRODUCT_MISMATCH',
                errorMessage: `Product variant '${record.productVariantId}' is not canonical.`,
                registeredAt: new Date().toISOString(),
            };
        }
        // 4. Validate Hardware Revision Compatibility
        if (!(0, contracts_1.isCanonicalProductHardwareSupported)(record.productVariantId, record.hardwareRevision)) {
            return {
                success: false,
                errorCode: 'HARDWARE_REVISION_MISMATCH',
                errorMessage: `Hardware revision '${record.hardwareRevision}' is not supported for variant '${record.productVariantId}'.`,
                registeredAt: new Date().toISOString(),
            };
        }
        // 5. Validate Firmware Family Consistency
        const prodDef = (0, contracts_1.getCanonicalProductDefinition)(record.productVariantId);
        const isBenchTestRecord = record.benchTestMode === true;
        if (!prodDef || (!isBenchTestRecord && prodDef.firmwareFamily !== record.firmwareFamily)) {
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
        const existingSerial = await this.repository.findInventoryItemBySerialNumber(record.serialNumber);
        if (existingSerial && existingSerial.deviceId !== record.deviceId) {
            return {
                success: false,
                errorCode: 'SERIAL_ALREADY_REGISTERED',
                errorMessage: `Serial number '${record.serialNumber}' is already assigned to another device. Re-provision with a new serial.`,
                registeredAt: new Date().toISOString(),
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
            // Keep inventory/packing compatibility canonical while allowing the
            // original generic family to remain in the traceability record.
            firmwareFamily: isBenchTestRecord ? prodDef.firmwareFamily : record.firmwareFamily,
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
    async getDevice(identifier) {
        const item = await this.repository.findInventoryItemByIdentifier(identifier);
        if (!item)
            return undefined;
        return this.mapToContractInventoryItem(item);
    }
    /**
     * Executes dual-scan verification comparing a device's identity with a scanned label QR token/carton.
     */
    async performDualScan(request) {
        const scannedValue = request.deviceSerial.trim();
        const scannedToken = request.boxTokenOrUri.startsWith('eh://p/v1?t=')
            ? request.boxTokenOrUri.replace('eh://p/v1?t=', '').split('&')[0] || ''
            : request.boxTokenOrUri;
        let item = await this.repository.findInventoryItemBySerialNumber(scannedValue);
        const compactMatch = /^E1[A-Z]\dH\dF\d-(\d{5})$/.exec(scannedValue);
        if (!item && compactMatch) {
            // The compact factory barcode includes model, HW and FW identifiers.
            // Prefer the exact box QR record, then resolve by sequence and validate
            // that its calculated compact code is identical to the scanned value.
            const qrItem = await this.repository.findInventoryItemByQrToken(scannedToken);
            item = qrItem && compactFactoryBarcode(qrItem) === scannedValue
                ? qrItem
                : await this.repository.findInventoryItemBySerialSuffix(compactMatch[1] || '').then((candidate) => candidate && compactFactoryBarcode(candidate) === scannedValue ? candidate : undefined);
        }
        if (!item) {
            return {
                schemaVersion: 1,
                success: false,
                isMatch: false,
                status: 'DEVICE_NOT_FOUND',
                deviceSerial: scannedValue,
                rejectionReason: `Device with serial '${request.deviceSerial}' was not found in inventory.`,
                errorCode: 'DEVICE_NOT_FOUND',
                verifiedAt: new Date().toISOString(),
            };
        }
        const contractItem = this.mapToContractInventoryItem(item);
        let carton = null;
        if (request.cartonId) {
            const dbCarton = await this.repository.findCartonById(request.cartonId);
            if (dbCarton) {
                carton = this.mapToContractCarton(dbCarton);
            }
        }
        const evaluation = (0, contracts_1.evaluateDualScan)({
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
            if ((0, contracts_1.isValidInventoryStateTransition)(item.status, nextStatus)) {
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
    async createCarton(request) {
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
    async getCarton(cartonId) {
        const carton = await this.repository.findCartonById(cartonId);
        if (!carton)
            return undefined;
        return this.mapToContractCarton(carton);
    }
    /**
     * Atomically finalizes the packing operation.
     */
    async completePacking(request) {
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
        }
        catch (err) {
            const errMessage = err.message || 'PACKING_VALIDATION_FAILED';
            return {
                success: false,
                errorCode: errMessage || 'PACKING_VALIDATION_FAILED',
                errorMessage: `Packing failed: ${errMessage}`,
                packedAt: new Date().toISOString(),
            };
        }
    }
    async getPackingHistory(limit = 50, offset = 0) {
        const rows = await this.repository.getPackingHistory(limit, offset);
        return rows.map((r) => this.mapToContractPackagingRecord(r));
    }
    // ── Helper Mappers ───────────────────────────────────────────────────
    mapToContractInventoryItem(dbItem) {
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
    mapToContractCarton(dbCarton) {
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
    mapToContractPackagingRecord(dbRecord) {
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
    async listInventoryItems(filters) {
        const items = await this.repository.listInventoryItems(filters);
        return items.map((i) => this.mapToContractInventoryItem(i));
    }
    async listCartons(filters) {
        const cartons = await this.repository.listCartons(filters);
        return cartons.map((c) => this.mapToContractCarton(c));
    }
    async listQcRecords(filters) {
        return this.repository.listQcRecords(filters);
    }
    async recordQcOperation(data) {
        return this.repository.recordDualScanVerification({
            id: `qc_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
            stationId: data.stationId,
            operatorUserId: data.operatorUserId || 'operator_qc',
            deviceId: data.deviceId,
            serialNumber: data.serialNumber,
            scannedQrToken: data.scannedQrToken || 'tok_manual_qc',
            scannedQrUri: data.scannedQrUri || `eh://p/v1?t=tok_manual_qc`,
            isMatch: data.isMatch,
            verificationStatus: data.verificationStatus,
            rejectionReason: data.rejectionReason || null,
            verifiedAt: new Date(),
        });
    }
    async adjustInventory(deviceId, status, notes) {
        const updated = await this.repository.adjustInventory(deviceId, status, notes);
        return updated ? this.mapToContractInventoryItem(updated) : null;
    }
}
exports.InventoryService = InventoryService;
//# sourceMappingURL=inventory.service.js.map