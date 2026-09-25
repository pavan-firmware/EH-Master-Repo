'use strict';

/**
 * EH Home — HTTP Server Bootstrap & Process Lifecycle (Phase 13 & Phase 34)
 *
 * Exposes createServer() factory function and handles HTTP listener lifecycle,
 * production pre-flight validation, deterministic lifecycle states, and graceful shutdown.
 */

const fs = require('fs');
const path = require('path');
const http = require('http');

// Auto-load .env configuration if present
function loadEnv() {
  const candidates = [
    path.resolve(process.cwd(), '.env'),
    path.resolve(__dirname, '../../.env'),
    path.resolve(__dirname, '../.env')
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) {
      try {
        const content = fs.readFileSync(p, 'utf8');
        for (const line of content.split(/\r?\n/)) {
          const trimmed = line.trim();
          if (!trimmed || trimmed.startsWith('#')) continue;
          const eq = trimmed.indexOf('=');
          if (eq > 0) {
            const key = trimmed.slice(0, eq).trim();
            const val = trimmed.slice(eq + 1).trim();
            if (!process.env[key]) {
              process.env[key] = val;
            }
          }
        }
      } catch (_) {}
      break;
    }
  }
}
loadEnv();

const { createApp } = require('./app');
const { loadAndValidateConfig } = require('./config/runtime-config');

/**
 * Create an HTTP server instance around an application handler
 *
 * @param {Object} [appInstance] - Application instance from createApp()
 * @param {Object} [options]
 * @returns {http.Server}
 */
function createServer(appInstance = null, options = {}) {
  // Enforce production config pre-flight validation
  const validation = loadAndValidateConfig(process.env, {
    throwOnFailure: process.env.NODE_ENV === 'production'
  });

  const appOpts = {
    ...options,
    config: validation.config
  };

  const app = appInstance || createApp(appOpts);

  // Advance lifecycle state from UNINITIALIZED to READY (or DEGRADED)
  if (app.services && app.services.operationalReadinessService) {
    app.services.operationalReadinessService.setLifecycleState('READY', 'Server initialized and ready to serve traffic');
  }

  const server = http.createServer((req, res) => app.handleRequest(req, res));
  server.appInstance = app;
  server.runtimeConfig = validation.config;
  return server;
}

/**
 * Setup graceful shutdown listeners for the server process
 *
 * @param {http.Server} server
 * @param {number} [timeoutMs=10000]
 */
function setupGracefulShutdown(server, timeoutMs = 10000) {
  let isShuttingDown = false;

  async function shutdown(signal) {
    if (isShuttingDown) return;
    isShuttingDown = true;
    console.log(`\n[EH Home Server] Received ${signal}. Starting graceful shutdown...`);

    // Transition lifecycle to SHUTTING_DOWN so readiness probes fail immediately
    if (server.appInstance && server.appInstance.services && server.appInstance.services.operationalReadinessService) {
      server.appInstance.services.operationalReadinessService.setLifecycleState('SHUTTING_DOWN', `Process received ${signal}`);
    }

    const forceExitTimeout = setTimeout(() => {
      console.error('[EH Home Server] Forced shutdown due to timeout.');
      process.exit(1);
    }, timeoutMs);
    forceExitTimeout.unref();

    server.close(async (err) => {
      if (err) {
        console.error('[EH Home Server] Error while closing HTTP server:', err.message);
      } else {
        console.log('[EH Home Server] HTTP server closed.');
      }

      // Disconnect background services if present
      if (server.appInstance && server.appInstance.services) {
        const { mqttTransport, db } = server.appInstance.services;
        if (mqttTransport && typeof mqttTransport.disconnect === 'function') {
          try {
            await mqttTransport.disconnect();
            console.log('[EH Home Server] MQTT transport disconnected cleanly.');
          } catch (mErr) {
            console.warn('[EH Home Server] Error disconnecting MQTT transport:', mErr.message);
          }
        }

        if (db && typeof db.close === 'function') {
          try {
            await db.close();
            console.log('[EH Home Server] Database connection closed cleanly.');
          } catch (dbErr) {
            console.warn('[EH Home Server] Error closing database connection:', dbErr.message);
          }
        }
      }

      if (server.appInstance && server.appInstance.services && server.appInstance.services.operationalReadinessService) {
        server.appInstance.services.operationalReadinessService.setLifecycleState('TERMINATED', 'Graceful shutdown completed');
      }

      clearTimeout(forceExitTimeout);
      console.log('[EH Home Server] Graceful shutdown complete.');
      process.exit(0);
    });
  }

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

async function seedDevelopmentData(app) {
  try {
    const repos = app.repositories;
    const db = (app.db || (app.services && app.services.db));
    if (!repos || !db) return;
    const { productRepo, deviceRepo, deviceStateRepo, homeRepo, userRepo, roomRepo } = repos;
    const crypto = require('crypto');

    function makePasswordHash(pwd) {
      const salt = crypto.randomBytes(16).toString('hex');
      const hash = crypto.pbkdf2Sync(pwd, salt, 100000, 64, 'sha256').toString('hex');
      return `pbkdf2:sha256:100000:${salt}:${hash}`;
    }

    // 1. Ensure Product Catalog
    try {
      await productRepo.createFamily({ id: 'fam-switches', name: 'EH Smart Switches', description: 'Smart switches' });
      await productRepo.createProduct({ id: 'prod-sw3x', familyId: 'fam-switches', name: 'Smart Switch 3X', description: '3-Channel Switch' });
      await productRepo.createVariant({
        id: 'eh-smart-switch-3x',
        productId: 'prod-sw3x',
        name: '3X',
        skuCode: 'EH-SW3X',
        channelCount: 3,
        hardwareCapabilities: [],
        supportedFirmwareFamilies: ['esp32-switch-platform', 'esp32c6-switch-platform']
      });
    } catch (_) {}

    // 2. Ensure Primary User (chandra77807@gmail.com / 12345678)
    let user = null;
    try {
      user = await userRepo.findByEmail('chandra77807@gmail.com');
      if (!user) {
        user = await userRepo.createUser({
          id: '41fa1669-438e-4dac-a81b-2807ba460f7f',
          email: 'chandra77807@gmail.com',
          passwordHash: makePasswordHash('12345678'),
          emailVerified: true
        });
      } else {
        // Ensure password is always valid
        const passwordHash = makePasswordHash('12345678');
        await db.update('users', user.id, { password_hash: passwordHash, email_verified: true });
      }

      // Upsert profile
      await db.upsert('user_profiles', user.id, {
        full_name: 'Pavan',
        phone_number: null,
        avatar_url: null,
        timezone: 'Asia/Kolkata'
      });
    } catch (uErr) {
      console.warn('[EH Home Server] User seed notice:', uErr.message);
    }

    // 3. Ensure Admin User (admin@eh.com / admin123)
    try {
      let adminUser = await userRepo.findByEmail('admin@eh.com');
      if (!adminUser) {
        await userRepo.createUser({
          id: '00000000-0000-0000-0000-000000000001',
          email: 'admin@eh.com',
          passwordHash: makePasswordHash('admin123'),
          emailVerified: true
        });
      }
    } catch (_) {}

    // 4. Ensure Home for chandra77807@gmail.com
    let home = null;
    try {
      const ownerId = user ? user.id : '41fa1669-438e-4dac-a81b-2807ba460f7f';
      const userHomes = await db.find('homes', h => h.owner_id === ownerId || h.ownerId === ownerId);
      if (userHomes && userHomes.length > 0) {
        home = userHomes[0];
      } else {
        home = await homeRepo.createHome({
          id: '00000000-0000-0000-0000-000000000002',
          name: "Pavan's Home",
          ownerId: ownerId
        });
      }
    } catch (hErr) {
      console.warn('[EH Home Server] Home seed notice:', hErr.message);
    }

    // 5. Ensure Default Rooms
    let livingRoomId = null;
    if (home && roomRepo) {
      try {
        const homeRooms = await roomRepo.listRoomsByHome(home.id);
        if (homeRooms.length === 0) {
          const lr = await roomRepo.createRoom({ homeId: home.id, name: 'Living Room', iconKey: 'living-room', sortOrder: 0 });
          livingRoomId = lr.id;
          await roomRepo.createRoom({ homeId: home.id, name: 'Bedroom', iconKey: 'bedroom', sortOrder: 1 });
          await roomRepo.createRoom({ homeId: home.id, name: 'Kitchen', iconKey: 'kitchen', sortOrder: 2 });
        } else {
          livingRoomId = homeRooms[0].id;
        }
      } catch (_) {}
    }

    // 6. Ensure Physical ESP32 Switch Registration & Claim
    const physicalEsp32Id = 'ce196211-91cf-496a-9403-709d8589eb15';
    try {
      const existingDev = await deviceRepo.getDevice(physicalEsp32Id);
      if (!existingDev) {
        await deviceRepo.registerDevice({
          deviceId: physicalEsp32Id,
          serialNumber: 'EH-SOCK3X-PHYSICAL-01',
          productVariantId: 'eh-smart-socket-3x',
          hardwareRevision: 'HW_1_0',
          firmwareFamily: 'esp32-socket-platform',
          firmwareVersion: '1.0.0'
        });
      }
      if (home) {
        const auth = await deviceRepo.getDeviceAuthorization(physicalEsp32Id);
        if (!auth) {
          await deviceRepo.claimDevice({
            deviceId: physicalEsp32Id,
            homeId: home.id,
            customName: 'Smart Socket 3X',
            claimedByUserId: home.owner_id || (user ? user.id : '41fa1669-438e-4dac-a81b-2807ba460f7f'),
            roomId: livingRoomId || null
          });
        }
      }
      const existingState = await deviceStateRepo.getFullState(physicalEsp32Id);
      if (!existingState) {
        await deviceStateRepo.updateDeviceConnection(physicalEsp32Id, 'OFFLINE');
      }
    } catch (_) {}
    console.log('[EH Home Server] Dev database successfully verified & seeded for chandra77807@gmail.com.');
  } catch (err) {
    console.warn('[EH Home Server] Dev seed skipped:', err.message);
  }
}

// Start server automatically if executed directly (e.g., node backend/src/server.js)
if (require.main === module) {
  if (!process.env.DB_ADAPTER) {
    process.env.DB_ADAPTER = 'postgres';
  }
  if (!process.env.DATABASE_URL) {
    process.env.DATABASE_URL = 'postgresql://eh_admin:eh_development_password_only@localhost:5432/eh_home_dev';
  }

  const port = process.env.PORT || 3000;
  const host = process.env.HOST || '0.0.0.0';

  (async () => {
    try {
      const server = createServer();
      const appDb = (server.appInstance && (server.appInstance.db || (server.appInstance.services && server.appInstance.services.db)));
      if (appDb && typeof appDb.connect === 'function') {
        await appDb.connect();
      }
      setupGracefulShutdown(server);

      if (process.env.NODE_ENV !== 'production' && server.appInstance) {
        await seedDevelopmentData(server.appInstance);
      }

      process.on('uncaughtException', (err) => {
        console.error('[EH Home Backend] Uncaught exception:', err);
      });
      process.on('unhandledRejection', (reason) => {
        console.error('[EH Home Backend] Unhandled rejection:', reason);
      });

      if (process.stdin.isTTY === false) {
        try { process.stdin.resume(); } catch (_) {}
      }
      setInterval(() => {}, 1000 * 60 * 60);

      server.listen(port, host, () => {
        console.log(`[EH Home Backend] Server running in ${process.env.NODE_ENV || 'development'} mode at http://${host}:${port}/`);
        console.log(`[EH Home Backend] Database connected: ${process.env.DB_ADAPTER} (${process.env.DATABASE_URL.replace(/:[^:@]+@/, ':***@')})`);
        console.log(`[EH Home Backend] Liveness check available at http://${host}:${port}/api/v1/health/liveness`);
        console.log(`[EH Home Backend] Readiness check available at http://${host}:${port}/api/v1/health/readiness`);
      });
    } catch (err) {
      console.error(`[EH Home Backend Startup Failed]:`, err.message);
      process.exit(1);
    }
  })();
}

module.exports = { createServer, setupGracefulShutdown };
