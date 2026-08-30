'use strict';

/**
 * EH Home — HTTP Server Bootstrap & Process Lifecycle (Phase 13)
 *
 * Exposes createServer() factory function and handles HTTP listener lifecycle,
 * production pre-flight validation, and graceful shutdown.
 */

const http = require('http');
const { createApp } = require('./app');
const { validateProductionConfig } = require('./config/production-config-validator');

/**
 * Create an HTTP server instance around an application handler
 *
 * @param {Object} [appInstance] - Application instance from createApp()
 * @param {Object} [options]
 * @returns {http.Server}
 */
function createServer(appInstance = null, options = {}) {
  // Enforce production config pre-flight validation
  validateProductionConfig(process.env, {
    throwOnFailure: process.env.NODE_ENV === 'production'
  });

  const app = appInstance || createApp(options);
  const server = http.createServer((req, res) => app.handleRequest(req, res));
  server.appInstance = app;
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
        const { mqttTransport } = server.appInstance.services;
        if (mqttTransport && typeof mqttTransport.disconnect === 'function') {
          try {
            await mqttTransport.disconnect();
            console.log('[EH Home Server] MQTT transport disconnected cleanly.');
          } catch (mErr) {
            console.warn('[EH Home Server] Error disconnecting MQTT transport:', mErr.message);
          }
        }
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
      console.log(`[EH Home Backend] Health check available at http://${host}:${port}/health`);
    });
  } catch (err) {
    console.error(`[EH Home Backend Startup Failed]:`, err.message);
    process.exit(1);
  }
}

module.exports = { createServer, setupGracefulShutdown };
