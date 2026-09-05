'use strict';

/**
 * EH Home — HTTP Server Bootstrap & Process Lifecycle (Phase 13 & Phase 34)
 *
 * Exposes createServer() factory function and handles HTTP listener lifecycle,
 * production pre-flight validation, deterministic lifecycle states, and graceful shutdown.
 */

const http = require('http');
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

// Start server automatically if executed directly (e.g., node backend/src/server.js)
if (require.main === module) {
  const port = process.env.PORT || 3000;
  const host = process.env.HOST || '0.0.0.0';

  try {
    const server = createServer();
    setupGracefulShutdown(server);

    server.listen(port, host, () => {
      console.log(`[EH Home Backend] Server running in ${process.env.NODE_ENV || 'development'} mode at http://${host}:${port}/`);
      console.log(`[EH Home Backend] Liveness check available at http://${host}:${port}/api/v1/health/liveness`);
      console.log(`[EH Home Backend] Readiness check available at http://${host}:${port}/api/v1/health/readiness`);
    });
  } catch (err) {
    console.error(`[EH Home Backend Startup Failed]:`, err.message);
    process.exit(1);
  }
}

module.exports = { createServer, setupGracefulShutdown };
