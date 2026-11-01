/**
 * EH Home — Part 13 Live EMQX Integration Test Runner
 * 
 * Usage:
 *   node scripts/test-emqx-live.js
 */

const { spawn } = require('child_process');
const path = require('path');

const testPath = path.resolve(__dirname, '../apps/api/tests/emqx-live-integration.test.js');
const child = spawn(process.execPath, [testPath], { stdio: 'inherit' });

child.on('close', (code) => {
  process.exit(code || 0);
});
