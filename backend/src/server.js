'use strict';

/**
 * EH Home — HTTP Server Bootstrap (Phase 7A)
 *
 * Exposes createServer() factory function and handles HTTP listener lifecycle.
 */

const http = require('http');
const { createApp } = require('./app');

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
  const port = process.env.PORT || 3000;
  const host = process.env.HOST || '0.0.0.0';

  const server = createServer();
  server.listen(port, host, () => {
    console.log(`[EH Home Backend] Server running at http://${host}:${port}/`);
    console.log(`[EH Home Backend] Health check available at http://${host}:${port}/health`);
  });
}

module.exports = { createServer };
