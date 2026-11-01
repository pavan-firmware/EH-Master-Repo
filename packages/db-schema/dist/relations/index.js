"use strict";
/**
 * EH Home Drizzle ORM Relations Definitions
 * Maps relational graphs between core domain models.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.packagingRecordsRelations = exports.dualScanVerificationsRelations = exports.inventoryItemsRelations = exports.packagingCartonsRelations = exports.firmwareHardwareCompatibilityRelations = exports.firmwareArtifactsRelations = exports.firmwareBuildsRelations = exports.firmwareFamiliesRelations = exports.productVariantHardwareCompatibilityRelations = exports.componentSubstitutionsRelations = exports.bomItemsRelations = exports.bomSpecificationsRelations = exports.hardwareRevisionsRelations = exports.deviceAuthorizationsRelations = exports.devicesRelations = exports.productVariantsRelations = exports.productsRelations = exports.productFamiliesRelations = exports.roomsRelations = exports.floorsRelations = exports.homeMembershipsRelations = exports.homesRelations = exports.userProfilesRelations = exports.usersRelations = void 0;
const drizzle_orm_1 = require("drizzle-orm");
const auth_identity_1 = require("../schema/auth-identity");
const home_topology_1 = require("../schema/home-topology");
const product_catalog_1 = require("../schema/product-catalog");
const device_identity_state_1 = require("../schema/device-identity-state");
const automations_scenes_1 = require("../schema/automations-scenes");
const notifications_alerts_1 = require("../schema/notifications-alerts");
const hardware_bom_1 = require("../schema/hardware-bom");
const fleet_ota_1 = require("../schema/fleet-ota");
const firmware_build_1 = require("../schema/firmware-build");
const inventory_packing_1 = require("../schema/inventory-packing");
// ── Users Relations ──────────────────────────────────────────────────
exports.usersRelations = (0, drizzle_orm_1.relations)(auth_identity_1.users, ({ one, many }) => ({
    profile: one(auth_identity_1.userProfiles, {
        fields: [auth_identity_1.users.id],
        references: [auth_identity_1.userProfiles.id],
    }),
    refreshTokens: many(auth_identity_1.refreshTokens),
    memberships: many(auth_identity_1.homeMemberships),
    ownedHomes: many(home_topology_1.homes),
    notifications: many(notifications_alerts_1.notifications),
    pushTokens: many(notifications_alerts_1.pushDeviceTokens),
}));
// ── User Profiles Relations ──────────────────────────────────────────
exports.userProfilesRelations = (0, drizzle_orm_1.relations)(auth_identity_1.userProfiles, ({ one }) => ({
    user: one(auth_identity_1.users, {
        fields: [auth_identity_1.userProfiles.id],
        references: [auth_identity_1.users.id],
    }),
}));
// ── Homes Relations ──────────────────────────────────────────────────
exports.homesRelations = (0, drizzle_orm_1.relations)(home_topology_1.homes, ({ one, many }) => ({
    owner: one(auth_identity_1.users, {
        fields: [home_topology_1.homes.ownerId],
        references: [auth_identity_1.users.id],
    }),
    memberships: many(auth_identity_1.homeMemberships),
    floors: many(home_topology_1.floors),
    rooms: many(home_topology_1.rooms),
    deviceAuthorizations: many(device_identity_state_1.deviceAuthorizations),
    scenes: many(automations_scenes_1.scenes),
    automations: many(automations_scenes_1.automations),
    schedules: many(automations_scenes_1.schedules),
}));
// ── Home Memberships Relations ───────────────────────────────────────
exports.homeMembershipsRelations = (0, drizzle_orm_1.relations)(auth_identity_1.homeMemberships, ({ one }) => ({
    home: one(home_topology_1.homes, {
        fields: [auth_identity_1.homeMemberships.homeId],
        references: [home_topology_1.homes.id],
    }),
    user: one(auth_identity_1.users, {
        fields: [auth_identity_1.homeMemberships.userId],
        references: [auth_identity_1.users.id],
    }),
}));
// ── Floors & Rooms Relations ─────────────────────────────────────────
exports.floorsRelations = (0, drizzle_orm_1.relations)(home_topology_1.floors, ({ one, many }) => ({
    home: one(home_topology_1.homes, {
        fields: [home_topology_1.floors.homeId],
        references: [home_topology_1.homes.id],
    }),
    rooms: many(home_topology_1.rooms),
}));
exports.roomsRelations = (0, drizzle_orm_1.relations)(home_topology_1.rooms, ({ one, many }) => ({
    home: one(home_topology_1.homes, {
        fields: [home_topology_1.rooms.homeId],
        references: [home_topology_1.homes.id],
    }),
    floor: one(home_topology_1.floors, {
        fields: [home_topology_1.rooms.floorId],
        references: [home_topology_1.floors.id],
    }),
    deviceAuthorizations: many(device_identity_state_1.deviceAuthorizations),
}));
// ── Product Catalog Relations ────────────────────────────────────────
exports.productFamiliesRelations = (0, drizzle_orm_1.relations)(product_catalog_1.productFamilies, ({ many }) => ({
    products: many(product_catalog_1.products),
}));
exports.productsRelations = (0, drizzle_orm_1.relations)(product_catalog_1.products, ({ one, many }) => ({
    family: one(product_catalog_1.productFamilies, {
        fields: [product_catalog_1.products.familyId],
        references: [product_catalog_1.productFamilies.id],
    }),
    variants: many(product_catalog_1.productVariants),
}));
exports.productVariantsRelations = (0, drizzle_orm_1.relations)(product_catalog_1.productVariants, ({ one, many }) => ({
    product: one(product_catalog_1.products, {
        fields: [product_catalog_1.productVariants.productId],
        references: [product_catalog_1.products.id],
    }),
    devices: many(device_identity_state_1.devices),
    capabilities: many(product_catalog_1.productCapabilities),
    images: many(product_catalog_1.productImages),
}));
// ── Devices Relations ────────────────────────────────────────────────
exports.devicesRelations = (0, drizzle_orm_1.relations)(device_identity_state_1.devices, ({ one, many }) => ({
    productVariant: one(product_catalog_1.productVariants, {
        fields: [device_identity_state_1.devices.productVariantId],
        references: [product_catalog_1.productVariants.id],
    }),
    credentials: one(device_identity_state_1.deviceCredentials, {
        fields: [device_identity_state_1.devices.id],
        references: [device_identity_state_1.deviceCredentials.deviceId],
    }),
    authorization: one(device_identity_state_1.deviceAuthorizations, {
        fields: [device_identity_state_1.devices.id],
        references: [device_identity_state_1.deviceAuthorizations.deviceId],
    }),
    state: one(device_identity_state_1.deviceState, {
        fields: [device_identity_state_1.devices.id],
        references: [device_identity_state_1.deviceState.deviceId],
    }),
    networkIdentity: one(device_identity_state_1.networkIdentity, {
        fields: [device_identity_state_1.devices.id],
        references: [device_identity_state_1.networkIdentity.deviceId],
    }),
    channelStates: many(device_identity_state_1.channelState),
    commands: many(device_identity_state_1.deviceCommands),
    events: many(device_identity_state_1.deviceEvents),
}));
exports.deviceAuthorizationsRelations = (0, drizzle_orm_1.relations)(device_identity_state_1.deviceAuthorizations, ({ one }) => ({
    device: one(device_identity_state_1.devices, {
        fields: [device_identity_state_1.deviceAuthorizations.deviceId],
        references: [device_identity_state_1.devices.id],
    }),
    home: one(home_topology_1.homes, {
        fields: [device_identity_state_1.deviceAuthorizations.homeId],
        references: [home_topology_1.homes.id],
    }),
    room: one(home_topology_1.rooms, {
        fields: [device_identity_state_1.deviceAuthorizations.roomId],
        references: [home_topology_1.rooms.id],
    }),
    claimedBy: one(auth_identity_1.users, {
        fields: [device_identity_state_1.deviceAuthorizations.claimedByUserId],
        references: [auth_identity_1.users.id],
    }),
}));
// ── Hardware & BOM Relations ──────────────────────────────────────────
exports.hardwareRevisionsRelations = (0, drizzle_orm_1.relations)(hardware_bom_1.hardwareRevisions, ({ one, many }) => ({
    productVariant: one(product_catalog_1.productVariants, {
        fields: [hardware_bom_1.hardwareRevisions.productVariantId],
        references: [product_catalog_1.productVariants.id],
    }),
    boms: many(hardware_bom_1.bomSpecifications),
    compatibilities: many(hardware_bom_1.productVariantHardwareCompatibility),
}));
exports.bomSpecificationsRelations = (0, drizzle_orm_1.relations)(hardware_bom_1.bomSpecifications, ({ one, many }) => ({
    hardwareRevision: one(hardware_bom_1.hardwareRevisions, {
        fields: [hardware_bom_1.bomSpecifications.hardwareRevisionId],
        references: [hardware_bom_1.hardwareRevisions.id],
    }),
    items: many(hardware_bom_1.bomItems),
}));
exports.bomItemsRelations = (0, drizzle_orm_1.relations)(hardware_bom_1.bomItems, ({ one, many }) => ({
    bom: one(hardware_bom_1.bomSpecifications, {
        fields: [hardware_bom_1.bomItems.bomId],
        references: [hardware_bom_1.bomSpecifications.id],
    }),
    substitutions: many(hardware_bom_1.componentSubstitutions),
}));
exports.componentSubstitutionsRelations = (0, drizzle_orm_1.relations)(hardware_bom_1.componentSubstitutions, ({ one }) => ({
    bomItem: one(hardware_bom_1.bomItems, {
        fields: [hardware_bom_1.componentSubstitutions.bomItemId],
        references: [hardware_bom_1.bomItems.id],
    }),
}));
exports.productVariantHardwareCompatibilityRelations = (0, drizzle_orm_1.relations)(hardware_bom_1.productVariantHardwareCompatibility, ({ one }) => ({
    productVariant: one(product_catalog_1.productVariants, {
        fields: [hardware_bom_1.productVariantHardwareCompatibility.productVariantId],
        references: [product_catalog_1.productVariants.id],
    }),
    hardwareRevision: one(hardware_bom_1.hardwareRevisions, {
        fields: [hardware_bom_1.productVariantHardwareCompatibility.hardwareRevisionId],
        references: [hardware_bom_1.hardwareRevisions.id],
    }),
}));
// ── Firmware Management Relations (Part 07) ───────────────────────────
exports.firmwareFamiliesRelations = (0, drizzle_orm_1.relations)(firmware_build_1.firmwareFamilies, ({ many }) => ({
    builds: many(firmware_build_1.firmwareBuilds),
}));
exports.firmwareBuildsRelations = (0, drizzle_orm_1.relations)(firmware_build_1.firmwareBuilds, ({ one, many }) => ({
    family: one(firmware_build_1.firmwareFamilies, {
        fields: [firmware_build_1.firmwareBuilds.firmwareFamilyId],
        references: [firmware_build_1.firmwareFamilies.id],
    }),
    release: one(fleet_ota_1.firmwareReleases, {
        fields: [firmware_build_1.firmwareBuilds.firmwareReleaseId],
        references: [fleet_ota_1.firmwareReleases.id],
    }),
    artifacts: many(firmware_build_1.firmwareArtifacts),
}));
exports.firmwareArtifactsRelations = (0, drizzle_orm_1.relations)(firmware_build_1.firmwareArtifacts, ({ one }) => ({
    build: one(firmware_build_1.firmwareBuilds, {
        fields: [firmware_build_1.firmwareArtifacts.buildId],
        references: [firmware_build_1.firmwareBuilds.id],
    }),
}));
exports.firmwareHardwareCompatibilityRelations = (0, drizzle_orm_1.relations)(firmware_build_1.firmwareHardwareCompatibility, ({ one }) => ({
    release: one(fleet_ota_1.firmwareReleases, {
        fields: [firmware_build_1.firmwareHardwareCompatibility.firmwareReleaseId],
        references: [fleet_ota_1.firmwareReleases.id],
    }),
    hardwareRevision: one(hardware_bom_1.hardwareRevisions, {
        fields: [firmware_build_1.firmwareHardwareCompatibility.hardwareRevisionId],
        references: [hardware_bom_1.hardwareRevisions.id],
    }),
}));
// ── Inventory & Packaging Relations (Part 11) ──────────────────────────
exports.packagingCartonsRelations = (0, drizzle_orm_1.relations)(inventory_packing_1.packagingCartons, ({ one, many }) => ({
    productVariant: one(product_catalog_1.productVariants, {
        fields: [inventory_packing_1.packagingCartons.productVariantId],
        references: [product_catalog_1.productVariants.id],
    }),
    items: many(inventory_packing_1.inventoryItems),
    packagingRecords: many(inventory_packing_1.packagingRecords),
}));
exports.inventoryItemsRelations = (0, drizzle_orm_1.relations)(inventory_packing_1.inventoryItems, ({ one }) => ({
    device: one(device_identity_state_1.devices, {
        fields: [inventory_packing_1.inventoryItems.deviceId],
        references: [device_identity_state_1.devices.id],
    }),
    productVariant: one(product_catalog_1.productVariants, {
        fields: [inventory_packing_1.inventoryItems.productVariantId],
        references: [product_catalog_1.productVariants.id],
    }),
    carton: one(inventory_packing_1.packagingCartons, {
        fields: [inventory_packing_1.inventoryItems.cartonId],
        references: [inventory_packing_1.packagingCartons.id],
    }),
}));
exports.dualScanVerificationsRelations = (0, drizzle_orm_1.relations)(inventory_packing_1.dualScanVerifications, ({ one, many }) => ({
    device: one(device_identity_state_1.devices, {
        fields: [inventory_packing_1.dualScanVerifications.deviceId],
        references: [device_identity_state_1.devices.id],
    }),
    carton: one(inventory_packing_1.packagingCartons, {
        fields: [inventory_packing_1.dualScanVerifications.cartonId],
        references: [inventory_packing_1.packagingCartons.id],
    }),
    packagingRecords: many(inventory_packing_1.packagingRecords),
}));
exports.packagingRecordsRelations = (0, drizzle_orm_1.relations)(inventory_packing_1.packagingRecords, ({ one }) => ({
    device: one(device_identity_state_1.devices, {
        fields: [inventory_packing_1.packagingRecords.deviceId],
        references: [device_identity_state_1.devices.id],
    }),
    productVariant: one(product_catalog_1.productVariants, {
        fields: [inventory_packing_1.packagingRecords.productVariantId],
        references: [product_catalog_1.productVariants.id],
    }),
    carton: one(inventory_packing_1.packagingCartons, {
        fields: [inventory_packing_1.packagingRecords.cartonId],
        references: [inventory_packing_1.packagingCartons.id],
    }),
    verification: one(inventory_packing_1.dualScanVerifications, {
        fields: [inventory_packing_1.packagingRecords.verificationId],
        references: [inventory_packing_1.dualScanVerifications.id],
    }),
}));
//# sourceMappingURL=index.js.map