#!/usr/bin/env node
'use strict';

/**
 * EH Home — Safe Development Data Reset Utility
 *
 * Requirements:
 * 1. Strictly refuses execution if NODE_ENV !== 'development' (and strictly refuses in production regardless of flags).
 * 2. Requires explicit --confirm-reset flag for destructive execution; otherwise runs in safe dry-run preview mode.
 * 3. Dry-run preview before destructive execution showing targeted records.
 * 4. Clear list of records that will be deleted.
 * 5. Production refusal regardless of flags.
 * 6. Must NOT delete or modify verified consumer accounts/homes unless explicitly targeted via --target=<userId/email/homeId>.
 */

const { DatabaseClient } = require('../backend/src/shared/db-client');

async function main() {
  const nodeEnv = process.env.NODE_ENV;
  const dbAdapter = process.env.DB_ADAPTER || 'memory';
  const args = process.argv.slice(2);
  const isConfirmReset = args.includes('--confirm-reset');
  const isDryRun = !isConfirmReset || args.includes('--dry-run');
  const targetArg = args.find(a => a.startsWith('--target='));
  const explicitTarget = targetArg ? targetArg.split('=')[1].trim() : null;

  console.log('====================================================');
  console.log('EH Home — Safe Development Data Reset Utility');
  console.log('====================================================');
  console.log(`Environment:      ${nodeEnv || 'undefined'}`);
  console.log(`Database Adapter: ${dbAdapter}`);
  console.log(`Execution Mode:   ${isDryRun ? 'DRY-RUN PREVIEW (No changes applied)' : 'DESTRUCTIVE EXECUTION'}`);
  console.log(`Target Scope:     ${explicitTarget || 'development-fixtures-only (default)'}`);
  console.log('====================================================\n');

  // Requirement 5: Production refusal regardless of flags
  if (nodeEnv === 'production' || process.env.NODE_ENV === 'production') {
    console.error('FATAL: Destructive data reset is strictly REFUSED in production environment regardless of flags.');
    process.exit(1);
  }

  // Requirement 1: NODE_ENV=development requirement
  if (nodeEnv !== 'development') {
    console.error(`FATAL: Reset utility strictly requires NODE_ENV=development (current: "${nodeEnv}").`);
    console.error('Usage: NODE_ENV=development node scripts/reset-dev-data.js [--confirm-reset] [--target=<scope>]');
    process.exit(1);
  }

  // 2. Connect Database Client
  const dbClient = new DatabaseClient({
    mode: dbAdapter,
    connectionString: process.env.DATABASE_URL
  });

  try {
    await dbClient.connect();
    console.log('[Status] Connected to database adapter successfully.');

    // Known automated test fixtures / ephemeral dev fixtures
    const DEV_FIXTURE_EMAILS = [
      'test-phase48@example.com',
      'test-demo-user@example.com',
      'demo@example.com',
      'temp-test@example.com',
      'fixture-user@example.com'
    ];

    const DEV_FIXTURE_HOMES = [
      'Demo Home',
      'Test Home Phase48',
      'Temporary Test Home',
      'Fixture Home'
    ];

    console.log('\n[Inspection] Scanning database records matching targeted scope...');

    let usersToDelete = [];
    let homesToDelete = [];

    if (typeof dbClient.adapter.find === 'function') {
      const allUsers = await dbClient.adapter.find('users', () => true);
      const allHomes = await dbClient.adapter.find('homes', () => true);

      if (explicitTarget) {
        // Explicit targeted selection by email, user ID, or home name / home ID
        usersToDelete = allUsers.filter(u =>
          u.id === explicitTarget ||
          u.email.toLowerCase() === explicitTarget.toLowerCase() ||
          (explicitTarget === 'all-dev-fixtures' && (DEV_FIXTURE_EMAILS.includes(u.email.toLowerCase()) || u.email.includes('fixture')))
        );

        homesToDelete = allHomes.filter(h =>
          h.id === explicitTarget ||
          h.name.toLowerCase() === explicitTarget.toLowerCase() ||
          (explicitTarget === 'all-dev-fixtures' && (DEV_FIXTURE_HOMES.includes(h.name) || h.name.includes('Fixture')))
        );
      } else {
        // Default safe scope: strictly match known development fixture emails / homes only
        // Real verified consumer accounts are never selected by default
        usersToDelete = allUsers.filter(u => DEV_FIXTURE_EMAILS.includes(u.email.toLowerCase()));
        homesToDelete = allHomes.filter(h => DEV_FIXTURE_HOMES.includes(h.name));
      }
    }

    // Requirement 4: Clear list of records that will be deleted
    console.log(`\nRecords targeted for removal (${usersToDelete.length} user(s), ${homesToDelete.length} home(s)):`);
    if (usersToDelete.length === 0 && homesToDelete.length === 0) {
      console.log('  (No matching development fixture records found)');
    } else {
      if (usersToDelete.length > 0) {
        console.log('  Users:');
        for (const u of usersToDelete) {
          console.log(`    - ID: ${u.id} | Email: ${u.email}`);
        }
      }
      if (homesToDelete.length > 0) {
        console.log('  Homes:');
        for (const h of homesToDelete) {
          console.log(`    - ID: ${h.id} | Name: "${h.name}" | Owner: ${h.owner_id}`);
        }
      }
    }

    // Requirement 3 & 2: Dry-run preview before destructive execution
    if (isDryRun) {
      console.log('\n----------------------------------------------------');
      console.log('[DRY-RUN PREVIEW] Preview completed successfully.');
      console.log('No database records were modified or deleted.');
      console.log('To perform destructive execution, provide the explicit --confirm-reset flag:');
      console.log('  NODE_ENV=development node scripts/reset-dev-data.js --confirm-reset');
      console.log('----------------------------------------------------\n');
    } else {
      if (usersToDelete.length === 0 && homesToDelete.length === 0) {
        console.log('\n[Execution] Nothing to delete for current scope.');
        return;
      }

      console.log('\n[Destructive Execution] Deleting targeted development records...');

      for (const u of usersToDelete) {
        if (typeof dbClient.adapter.delete === 'function') {
          await dbClient.adapter.delete('users', u.id);
          try { await dbClient.adapter.delete('user_profiles', u.id); } catch (_) {}
          console.log(`  Deleted user record: ${u.email} (${u.id})`);
        }
      }

      for (const h of homesToDelete) {
        if (typeof dbClient.adapter.delete === 'function') {
          await dbClient.adapter.delete('homes', h.id);
          console.log(`  Deleted home record: "${h.name}" (${h.id})`);
        }
      }

      console.log('\n[Complete] Successfully cleaned targeted development records.');
      console.log('Verified consumer accounts and platform catalog seed data remain preserved.');
    }
  } catch (err) {
    console.error('Error during data reset execution:', err.message);
  } finally {
    await dbClient.close();
  }
}

if (require.main === module) {
  main().catch(err => {
    console.error('Unhandled reset failure:', err);
    process.exit(1);
  });
}

module.exports = { main };
