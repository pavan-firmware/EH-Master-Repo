"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.packagingRecords = exports.dualScanVerifications = exports.inventoryItems = exports.packagingCartons = void 0;
/**
 * EH Home Schema — inventory-packing
 * Source: PostgreSQL Migration 033_production_inventory_packing.sql
 */
const pg_core_1 = require("drizzle-orm/pg-core");
const device_identity_state_1 = require("./device-identity-state");
const product_catalog_1 = require("./product-catalog");
// --- packaging_cartons (033_production_inventory_packing.sql) ---
exports.packagingCartons = (0, pg_core_1.pgTable)('packaging_cartons', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    cartonCode: (0, pg_core_1.varchar)('carton_code', { length: 128 }).notNull().unique(),
    productVariantId: (0, pg_core_1.varchar)('product_variant_id', { length: 128 }).notNull().references(() => product_catalog_1.productVariants.id),
    hardwareRevision: (0, pg_core_1.varchar)('hardware_revision', { length: 32 }).notNull(),
    targetCapacity: (0, pg_core_1.integer)('target_capacity').notNull().default(1),
    packedCount: (0, pg_core_1.integer)('packed_count').notNull().default(0),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('OPEN'),
    sealedAt: (0, pg_core_1.timestamp)('sealed_at', { withTimezone: true }),
    operatorUserId: (0, pg_core_1.varchar)('operator_user_id', { length: 128 }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- inventory_items (033_production_inventory_packing.sql) ---
exports.inventoryItems = (0, pg_core_1.pgTable)('inventory_items', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 128 }).notNull().unique().references(() => device_identity_state_1.devices.id),
    serialNumber: (0, pg_core_1.varchar)('serial_number', { length: 128 }).notNull().unique().references(() => device_identity_state_1.devices.serialNumber),
    productVariantId: (0, pg_core_1.varchar)('product_variant_id', { length: 128 }).notNull().references(() => product_catalog_1.productVariants.id),
    hardwareRevision: (0, pg_core_1.varchar)('hardware_revision', { length: 32 }).notNull(),
    firmwareFamily: (0, pg_core_1.varchar)('firmware_family', { length: 64 }).notNull(),
    firmwareVersion: (0, pg_core_1.varchar)('firmware_version', { length: 32 }).notNull(),
    traceId: (0, pg_core_1.varchar)('trace_id', { length: 128 }).notNull(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('PROVISIONED'),
    cartonId: (0, pg_core_1.varchar)('carton_id', { length: 128 }).references(() => exports.packagingCartons.id),
    qrToken: (0, pg_core_1.varchar)('qr_token', { length: 64 }),
    qrUri: (0, pg_core_1.varchar)('qr_uri', { length: 255 }),
    qcStatus: (0, pg_core_1.varchar)('qc_status', { length: 32 }).notNull().default('PASS'),
    registeredAt: (0, pg_core_1.timestamp)('registered_at', { withTimezone: true }).notNull().defaultNow(),
    verifiedAt: (0, pg_core_1.timestamp)('verified_at', { withTimezone: true }),
    packedAt: (0, pg_core_1.timestamp)('packed_at', { withTimezone: true }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- dual_scan_verifications (033_production_inventory_packing.sql) ---
exports.dualScanVerifications = (0, pg_core_1.pgTable)('dual_scan_verifications', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 128 }).notNull().references(() => device_identity_state_1.devices.id),
    serialNumber: (0, pg_core_1.varchar)('serial_number', { length: 128 }).notNull(),
    scannedQrToken: (0, pg_core_1.varchar)('scanned_qr_token', { length: 64 }).notNull(),
    scannedQrUri: (0, pg_core_1.varchar)('scanned_qr_uri', { length: 255 }).notNull(),
    cartonId: (0, pg_core_1.varchar)('carton_id', { length: 128 }).references(() => exports.packagingCartons.id),
    isMatch: (0, pg_core_1.boolean)('is_match').notNull(),
    verificationStatus: (0, pg_core_1.varchar)('verification_status', { length: 32 }).notNull(),
    rejectionReason: (0, pg_core_1.text)('rejection_reason'),
    stationId: (0, pg_core_1.varchar)('station_id', { length: 64 }).notNull(),
    operatorUserId: (0, pg_core_1.varchar)('operator_user_id', { length: 128 }),
    verifiedAt: (0, pg_core_1.timestamp)('verified_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- packaging_records (033_production_inventory_packing.sql) ---
exports.packagingRecords = (0, pg_core_1.pgTable)('packaging_records', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    traceId: (0, pg_core_1.varchar)('trace_id', { length: 128 }).notNull(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 128 }).notNull().references(() => device_identity_state_1.devices.id),
    serialNumber: (0, pg_core_1.varchar)('serial_number', { length: 128 }).notNull(),
    productVariantId: (0, pg_core_1.varchar)('product_variant_id', { length: 128 }).notNull().references(() => product_catalog_1.productVariants.id),
    hardwareRevision: (0, pg_core_1.varchar)('hardware_revision', { length: 32 }).notNull(),
    firmwareFamily: (0, pg_core_1.varchar)('firmware_family', { length: 64 }).notNull(),
    firmwareVersion: (0, pg_core_1.varchar)('firmware_version', { length: 32 }).notNull(),
    cartonId: (0, pg_core_1.varchar)('carton_id', { length: 128 }).notNull().references(() => exports.packagingCartons.id),
    verificationId: (0, pg_core_1.varchar)('verification_id', { length: 128 }).notNull().references(() => exports.dualScanVerifications.id),
    stationId: (0, pg_core_1.varchar)('station_id', { length: 64 }).notNull(),
    operatorUserId: (0, pg_core_1.varchar)('operator_user_id', { length: 128 }),
    packedAt: (0, pg_core_1.timestamp)('packed_at', { withTimezone: true }).notNull().defaultNow(),
    notes: (0, pg_core_1.text)('notes'),
});
//# sourceMappingURL=inventory-packing.js.map