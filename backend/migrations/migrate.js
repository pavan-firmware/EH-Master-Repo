'use strict';

/**
 * EH Home — Database Migration Runner (Phase 37)
 *
 * Implements:
 * 1. Deterministic, ordered migration execution (001 to 026+)
 * 2. Atomic tracking via `schema_migrations` table
 * 3. PostgreSQL advisory locking to prevent concurrent migration races
 * 4. SHA-256 checksum verification & drift detection
 * 5. Production downgrade safety invariant (down strictly forbidden in production)
 * 6. CLI commands: up, status, validate, down
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { createDatabaseClient } = require('../src/shared/db-client');

const ADVISORY_LOCK_ID = 2026090637;
const MIGRATIONS_DIR = __dirname;

function computeChecksum(content) {
  // Normalize line endings to avoid cross-platform CRLF/LF drift
  const normalized = content.replace(/\r\n/g, '\n').trim();
  return crypto.createHash('sha256').update(normalized).digest('hex');
}

class MigrationRunner {
  /**
   * @param {Object} [opts={}]
   * @param {Object} [opts.db] - Database client or adapter
   * @param {string} [opts.migrationsDir] - Custom migrations directory path
   */
  constructor(opts = {}) {
    this.db = opts.db || createDatabaseClient();
    this.migrationsDir = opts.migrationsDir || MIGRATIONS_DIR;
  }

  /**
   * Get sorted list of all up migration files from disk
   * @returns {Array<{ version: string, filename: string, filepath: string, downFilepath: string|null, checksum: string }>}
   */
  getMigrationFiles() {
    const files = fs.readdirSync(this.migrationsDir);
    const upFiles = files.filter(f => f.endsWith('.sql') && !f.endsWith('.down.sql'));

    // Sort numerically / alphabetically by prefix (e.g. 001_, 002_, ...)
    upFiles.sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));

    return upFiles.map(filename => {
      const filepath = path.join(this.migrationsDir, filename);
      const content = fs.readFileSync(filepath, 'utf8');
      const version = filename.split('_')[0];

      const downFilename = filename.replace(/\.sql$/, '.down.sql');
      const downFilepath = path.join(this.migrationsDir, downFilename);
      const hasDown = fs.existsSync(downFilepath);

      return {
        version,
        filename,
        filepath,
        downFilepath: hasDown ? downFilepath : null,
        checksum: computeChecksum(content)
      };
    });
  }

  /**
   * Ensure schema_migrations table exists
   */
  async ensureMigrationTable() {
    const createTableSql = `
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version VARCHAR(64) PRIMARY KEY,
        filename VARCHAR(255) NOT NULL,
        checksum VARCHAR(64) NOT NULL,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `;
    try {
      await this.db.query(createTableSql);
    } catch (_) {
      // In-memory adapter will ensure table via its table registry
    }
  }

  /**
   * Acquire PostgreSQL advisory lock (no-op on in-memory)
   */
  async acquireLock() {
    try {
      await this.db.query('SELECT pg_advisory_lock($1)', [ADVISORY_LOCK_ID]);
    } catch (_) {
      // No-op if underlying database does not support advisory locks
    }
  }

  /**
   * Release PostgreSQL advisory lock
   */
  async releaseLock() {
    try {
      await this.db.query('SELECT pg_advisory_unlock($1)', [ADVISORY_LOCK_ID]);
    } catch (_) {
      // No-op
    }
  }

  /**
   * Get applied migrations from database
   * @returns {Promise<Map<string, { version: string, filename: string, checksum: string, applied_at: string }>>}
   */
  async getAppliedMigrations() {
    await this.ensureMigrationTable();
    const appliedMap = new Map();

    try {
      const rows = await this.db.find('schema_migrations');
      if (rows && rows.length > 0) {
        for (const row of rows) {
          appliedMap.set(row.version, row);
        }
        return appliedMap;
      }
    } catch (_) {}

    try {
      const res = await this.db.query('SELECT version, filename, checksum, applied_at FROM schema_migrations ORDER BY version ASC');
      if (res && res.rows && res.rows.length > 0) {
        for (const row of res.rows) {
          appliedMap.set(row.version, row);
        }
      }
    } catch (_) {}

    return appliedMap;
  }

  /**
   * Get migration status
   */
  async getStatus() {
    const diskMigrations = this.getMigrationFiles();
    const appliedMap = await this.getAppliedMigrations();

    const statusList = [];
    let hasDrift = false;

    for (const m of diskMigrations) {
      const applied = appliedMap.get(m.version);
      let status = 'PENDING';
      let drift = false;

      if (applied) {
        status = 'APPLIED';
        if (applied.checksum && applied.checksum !== m.checksum) {
          drift = true;
          hasDrift = true;
        }
      }

      statusList.push({
        version: m.version,
        filename: m.filename,
        checksum: m.checksum,
        appliedAt: applied ? applied.applied_at : null,
        status,
        drift
      });
    }

    return {
      total: diskMigrations.length,
      appliedCount: appliedMap.size,
      pendingCount: diskMigrations.length - appliedMap.size,
      hasDrift,
      migrations: statusList
    };
  }

  /**
   * Validate all migrations on disk and detect drift against applied records
   */
  async validateMigrations() {
    const status = await this.getStatus();
    const errors = [];

    if (status.hasDrift) {
      const drifted = status.migrations.filter(m => m.drift);
      for (const d of drifted) {
        errors.push(`Migration drift detected for ${d.filename}: Checksum on disk does not match recorded migration checksum.`);
      }
    }

    return {
      isValid: errors.length === 0,
      errors,
      status
    };
  }

  /**
   * Apply all pending migrations in order
   */
  async runMigrations() {
    await this.ensureMigrationTable();
    await this.acquireLock();

    try {
      const diskMigrations = this.getMigrationFiles();
      const appliedMap = await this.getAppliedMigrations();

      // Check for drift in previously applied migrations before executing new ones
      for (const m of diskMigrations) {
        const applied = appliedMap.get(m.version);
        if (applied && applied.checksum && applied.checksum !== m.checksum) {
          throw new Error(
            `Migration drift detected for ${m.filename}. Applied checksum "${applied.checksum}" does not match disk checksum "${m.checksum}". Refusing to apply migrations.`
          );
        }
      }

      const pending = diskMigrations.filter(m => !appliedMap.has(m.version));
      const appliedInThisRun = [];

      for (const m of pending) {
        console.log(`[MigrationRunner] Applying migration: ${m.filename}...`);
        const sql = fs.readFileSync(m.filepath, 'utf8');

        // Execute migration and record in tracking table within a single transaction
        await this.db.withTransaction(async (tx) => {
          // Split multiple SQL statements cleanly or execute raw batch
          await tx.query(sql);

          // Record in schema_migrations
          if (tx.pool || tx.client) {
            await tx.query(
              'INSERT INTO schema_migrations (version, filename, checksum, applied_at) VALUES ($1, $2, $3, NOW())',
              [m.version, m.filename, m.checksum]
            );
          } else {
            await tx.insert('schema_migrations', m.version, {
              version: m.version,
              filename: m.filename,
              checksum: m.checksum,
              applied_at: new Date().toISOString()
            });
          }
        });

        appliedInThisRun.push(m.filename);
        console.log(`[MigrationRunner] Successfully applied: ${m.filename}`);
      }

      return {
        appliedCount: appliedInThisRun.length,
        applied: appliedInThisRun
      };
    } finally {
      await this.releaseLock();
    }
  }

  /**
   * Rollback the last applied migration (DEVELOPMENT ONLY)
   *
   * @param {Object} [options]
   * @param {boolean} [options.forceDevDowngrade=false]
   */
  async revertLastMigration(options = {}) {
    const isProduction = (process.env.NODE_ENV || '').trim().toLowerCase() === 'production';

    // Strict production downgrade rejection invariant
    if (isProduction) {
      throw new Error('Migration downgrade is strictly forbidden in production mode (NODE_ENV=production).');
    }

    if (!options.forceDevDowngrade) {
      throw new Error('Migration downgrade requires explicit { forceDevDowngrade: true } option in non-production mode.');
    }

    await this.ensureMigrationTable();
    await this.acquireLock();

    try {
      const diskMigrations = this.getMigrationFiles();
      const appliedMap = await this.getAppliedMigrations();

      if (appliedMap.size === 0) {
        console.log('[MigrationRunner] No applied migrations to revert.');
        return { reverted: null };
      }

      // Find the latest applied migration
      const appliedVersions = Array.from(appliedMap.keys()).sort((a, b) => b.localeCompare(a, undefined, { numeric: true }));
      const lastVersion = appliedVersions[0];
      const targetMigration = diskMigrations.find(m => m.version === lastVersion);

      if (!targetMigration) {
        throw new Error(`Cannot revert migration ${lastVersion}: migration file not found on disk.`);
      }

      if (!targetMigration.downFilepath || !fs.existsSync(targetMigration.downFilepath)) {
        throw new Error(`Cannot revert migration ${targetMigration.filename}: corresponding .down.sql file does not exist.`);
      }

      console.log(`[MigrationRunner] Reverting migration ${targetMigration.filename} using down file...`);
      const downSql = fs.readFileSync(targetMigration.downFilepath, 'utf8');

      await this.db.withTransaction(async (tx) => {
        await tx.query(downSql);

        if (tx.pool || tx.client) {
          await tx.query('DELETE FROM schema_migrations WHERE version = $1', [targetMigration.version]);
        } else {
          await tx.delete('schema_migrations', targetMigration.version);
        }
      });

      console.log(`[MigrationRunner] Successfully reverted: ${targetMigration.filename}`);
      return { reverted: targetMigration.filename };
    } finally {
      await this.releaseLock();
    }
  }
}

// CLI Execution Handler
async function runCli() {
  const args = process.argv.slice(2);
  const command = (args[0] || 'status').toLowerCase();

  const runner = new MigrationRunner();

  try {
    switch (command) {
      case 'up': {
        console.log('=== EH HOME MIGRATION RUNNER — UP ===\n');
        const res = await runner.runMigrations();
        console.log(`\nMigration run completed. Applied ${res.appliedCount} migrations.`);
        process.exit(0);
        break;
      }
      case 'status': {
        console.log('=== EH HOME MIGRATION RUNNER — STATUS ===\n');
        const status = await runner.getStatus();
        console.log(`Total Migrations on Disk: ${status.total}`);
        console.log(`Applied: ${status.appliedCount} | Pending: ${status.pendingCount}\n`);

        status.migrations.forEach(m => {
          const statusLabel = m.status === 'APPLIED' ? '[APPLIED]' : '[PENDING]';
          const driftLabel = m.drift ? ' [DRIFT DETECTED!]' : '';
          console.log(`  ${statusLabel} ${m.filename}${driftLabel}`);
        });

        if (status.hasDrift) {
          console.error('\n[WARNING] Migration drift detected!');
          process.exit(1);
        }
        process.exit(0);
        break;
      }
      case 'validate': {
        console.log('=== EH HOME MIGRATION RUNNER — VALIDATE ===\n');
        const validation = await runner.validateMigrations();
        if (!validation.isValid) {
          console.error('[FAIL] Migration validation failed:');
          validation.errors.forEach(e => console.error(`  - ${e}`));
          process.exit(1);
        }
        console.log(`[PASS] All ${validation.status.total} migrations valid. No drift detected.`);
        process.exit(0);
        break;
      }
      case 'down': {
        console.log('=== EH HOME MIGRATION RUNNER — DOWN (DEV ONLY) ===\n');
        const hasForce = args.includes('--force-dev-downgrade');
        const res = await runner.revertLastMigration({ forceDevDowngrade: hasForce });
        console.log(`\nRevert result: ${res.reverted ? res.reverted : 'None'}`);
        process.exit(0);
        break;
      }
      default: {
        console.error(`Unknown command: ${command}. Supported commands: up, status, validate, down`);
        process.exit(1);
      }
    }
  } catch (err) {
    console.error(`\n[Migration Error]: ${err.message}`);
    process.exit(1);
  } finally {
    await runner.db.close();
  }
}

if (require.main === module) {
  runCli();
}

module.exports = { MigrationRunner, computeChecksum, ADVISORY_LOCK_ID };
