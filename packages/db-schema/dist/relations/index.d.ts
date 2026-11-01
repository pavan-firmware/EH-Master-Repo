/**
 * EH Home Drizzle ORM Relations Definitions
 * Maps relational graphs between core domain models.
 */
export declare const usersRelations: import("drizzle-orm").Relations<"users", {
    profile: import("drizzle-orm").One<"user_profiles", true>;
    refreshTokens: import("drizzle-orm").Many<"refresh_tokens">;
    memberships: import("drizzle-orm").Many<"home_memberships">;
    ownedHomes: import("drizzle-orm").Many<"homes">;
    notifications: import("drizzle-orm").Many<"notifications">;
    pushTokens: import("drizzle-orm").Many<"push_device_tokens">;
}>;
export declare const userProfilesRelations: import("drizzle-orm").Relations<"user_profiles", {
    user: import("drizzle-orm").One<"users", true>;
}>;
export declare const homesRelations: import("drizzle-orm").Relations<"homes", {
    owner: import("drizzle-orm").One<"users", true>;
    memberships: import("drizzle-orm").Many<"home_memberships">;
    floors: import("drizzle-orm").Many<"floors">;
    rooms: import("drizzle-orm").Many<"rooms">;
    deviceAuthorizations: import("drizzle-orm").Many<"device_authorizations">;
    scenes: import("drizzle-orm").Many<"scenes">;
    automations: import("drizzle-orm").Many<"automations">;
    schedules: import("drizzle-orm").Many<"schedules">;
}>;
export declare const homeMembershipsRelations: import("drizzle-orm").Relations<"home_memberships", {
    home: import("drizzle-orm").One<"homes", true>;
    user: import("drizzle-orm").One<"users", true>;
}>;
export declare const floorsRelations: import("drizzle-orm").Relations<"floors", {
    home: import("drizzle-orm").One<"homes", true>;
    rooms: import("drizzle-orm").Many<"rooms">;
}>;
export declare const roomsRelations: import("drizzle-orm").Relations<"rooms", {
    home: import("drizzle-orm").One<"homes", true>;
    floor: import("drizzle-orm").One<"floors", false>;
    deviceAuthorizations: import("drizzle-orm").Many<"device_authorizations">;
}>;
export declare const productFamiliesRelations: import("drizzle-orm").Relations<"product_families", {
    products: import("drizzle-orm").Many<"products">;
}>;
export declare const productsRelations: import("drizzle-orm").Relations<"products", {
    family: import("drizzle-orm").One<"product_families", true>;
    variants: import("drizzle-orm").Many<"product_variants">;
}>;
export declare const productVariantsRelations: import("drizzle-orm").Relations<"product_variants", {
    product: import("drizzle-orm").One<"products", true>;
    devices: import("drizzle-orm").Many<"devices">;
    capabilities: import("drizzle-orm").Many<"product_capabilities">;
    images: import("drizzle-orm").Many<"product_images">;
}>;
export declare const devicesRelations: import("drizzle-orm").Relations<"devices", {
    productVariant: import("drizzle-orm").One<"product_variants", true>;
    credentials: import("drizzle-orm").One<"device_credentials", true>;
    authorization: import("drizzle-orm").One<"device_authorizations", true>;
    state: import("drizzle-orm").One<"device_state", true>;
    networkIdentity: import("drizzle-orm").One<"network_identity", true>;
    channelStates: import("drizzle-orm").Many<"channel_state">;
    commands: import("drizzle-orm").Many<"device_commands">;
    events: import("drizzle-orm").Many<"device_events">;
}>;
export declare const deviceAuthorizationsRelations: import("drizzle-orm").Relations<"device_authorizations", {
    device: import("drizzle-orm").One<"devices", true>;
    home: import("drizzle-orm").One<"homes", true>;
    room: import("drizzle-orm").One<"rooms", false>;
    claimedBy: import("drizzle-orm").One<"users", true>;
}>;
export declare const hardwareRevisionsRelations: import("drizzle-orm").Relations<"hardware_revisions", {
    productVariant: import("drizzle-orm").One<"product_variants", true>;
    boms: import("drizzle-orm").Many<"bom_specifications">;
    compatibilities: import("drizzle-orm").Many<"product_variant_hardware_compatibility">;
}>;
export declare const bomSpecificationsRelations: import("drizzle-orm").Relations<"bom_specifications", {
    hardwareRevision: import("drizzle-orm").One<"hardware_revisions", true>;
    items: import("drizzle-orm").Many<"bom_items">;
}>;
export declare const bomItemsRelations: import("drizzle-orm").Relations<"bom_items", {
    bom: import("drizzle-orm").One<"bom_specifications", true>;
    substitutions: import("drizzle-orm").Many<"component_substitutions">;
}>;
export declare const componentSubstitutionsRelations: import("drizzle-orm").Relations<"component_substitutions", {
    bomItem: import("drizzle-orm").One<"bom_items", true>;
}>;
export declare const productVariantHardwareCompatibilityRelations: import("drizzle-orm").Relations<"product_variant_hardware_compatibility", {
    productVariant: import("drizzle-orm").One<"product_variants", true>;
    hardwareRevision: import("drizzle-orm").One<"hardware_revisions", true>;
}>;
export declare const firmwareFamiliesRelations: import("drizzle-orm").Relations<"firmware_families", {
    builds: import("drizzle-orm").Many<"firmware_builds">;
}>;
export declare const firmwareBuildsRelations: import("drizzle-orm").Relations<"firmware_builds", {
    family: import("drizzle-orm").One<"firmware_families", true>;
    release: import("drizzle-orm").One<"firmware_releases", false>;
    artifacts: import("drizzle-orm").Many<"firmware_artifacts">;
}>;
export declare const firmwareArtifactsRelations: import("drizzle-orm").Relations<"firmware_artifacts", {
    build: import("drizzle-orm").One<"firmware_builds", true>;
}>;
export declare const firmwareHardwareCompatibilityRelations: import("drizzle-orm").Relations<"firmware_hardware_compatibility", {
    release: import("drizzle-orm").One<"firmware_releases", true>;
    hardwareRevision: import("drizzle-orm").One<"hardware_revisions", true>;
}>;
export declare const packagingCartonsRelations: import("drizzle-orm").Relations<"packaging_cartons", {
    productVariant: import("drizzle-orm").One<"product_variants", true>;
    items: import("drizzle-orm").Many<"inventory_items">;
    packagingRecords: import("drizzle-orm").Many<"packaging_records">;
}>;
export declare const inventoryItemsRelations: import("drizzle-orm").Relations<"inventory_items", {
    device: import("drizzle-orm").One<"devices", true>;
    productVariant: import("drizzle-orm").One<"product_variants", true>;
    carton: import("drizzle-orm").One<"packaging_cartons", false>;
}>;
export declare const dualScanVerificationsRelations: import("drizzle-orm").Relations<"dual_scan_verifications", {
    device: import("drizzle-orm").One<"devices", true>;
    carton: import("drizzle-orm").One<"packaging_cartons", false>;
    packagingRecords: import("drizzle-orm").Many<"packaging_records">;
}>;
export declare const packagingRecordsRelations: import("drizzle-orm").Relations<"packaging_records", {
    device: import("drizzle-orm").One<"devices", true>;
    productVariant: import("drizzle-orm").One<"product_variants", true>;
    carton: import("drizzle-orm").One<"packaging_cartons", true>;
    verification: import("drizzle-orm").One<"dual_scan_verifications", true>;
}>;
//# sourceMappingURL=index.d.ts.map