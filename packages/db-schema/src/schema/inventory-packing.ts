/**
 * EH Home Schema — inventory-packing
 * Source: PostgreSQL Migration 033_production_inventory_packing.sql
 */
import { boolean, integer, pgTable, text, timestamp, varchar } from 'drizzle-orm/pg-core';
import { devices } from './device-identity-state';
import { productVariants } from './product-catalog';


// --- packaging_cartons (033_production_inventory_packing.sql) ---
export const packagingCartons = pgTable('packaging_cartons', {
  id: varchar('id', { length: 128 }).primaryKey(),
  cartonCode: varchar('carton_code', { length: 128 }).notNull().unique(),
  productVariantId: varchar('product_variant_id', { length: 128 }).notNull().references(() => productVariants.id),
  hardwareRevision: varchar('hardware_revision', { length: 32 }).notNull(),
  targetCapacity: integer('target_capacity').notNull().default(1),
  packedCount: integer('packed_count').notNull().default(0),
  status: varchar('status', { length: 32 }).notNull().default('OPEN'),
  sealedAt: timestamp('sealed_at', { withTimezone: true }),
  operatorUserId: varchar('operator_user_id', { length: 128 }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type PackagingCarton = typeof packagingCartons.$inferSelect;
export type NewPackagingCarton = typeof packagingCartons.$inferInsert;

// --- inventory_items (033_production_inventory_packing.sql) ---
export const inventoryItems = pgTable('inventory_items', {
  id: varchar('id', { length: 128 }).primaryKey(),
  deviceId: varchar('device_id', { length: 128 }).notNull().unique().references(() => devices.id),
  serialNumber: varchar('serial_number', { length: 128 }).notNull().unique().references(() => devices.serialNumber),
  productVariantId: varchar('product_variant_id', { length: 128 }).notNull().references(() => productVariants.id),
  hardwareRevision: varchar('hardware_revision', { length: 32 }).notNull(),
  firmwareFamily: varchar('firmware_family', { length: 64 }).notNull(),
  firmwareVersion: varchar('firmware_version', { length: 32 }).notNull(),
  traceId: varchar('trace_id', { length: 128 }).notNull(),
  status: varchar('status', { length: 32 }).notNull().default('PROVISIONED'),
  cartonId: varchar('carton_id', { length: 128 }).references(() => packagingCartons.id),
  qrToken: varchar('qr_token', { length: 64 }),
  qrUri: varchar('qr_uri', { length: 255 }),
  qcStatus: varchar('qc_status', { length: 32 }).notNull().default('PASS'),
  registeredAt: timestamp('registered_at', { withTimezone: true }).notNull().defaultNow(),
  verifiedAt: timestamp('verified_at', { withTimezone: true }),
  packedAt: timestamp('packed_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type InventoryItem = typeof inventoryItems.$inferSelect;
export type NewInventoryItem = typeof inventoryItems.$inferInsert;

// --- dual_scan_verifications (033_production_inventory_packing.sql) ---
export const dualScanVerifications = pgTable('dual_scan_verifications', {
  id: varchar('id', { length: 128 }).primaryKey(),
  deviceId: varchar('device_id', { length: 128 }).notNull().references(() => devices.id),
  serialNumber: varchar('serial_number', { length: 128 }).notNull(),
  scannedQrToken: varchar('scanned_qr_token', { length: 64 }).notNull(),
  scannedQrUri: varchar('scanned_qr_uri', { length: 255 }).notNull(),
  cartonId: varchar('carton_id', { length: 128 }).references(() => packagingCartons.id),
  isMatch: boolean('is_match').notNull(),
  verificationStatus: varchar('verification_status', { length: 32 }).notNull(),
  rejectionReason: text('rejection_reason'),
  stationId: varchar('station_id', { length: 64 }).notNull(),
  operatorUserId: varchar('operator_user_id', { length: 128 }),
  verifiedAt: timestamp('verified_at', { withTimezone: true }).notNull().defaultNow(),
});

export type DualScanVerification = typeof dualScanVerifications.$inferSelect;
export type NewDualScanVerification = typeof dualScanVerifications.$inferInsert;

// --- packaging_records (033_production_inventory_packing.sql) ---
export const packagingRecords = pgTable('packaging_records', {
  id: varchar('id', { length: 128 }).primaryKey(),
  traceId: varchar('trace_id', { length: 128 }).notNull(),
  deviceId: varchar('device_id', { length: 128 }).notNull().references(() => devices.id),
  serialNumber: varchar('serial_number', { length: 128 }).notNull(),
  productVariantId: varchar('product_variant_id', { length: 128 }).notNull().references(() => productVariants.id),
  hardwareRevision: varchar('hardware_revision', { length: 32 }).notNull(),
  firmwareFamily: varchar('firmware_family', { length: 64 }).notNull(),
  firmwareVersion: varchar('firmware_version', { length: 32 }).notNull(),
  cartonId: varchar('carton_id', { length: 128 }).notNull().references(() => packagingCartons.id),
  verificationId: varchar('verification_id', { length: 128 }).notNull().references(() => dualScanVerifications.id),
  stationId: varchar('station_id', { length: 64 }).notNull(),
  operatorUserId: varchar('operator_user_id', { length: 128 }),
  packedAt: timestamp('packed_at', { withTimezone: true }).notNull().defaultNow(),
  notes: text('notes'),
});

export type PackagingRecord = typeof packagingRecords.$inferSelect;
export type NewPackagingRecord = typeof packagingRecords.$inferInsert;
