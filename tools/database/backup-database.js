'use strict';

/**
 * EH Home — Database Backup & Integrity Check Tool (Phase 13)
 *
 * Backs up database state to a timestamped archive with SHA-256 integrity checksum.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function createBackup(dbClient, outputDir = path.join(__dirname, '..', '..', 'backups')) {
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupFilename = `eh_home_backup_${timestamp}.json`;
  const backupPath = path.join(outputDir, backupFilename);

  const dump = {
    version: '1.0.0',
    createdAt: new Date().toISOString(),
    tables: {}
  };

  if (dbClient && dbClient.tables) {
    for (const [tableName, mapData] of dbClient.tables.entries()) {
      dump.tables[tableName] = Array.from(mapData.values());
    }
  }

  const content = JSON.stringify(dump, null, 2);
  const hash = crypto.createHash('sha256').update(content).digest('hex');

  fs.writeFileSync(backupPath, content, 'utf8');
  fs.writeFileSync(`${backupPath}.sha256`, `${hash}  ${backupFilename}\n`, 'utf8');

  return {
    backupPath,
    checksum: hash,
    filename: backupFilename,
    tableCount: Object.keys(dump.tables).length
  };
}

module.exports = { createBackup };
