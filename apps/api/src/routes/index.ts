/**
 * EH Home API Routes Registration
 * Mounts operational endpoints and versioned application namespaces.
 */

import { FastifyInstance, FastifyPluginAsync } from 'fastify';
import { healthRoutes } from '../plugins/health';
import { systemRoutes } from '../modules/system/system.routes';
import { productRoutes } from '../modules/products/product.routes';
import { hardwareRoutes } from '../modules/hardware/hardware.routes';
import { firmwareRoutes } from '../modules/firmware/firmware.routes';
import { inventoryRoutes } from '../modules/inventory/inventory.routes';
import { telemetryRoutes } from '../modules/telemetry/telemetry.routes';
import { commandRoutes } from '../modules/commands/command.routes';
import { otaRoutes } from '../modules/ota/ota.routes';
import { securityRoutes } from '../modules/security/security.routes';
import { auditRoutes } from '../modules/audit/audit.routes';
import { storageRoutes } from '../modules/storage/storage.routes';
import { backupRoutes } from '../modules/backup/backup.routes';

export const registerRoutes: FastifyPluginAsync = async (app: FastifyInstance) => {
  // 1. Root Operational Endpoints (/health, /ready)
  await app.register(healthRoutes);

  // 2. Versioned API Namespace (/api/v1/*)
  await app.register(
    async (v1) => {
      // System & Operational Diagnostics
      await v1.register(systemRoutes, { prefix: '/system' });

      // Product & Design Management Catalog
      await v1.register(productRoutes, { prefix: '/products' });

      // Hardware & BOM Management
      await v1.register(hardwareRoutes, { prefix: '/hardware' });

      // Firmware, Git & Binary Management
      await v1.register(firmwareRoutes, { prefix: '/firmware' });

      // Manufacturing Inventory, Dual-Scan & Packing
      await v1.register(inventoryRoutes, { prefix: '/inventory' });

      // Telemetry Ingestion & Time-Series History
      await v1.register(telemetryRoutes, { prefix: '/telemetry' });

      // Device Commands, State & Availability
      await v1.register(commandRoutes, { prefix: '/devices' });

      // Signed OTA Manifests, Eligibility & Jobs
      await v1.register(otaRoutes, { prefix: '/ota' });

      // RBAC, Security & Identity Authorization (Part 14)
      await v1.register(securityRoutes, { prefix: '/security' });

      // Security Audit Trail & Observability (Part 14)
      await v1.register(auditRoutes, { prefix: '/audit' });

      // S3-Compatible Object Storage (Part 16)
      await v1.register(storageRoutes, { prefix: '/storage' });

      // Database Backup, Verification & Recovery (Part 16)
      await v1.register(backupRoutes, { prefix: '/backups' });
    },
    { prefix: '/api/v1' }
  );
};

