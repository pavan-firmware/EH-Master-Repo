import { z } from 'zod';
import { SchemaVersionSchema, HardwareRevisionCodeSchema, MacAddressSchema, SerialNumberSchema } from '../common';

export const DeviceLifecycleStateSchema = z.enum([
  'CREATED',
  'PROGRAMMED',
  'TESTING',
  'TEST_PASSED',
  'TEST_FAILED',
  'QC_APPROVED',
  'QR_ASSIGNED',
  'LABEL_PRINTED',
  'PACKING_SCANNED',
  'PACKED',
  'INVENTORY_STOCKED',
  'SHIPPED',
  'ACTIVATED',
  'DECOMMISSIONED'
]);
export type DeviceLifecycleState = z.infer<typeof DeviceLifecycleStateSchema>;

export const DeviceIdentitySchema = z.object({
  schemaVersion: SchemaVersionSchema,
  deviceId: z.string().uuid(),
  serialNumber: SerialNumberSchema,
  productVariantId: z.string().regex(/^eh-[a-z0-9-]+$/),
  hardwareRevision: HardwareRevisionCodeSchema,
  firmwareFamily: z.string().regex(/^[a-z0-9-]+$/)
});
export type DeviceIdentity = z.infer<typeof DeviceIdentitySchema>;

export const DeviceHardwareRecordSchema = z.object({
  schemaVersion: SchemaVersionSchema,
  deviceId: z.string().uuid(),
  serialNumber: SerialNumberSchema,
  macAddress: MacAddressSchema,
  productVariantId: z.string().min(1),
  hardwareRevision: HardwareRevisionCodeSchema,
  firmwareFamily: z.string().min(1),
  firmwareVersion: z.string().min(1),
  batchId: z.string().uuid().optional(),
  lifecycleState: DeviceLifecycleStateSchema.default('CREATED'),
  manufacturedAt: z.string().datetime().optional(),
  createdAt: z.string().datetime()
});
export type DeviceHardwareRecord = z.infer<typeof DeviceHardwareRecordSchema>;

export const CredentialStateSchema = z.enum([
  'FACTORY',
  'PROVISIONED',
  'CLAIMED',
  'ACTIVE',
  'ROTATED',
  'REVOKED',
  'RESET'
]);
export type CredentialState = z.infer<typeof CredentialStateSchema>;

export const DeviceCredentialSchema = z.object({
  schemaVersion: SchemaVersionSchema,
  deviceId: z.string().uuid(),
  mqttUsername: z.string().min(1),
  mqttPasswordHash: z.string().min(1),
  tlsClientCertFingerprint: z.string().nullable().optional(),
  localSessionKeyHash: z.string().min(1),
  credentialState: CredentialStateSchema,
  createdAt: z.string().datetime(),
  rotatedAt: z.string().datetime().nullable().optional()
});
export type DeviceCredential = z.infer<typeof DeviceCredentialSchema>;

export const ConnectionStateSchema = z.enum(['ONLINE', 'STALE', 'OFFLINE']);
export type ConnectionState = z.infer<typeof ConnectionStateSchema>;

export const DeviceStateSchema = z.object({
  schemaVersion: SchemaVersionSchema,
  deviceId: z.string().uuid(),
  connectionState: ConnectionStateSchema.default('OFFLINE'),
  lastSeenAt: z.string().datetime().nullable().optional(),
  lastCommandId: z.string().nullable().optional(),
  lastEventId: z.string().nullable().optional(),
  updatedAt: z.string().datetime()
});
export type DeviceState = z.infer<typeof DeviceStateSchema>;
