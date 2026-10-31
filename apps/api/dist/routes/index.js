"use strict";
/**
 * EH Home API Routes Registration
 * Mounts operational endpoints and versioned application namespaces.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.registerRoutes = void 0;
const health_1 = require("../plugins/health");
const system_routes_1 = require("../modules/system/system.routes");
const product_routes_1 = require("../modules/products/product.routes");
const hardware_routes_1 = require("../modules/hardware/hardware.routes");
const firmware_routes_1 = require("../modules/firmware/firmware.routes");
const inventory_routes_1 = require("../modules/inventory/inventory.routes");
const telemetry_routes_1 = require("../modules/telemetry/telemetry.routes");
const command_routes_1 = require("../modules/commands/command.routes");
const ota_routes_1 = require("../modules/ota/ota.routes");
const security_routes_1 = require("../modules/security/security.routes");
const audit_routes_1 = require("../modules/audit/audit.routes");
const storage_routes_1 = require("../modules/storage/storage.routes");
const backup_routes_1 = require("../modules/backup/backup.routes");
const registerRoutes = async (app) => {
    // 1. Root Operational Endpoints (/health, /ready)
    await app.register(health_1.healthRoutes);
    // 2. Versioned API Namespace (/api/v1/*)
    await app.register(async (v1) => {
        // System & Operational Diagnostics
        await v1.register(system_routes_1.systemRoutes, { prefix: '/system' });
        // Product & Design Management Catalog
        await v1.register(product_routes_1.productRoutes, { prefix: '/products' });
        // Hardware & BOM Management
        await v1.register(hardware_routes_1.hardwareRoutes, { prefix: '/hardware' });
        // Firmware, Git & Binary Management
        await v1.register(firmware_routes_1.firmwareRoutes, { prefix: '/firmware' });
        // Manufacturing Inventory, Dual-Scan & Packing
        await v1.register(inventory_routes_1.inventoryRoutes, { prefix: '/inventory' });
        // Telemetry Ingestion & Time-Series History
        await v1.register(telemetry_routes_1.telemetryRoutes, { prefix: '/telemetry' });
        // Device Commands, State & Availability
        await v1.register(command_routes_1.commandRoutes, { prefix: '/devices' });
        // Signed OTA Manifests, Eligibility & Jobs
        await v1.register(ota_routes_1.otaRoutes, { prefix: '/ota' });
        // RBAC, Security & Identity Authorization (Part 14)
        await v1.register(security_routes_1.securityRoutes, { prefix: '/security' });
        // Security Audit Trail & Observability (Part 14)
        await v1.register(audit_routes_1.auditRoutes, { prefix: '/audit' });
        // S3-Compatible Object Storage (Part 16)
        await v1.register(storage_routes_1.storageRoutes, { prefix: '/storage' });
        // Database Backup, Verification & Recovery (Part 16)
        await v1.register(backup_routes_1.backupRoutes, { prefix: '/backups' });
    }, { prefix: '/api/v1' });
};
exports.registerRoutes = registerRoutes;
//# sourceMappingURL=index.js.map