/**
 * EH Home Drizzle ORM Relations Definitions
 * Maps relational graphs between core domain models.
 */

import { relations } from 'drizzle-orm';
import { users, refreshTokens, userProfiles, homeMemberships } from '../schema/auth-identity';
import { homes, floors, rooms } from '../schema/home-topology';
import { productFamilies, products, productVariants, productCapabilities, productImages } from '../schema/product-catalog';
import {
  devices,
  deviceCredentials,
  deviceAuthorizations,
  deviceState,
  channelState,
  deviceCommands,
  deviceEvents,
  networkIdentity
} from '../schema/device-identity-state';
import { scenes, automations, schedules } from '../schema/automations-scenes';
import { notifications, pushDeviceTokens } from '../schema/notifications-alerts';
import {
  hardwareRevisions,
  bomSpecifications,
  bomItems,
  componentSubstitutions,
  productVariantHardwareCompatibility
} from '../schema/hardware-bom';
import { firmwareReleases } from '../schema/fleet-ota';
import {
  firmwareFamilies,
  firmwareBuilds,
  firmwareArtifacts,
  firmwareHardwareCompatibility
} from '../schema/firmware-build';
import {
  packagingCartons,
  inventoryItems,
  dualScanVerifications,
  packagingRecords
} from '../schema/inventory-packing';


// ── Users Relations ──────────────────────────────────────────────────
export const usersRelations = relations(users, ({ one, many }) => ({
  profile: one(userProfiles, {
    fields: [users.id],
    references: [userProfiles.id],
  }),
  refreshTokens: many(refreshTokens),
  memberships: many(homeMemberships),
  ownedHomes: many(homes),
  notifications: many(notifications),
  pushTokens: many(pushDeviceTokens),
}));

// ── User Profiles Relations ──────────────────────────────────────────
export const userProfilesRelations = relations(userProfiles, ({ one }) => ({
  user: one(users, {
    fields: [userProfiles.id],
    references: [users.id],
  }),
}));

// ── Homes Relations ──────────────────────────────────────────────────
export const homesRelations = relations(homes, ({ one, many }) => ({
  owner: one(users, {
    fields: [homes.ownerId],
    references: [users.id],
  }),
  memberships: many(homeMemberships),
  floors: many(floors),
  rooms: many(rooms),
  deviceAuthorizations: many(deviceAuthorizations),
  scenes: many(scenes),
  automations: many(automations),
  schedules: many(schedules),
}));

// ── Home Memberships Relations ───────────────────────────────────────
export const homeMembershipsRelations = relations(homeMemberships, ({ one }) => ({
  home: one(homes, {
    fields: [homeMemberships.homeId],
    references: [homes.id],
  }),
  user: one(users, {
    fields: [homeMemberships.userId],
    references: [users.id],
  }),
}));

// ── Floors & Rooms Relations ─────────────────────────────────────────
export const floorsRelations = relations(floors, ({ one, many }) => ({
  home: one(homes, {
    fields: [floors.homeId],
    references: [homes.id],
  }),
  rooms: many(rooms),
}));

export const roomsRelations = relations(rooms, ({ one, many }) => ({
  home: one(homes, {
    fields: [rooms.homeId],
    references: [homes.id],
  }),
  floor: one(floors, {
    fields: [rooms.floorId],
    references: [floors.id],
  }),
  deviceAuthorizations: many(deviceAuthorizations),
}));

// ── Product Catalog Relations ────────────────────────────────────────
export const productFamiliesRelations = relations(productFamilies, ({ many }) => ({
  products: many(products),
}));

export const productsRelations = relations(products, ({ one, many }) => ({
  family: one(productFamilies, {
    fields: [products.familyId],
    references: [productFamilies.id],
  }),
  variants: many(productVariants),
}));

export const productVariantsRelations = relations(productVariants, ({ one, many }) => ({
  product: one(products, {
    fields: [productVariants.productId],
    references: [products.id],
  }),
  devices: many(devices),
  capabilities: many(productCapabilities),
  images: many(productImages),
}));

// ── Devices Relations ────────────────────────────────────────────────
export const devicesRelations = relations(devices, ({ one, many }) => ({
  productVariant: one(productVariants, {
    fields: [devices.productVariantId],
    references: [productVariants.id],
  }),
  credentials: one(deviceCredentials, {
    fields: [devices.id],
    references: [deviceCredentials.deviceId],
  }),
  authorization: one(deviceAuthorizations, {
    fields: [devices.id],
    references: [deviceAuthorizations.deviceId],
  }),
  state: one(deviceState, {
    fields: [devices.id],
    references: [deviceState.deviceId],
  }),
  networkIdentity: one(networkIdentity, {
    fields: [devices.id],
    references: [networkIdentity.deviceId],
  }),
  channelStates: many(channelState),
  commands: many(deviceCommands),
  events: many(deviceEvents),
}));

export const deviceAuthorizationsRelations = relations(deviceAuthorizations, ({ one }) => ({
  device: one(devices, {
    fields: [deviceAuthorizations.deviceId],
    references: [devices.id],
  }),
  home: one(homes, {
    fields: [deviceAuthorizations.homeId],
    references: [homes.id],
  }),
  room: one(rooms, {
    fields: [deviceAuthorizations.roomId],
    references: [rooms.id],
  }),
  claimedBy: one(users, {
    fields: [deviceAuthorizations.claimedByUserId],
    references: [users.id],
  }),
}));

// ── Hardware & BOM Relations ──────────────────────────────────────────
export const hardwareRevisionsRelations = relations(hardwareRevisions, ({ one, many }) => ({
  productVariant: one(productVariants, {
    fields: [hardwareRevisions.productVariantId],
    references: [productVariants.id],
  }),
  boms: many(bomSpecifications),
  compatibilities: many(productVariantHardwareCompatibility),
}));

export const bomSpecificationsRelations = relations(bomSpecifications, ({ one, many }) => ({
  hardwareRevision: one(hardwareRevisions, {
    fields: [bomSpecifications.hardwareRevisionId],
    references: [hardwareRevisions.id],
  }),
  items: many(bomItems),
}));

export const bomItemsRelations = relations(bomItems, ({ one, many }) => ({
  bom: one(bomSpecifications, {
    fields: [bomItems.bomId],
    references: [bomSpecifications.id],
  }),
  substitutions: many(componentSubstitutions),
}));

export const componentSubstitutionsRelations = relations(componentSubstitutions, ({ one }) => ({
  bomItem: one(bomItems, {
    fields: [componentSubstitutions.bomItemId],
    references: [bomItems.id],
  }),
}));

export const productVariantHardwareCompatibilityRelations = relations(productVariantHardwareCompatibility, ({ one }) => ({
  productVariant: one(productVariants, {
    fields: [productVariantHardwareCompatibility.productVariantId],
    references: [productVariants.id],
  }),
  hardwareRevision: one(hardwareRevisions, {
    fields: [productVariantHardwareCompatibility.hardwareRevisionId],
    references: [hardwareRevisions.id],
  }),
}));

// ── Firmware Management Relations (Part 07) ───────────────────────────
export const firmwareFamiliesRelations = relations(firmwareFamilies, ({ many }) => ({
  builds: many(firmwareBuilds),
}));

export const firmwareBuildsRelations = relations(firmwareBuilds, ({ one, many }) => ({
  family: one(firmwareFamilies, {
    fields: [firmwareBuilds.firmwareFamilyId],
    references: [firmwareFamilies.id],
  }),
  release: one(firmwareReleases, {
    fields: [firmwareBuilds.firmwareReleaseId],
    references: [firmwareReleases.id],
  }),
  artifacts: many(firmwareArtifacts),
}));

export const firmwareArtifactsRelations = relations(firmwareArtifacts, ({ one }) => ({
  build: one(firmwareBuilds, {
    fields: [firmwareArtifacts.buildId],
    references: [firmwareBuilds.id],
  }),
}));

export const firmwareHardwareCompatibilityRelations = relations(firmwareHardwareCompatibility, ({ one }) => ({
  release: one(firmwareReleases, {
    fields: [firmwareHardwareCompatibility.firmwareReleaseId],
    references: [firmwareReleases.id],
  }),
  hardwareRevision: one(hardwareRevisions, {
    fields: [firmwareHardwareCompatibility.hardwareRevisionId],
    references: [hardwareRevisions.id],
  }),
}));

// ── Inventory & Packaging Relations (Part 11) ──────────────────────────
export const packagingCartonsRelations = relations(packagingCartons, ({ one, many }) => ({
  productVariant: one(productVariants, {
    fields: [packagingCartons.productVariantId],
    references: [productVariants.id],
  }),
  items: many(inventoryItems),
  packagingRecords: many(packagingRecords),
}));

export const inventoryItemsRelations = relations(inventoryItems, ({ one }) => ({
  device: one(devices, {
    fields: [inventoryItems.deviceId],
    references: [devices.id],
  }),
  productVariant: one(productVariants, {
    fields: [inventoryItems.productVariantId],
    references: [productVariants.id],
  }),
  carton: one(packagingCartons, {
    fields: [inventoryItems.cartonId],
    references: [packagingCartons.id],
  }),
}));

export const dualScanVerificationsRelations = relations(dualScanVerifications, ({ one, many }) => ({
  device: one(devices, {
    fields: [dualScanVerifications.deviceId],
    references: [devices.id],
  }),
  carton: one(packagingCartons, {
    fields: [dualScanVerifications.cartonId],
    references: [packagingCartons.id],
  }),
  packagingRecords: many(packagingRecords),
}));

export const packagingRecordsRelations = relations(packagingRecords, ({ one }) => ({
  device: one(devices, {
    fields: [packagingRecords.deviceId],
    references: [devices.id],
  }),
  productVariant: one(productVariants, {
    fields: [packagingRecords.productVariantId],
    references: [productVariants.id],
  }),
  carton: one(packagingCartons, {
    fields: [packagingRecords.cartonId],
    references: [packagingCartons.id],
  }),
  verification: one(dualScanVerifications, {
    fields: [packagingRecords.verificationId],
    references: [dualScanVerifications.id],
  }),
}));


