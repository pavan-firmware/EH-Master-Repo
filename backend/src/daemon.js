'use strict';

const { spawn } = require('child_process');
const path = require('path');

const serverScript = path.join(__dirname, 'server.js');

function startServer() {
  console.log('[EH Daemon] Spawning backend server process...');
  const child = spawn(process.execPath, [serverScript], {
    cwd: path.join(__dirname, '..', '..'),
    env: process.env,
    stdio: 'inherit'
  });

  child.on('exit', (code, signal) => {
    console.warn(`[EH Daemon] Server exited with code ${code}, signal ${signal}. Restarting in 2s...`);
    setTimeout(startServer, 2000);
  });

  child.on('error', (err) => {
    console.error('[EH Daemon] Failed to start server:', err);
    setTimeout(startServer, 2000);
  });
}

startServer();
