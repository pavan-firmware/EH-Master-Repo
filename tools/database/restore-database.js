'use strict';

/**
 * EH Home — Database Restore & Verification Tool (Phase 13)
 *
 * Validates backup checksum and restores tables into an isolated DatabaseClient instance.
 */

const fs = require('fs');
const crypto = require('crypto');

function restoreBackup(backupPath, targetDbClient) {
  if (!fs.existsSync(backupPath)) {
    throw new Error(`Backup file does not exist: ${backupPath}`);
  }

  const content = fs.readFileSync(backupPath, 'utf8');

  // Verify checksum if .sha256 file exists
  if (fs.existsSync(`${backupPath}.sha256`)) {
    const expectedHash = fs.readFileSync(`${backupPath}.sha256`, 'utf8').trim().split(/\s+/)[0];
    const actualHash = crypto.createHash('sha256').update(content).digest('hex');
    if (expectedHash !== actualHash) {
      throw new Error(`Backup checksum mismatch! Expected: ${expectedHash}, Actual: ${actualHash}`);
    }
  }

  const dump = JSON.parse(content);
  let totalRowsRestored = 0;

  for (const [tableName, rows] of Object.entries(dump.tables || {})) {
    const targetMap = targetDbClient.getTable(tableName);
    targetMap.clear();
    for (const row of rows) {
      targetMap.set(row.id, row);
      totalRowsRestored++;
    }
  }

  return {
    success: true,
    totalRowsRestored,
    tableCount: Object.keys(dump.tables || {}).length,
    backupCreatedAt: dump.createdAt
  };
}

module.exports = { restoreBackup };
