'use strict';

/**
 * EH Home — HTTP Server Bootstrap (Phase 7A)
 *
 * Exposes createServer() factory function and handles HTTP listener lifecycle.
 */

const http = require('http');
const { createApp } = require('./app');
const { config } = require('./shared/config');

/**
 * Create an HTTP server instance around an application handler
 *
 * @param {Object} [appInstance] - Application instance from createApp()
 * @param {Object} [options]
 * @returns {http.Server}
 */
function createServer(appInstance = null, options = {}) {
  const app = appInstance || createApp(options);
  const server = http.createServer((req, res) => app.handleRequest(req, res));
  server.appInstance = app;
  return server;
}

// Start server automatically if executed directly (e.g., node backend/src/server.js)
if (require.main === module) {
  const port = config.port;
  const host = config.host;

  const server = createServer();
  server.listen(port, host, () => {
    console.log(`[EH Home Backend] (${config.env}) Server running at http://${host}:${port}/`);
    console.log(`[EH Home Backend] Health check available at http://${host}:${port}/health`);
  });
}

module.exports = { createServer };
