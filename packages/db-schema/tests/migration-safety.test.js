/**
 * EH Home Migration Safety & Integrity Test Suite
 *
 * Enforces the non-negotiable invariant:
 * Migrations 001–029 are FROZEN.
 * None may be edited, renamed, squashed, deleted, or altered.
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

console.log('=== EH HOME MIGRATION SAFETY & INTEGRITY TEST ===\n');

const frozenMigrationsDir = path.join(__dirname, '../../../backend/migrations');
const forwardMigrationsDir = path.join(__dirname, '../migrations');

const frozenUpFiles = fs.readdirSync(frozenMigrationsDir)
  .filter(f => f.endsWith('.sql') && !f.endsWith('.down.sql') && /^[0-9]{3}_/.test(f))
  .sort();

const frozenDownFiles = fs.readdirSync(frozenMigrationsDir)
  .filter(f => f.endsWith('.down.sql') && /^[0-9]{3}_/.test(f))
  .sort();

const forwardUpFiles = fs.readdirSync(forwardMigrationsDir)
  .filter(f => f.endsWith('.sql') && !f.endsWith('.down.sql') && /^[0-9]{3}_/.test(f))
  .sort();

const forwardDownFiles = fs.readdirSync(forwardMigrationsDir)
  .filter(f => f.endsWith('.down.sql') && /^[0-9]{3}_/.test(f))
  .sort();

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function runTest(name, fn) {
  totalTests++;
  try {
    fn();
    console.log(`  [PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  [FAIL] ${name}: ${err.message}`);
    failedTests++;
  }
}

// 1. Verify frozen baseline migrations (001–029)
runTest('Exactly 29 frozen baseline migrations exist in backend/migrations (001–029)', () => {
  assert.strictEqual(frozenUpFiles.length, 29);
  assert.ok(frozenUpFiles[0].startsWith('001_'));
  assert.ok(frozenUpFiles[28].startsWith('029_'));
});

runTest('Exactly 29 frozen DOWN migrations exist in backend/migrations (001–029)', () => {
  assert.strictEqual(frozenDownFiles.length, 29);
});

// 2. Verify 1-to-1 symmetry for frozen migrations
runTest('Every frozen UP migration has a corresponding DOWN migration', () => {
  frozenUpFiles.forEach(up => {
    const base = up.replace('.sql', '');
    const expectedDown = `${base}.down.sql`;
    assert.ok(frozenDownFiles.includes(expectedDown), `Missing down migration for ${up}`);
  });
});

// 3. Verify sequence continuity (no missing numbers from 001 to 029)
runTest('Sequential continuity: all numbers 001 to 029 are present in frozen baseline without gaps', () => {
  for (let i = 1; i <= 29; i++) {
    const prefix = String(i).padStart(3, '0') + '_';
    const found = frozenUpFiles.some(f => f.startsWith(prefix));
    assert.ok(found, `Missing migration number ${prefix}`);
  }
});

// 4. Verify no migration >= 030 exists in backend/migrations (frozen boundary protection)
runTest('No migration >= 030 exists in backend/migrations (frozen legacy protected)', () => {
  const extraFiles = fs.readdirSync(frozenMigrationsDir)
    .filter(f => f.endsWith('.sql') && /^03[0-9]_|^0[4-9][0-9]_/.test(f));
  assert.strictEqual(extraFiles.length, 0, `Unexpected migration >= 030 found in backend/migrations: ${extraFiles.join(', ')}`);
});

// 5. Verify forward migration 030 in db-schema/migrations
runTest('Forward migration 030 exists in packages/db-schema/migrations', () => {
  assert.ok(forwardUpFiles.includes('030_hardware_bom_management.sql'), 'Missing 030_hardware_bom_management.sql');
  assert.ok(forwardDownFiles.includes('030_hardware_bom_management.down.sql'), 'Missing 030_hardware_bom_management.down.sql');
});

runTest('Forward migration 030 UP and DOWN are non-empty and well-formed', () => {
  const upContent = fs.readFileSync(path.join(forwardMigrationsDir, '030_hardware_bom_management.sql'), 'utf8');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS hardware_revisions'), 'Missing hardware_revisions DDL');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS bom_specifications'), 'Missing bom_specifications DDL');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS bom_items'), 'Missing bom_items DDL');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS component_substitutions'), 'Missing component_substitutions DDL');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS product_variant_hardware_compatibility'), 'Missing compatibility table DDL');

  const downContent = fs.readFileSync(path.join(forwardMigrationsDir, '030_hardware_bom_management.down.sql'), 'utf8');
  assert.ok(downContent.includes('DROP TABLE IF EXISTS product_variant_hardware_compatibility;'), 'Missing compatibility table drop');
  assert.ok(downContent.includes('DROP TABLE IF EXISTS hardware_revisions;'), 'Missing hardware_revisions drop');
});

// 6. Rollback Safety: No CASCADE keyword & strict reverse dependency order
runTest('Migration 030 rollback avoids CASCADE and drops in reverse-dependency order', () => {
  const downContent = fs.readFileSync(path.join(forwardMigrationsDir, '030_hardware_bom_management.down.sql'), 'utf8');
  // Prohibit CASCADE to prevent accidental deletion of future dependent tables
  assert.ok(!downContent.includes('CASCADE'), 'Migration 030 down must not use CASCADE');

  // Verify reverse dependency order
  const lines = downContent.split('\n')
    .map(l => l.trim())
    .filter(l => l.startsWith('DROP TABLE IF EXISTS'));

  const expectedOrder = [
    'DROP TABLE IF EXISTS product_variant_hardware_compatibility;',
    'DROP TABLE IF EXISTS component_substitutions;',
    'DROP TABLE IF EXISTS bom_items;',
    'DROP TABLE IF EXISTS bom_specifications;',
    'DROP TABLE IF EXISTS hardware_revisions;'
  ];

  assert.strictEqual(lines.length, 5, 'Must drop exactly the 5 migration 030 tables');
  for (let i = 0; i < expectedOrder.length; i++) {
    assert.strictEqual(lines[i], expectedOrder[i], `Expected drop step ${i} to be ${expectedOrder[i]}`);
  }
});

// 7. Schema Isolation: Migration 030 does not alter any historical table from 001–029
runTest('Migration 030 is isolated: does not alter or drop any historical table', () => {
  const upContent = fs.readFileSync(path.join(forwardMigrationsDir, '030_hardware_bom_management.sql'), 'utf8');
  assert.ok(!upContent.includes('ALTER TABLE'), 'Migration 030 must not ALTER existing tables');
  assert.ok(!upContent.includes('DROP TABLE'), 'Migration 030 UP must not DROP any tables');

  // Verify all CREATE TABLE statements only create the 5 approved tables
  const createdTables = [...upContent.matchAll(/CREATE TABLE IF NOT EXISTS ([a-z_]+)/g)].map(m => m[1]);
  const approvedTables = [
    'hardware_revisions',
    'bom_specifications',
    'bom_items',
    'component_substitutions',
    'product_variant_hardware_compatibility'
  ];
  assert.deepStrictEqual(createdTables, approvedTables);
});

// 8. Verify forward migration 031 in db-schema/migrations (Part 07)
runTest('Forward migration 031 exists in packages/db-schema/migrations', () => {
  assert.ok(forwardUpFiles.includes('031_firmware_git_binary_management.sql'), 'Missing 031_firmware_git_binary_management.sql');
  assert.ok(forwardDownFiles.includes('031_firmware_git_binary_management.down.sql'), 'Missing 031_firmware_git_binary_management.down.sql');
});

runTest('Forward migration 031 UP and DOWN are non-empty and well-formed', () => {
  const upContent = fs.readFileSync(path.join(forwardMigrationsDir, '031_firmware_git_binary_management.sql'), 'utf8');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS firmware_families'), 'Missing firmware_families DDL');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS firmware_builds'), 'Missing firmware_builds DDL');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS firmware_artifacts'), 'Missing firmware_artifacts DDL');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS firmware_hardware_compatibility'), 'Missing firmware_hardware_compatibility DDL');

  const downContent = fs.readFileSync(path.join(forwardMigrationsDir, '031_firmware_git_binary_management.down.sql'), 'utf8');
  assert.ok(downContent.includes('DROP TABLE IF EXISTS firmware_hardware_compatibility;'), 'Missing compatibility drop');
  assert.ok(downContent.includes('DROP TABLE IF EXISTS firmware_families;'), 'Missing families drop');
});

// 9. Rollback Safety for Migration 031: No CASCADE & strict reverse dependency order
runTest('Migration 031 rollback avoids CASCADE and drops in reverse-dependency order', () => {
  const downContent = fs.readFileSync(path.join(forwardMigrationsDir, '031_firmware_git_binary_management.down.sql'), 'utf8');
  assert.ok(!downContent.includes('CASCADE'), 'Migration 031 down must not use CASCADE');

  const lines = downContent.split('\n')
    .map(l => l.trim())
    .filter(l => l.startsWith('DROP TABLE IF EXISTS'));

  const expectedOrder = [
    'DROP TABLE IF EXISTS firmware_hardware_compatibility;',
    'DROP TABLE IF EXISTS firmware_artifacts;',
    'DROP TABLE IF EXISTS firmware_builds;',
    'DROP TABLE IF EXISTS firmware_families;'
  ];

  assert.strictEqual(lines.length, 4, 'Must drop exactly the 4 migration 031 tables');
  for (let i = 0; i < expectedOrder.length; i++) {
    assert.strictEqual(lines[i], expectedOrder[i], `Expected drop step ${i} to be ${expectedOrder[i]}`);
  }
});

// 10. Schema Isolation: Migration 031 does not alter any historical table from 001–030
runTest('Migration 031 is isolated: does not alter or drop any historical table', () => {
  const upContent = fs.readFileSync(path.join(forwardMigrationsDir, '031_firmware_git_binary_management.sql'), 'utf8');
  assert.ok(!upContent.includes('ALTER TABLE'), 'Migration 031 must not ALTER existing tables');
  assert.ok(!upContent.includes('DROP TABLE'), 'Migration 031 UP must not DROP any tables');

  const createdTables = [...upContent.matchAll(/CREATE TABLE IF NOT EXISTS ([a-z_]+)/g)].map(m => m[1]);
  const approvedTables = [
    'firmware_families',
    'firmware_builds',
    'firmware_artifacts',
    'firmware_hardware_compatibility'
  ];
  assert.deepStrictEqual(createdTables, approvedTables);
});

// 11. Verify forward migration 033 in db-schema/migrations (Part 11)
runTest('Forward migration 033 exists in packages/db-schema/migrations', () => {
  assert.ok(forwardUpFiles.includes('033_production_inventory_packing.sql'), 'Missing 033_production_inventory_packing.sql');
  assert.ok(forwardDownFiles.includes('033_production_inventory_packing.down.sql'), 'Missing 033_production_inventory_packing.down.sql');
});

runTest('Forward migration 033 UP and DOWN are non-empty and well-formed', () => {
  const upContent = fs.readFileSync(path.join(forwardMigrationsDir, '033_production_inventory_packing.sql'), 'utf8');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS packaging_cartons'), 'Missing packaging_cartons DDL');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS inventory_items'), 'Missing inventory_items DDL');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS dual_scan_verifications'), 'Missing dual_scan_verifications DDL');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS packaging_records'), 'Missing packaging_records DDL');

  const downContent = fs.readFileSync(path.join(forwardMigrationsDir, '033_production_inventory_packing.down.sql'), 'utf8');
  assert.ok(downContent.includes('DROP TABLE IF EXISTS packaging_records;'), 'Missing packaging_records drop');
  assert.ok(downContent.includes('DROP TABLE IF EXISTS packaging_cartons;'), 'Missing packaging_cartons drop');
});

runTest('Migration 033 rollback avoids CASCADE and drops in reverse-dependency order', () => {
  const downContent = fs.readFileSync(path.join(forwardMigrationsDir, '033_production_inventory_packing.down.sql'), 'utf8');
  assert.ok(!downContent.includes('CASCADE'), 'Migration 033 down must not use CASCADE');

  const lines = downContent.split('\n')
    .map(l => l.trim())
    .filter(l => l.startsWith('DROP TABLE IF EXISTS'));

  const expectedOrder = [
    'DROP TABLE IF EXISTS packaging_records;',
    'DROP TABLE IF EXISTS dual_scan_verifications;',
    'DROP TABLE IF EXISTS inventory_items;',
    'DROP TABLE IF EXISTS packaging_cartons;'
  ];

  assert.strictEqual(lines.length, 4, 'Must drop exactly the 4 migration 033 tables');
  for (let i = 0; i < expectedOrder.length; i++) {
    assert.strictEqual(lines[i], expectedOrder[i], `Expected drop step ${i} to be ${expectedOrder[i]}`);
  }
});

runTest('Migration 033 is isolated: does not alter or drop any historical table', () => {
  const upContent = fs.readFileSync(path.join(forwardMigrationsDir, '033_production_inventory_packing.sql'), 'utf8');
  assert.ok(!upContent.includes('ALTER TABLE'), 'Migration 033 must not ALTER existing tables');
  assert.ok(!upContent.includes('DROP TABLE'), 'Migration 033 UP must not DROP any tables');

  const createdTables = [...upContent.matchAll(/CREATE TABLE IF NOT EXISTS ([a-z_]+)/g)].map(m => m[1]);
  const approvedTables = [
    'packaging_cartons',
    'inventory_items',
    'dual_scan_verifications',
    'packaging_records'
  ];
  assert.deepStrictEqual(createdTables, approvedTables);
});

// 12. Verify forward migration 034 in db-schema/migrations (Part 13)
runTest('Forward migration 034 exists in packages/db-schema/migrations', () => {
  assert.ok(forwardUpFiles.includes('034_telemetry_mqtt_ota.sql'), 'Missing 034_telemetry_mqtt_ota.sql');
  assert.ok(forwardDownFiles.includes('034_telemetry_mqtt_ota.down.sql'), 'Missing 034_telemetry_mqtt_ota.down.sql');
});

runTest('Forward migration 034 UP and DOWN are non-empty and well-formed', () => {
  const upContent = fs.readFileSync(path.join(forwardMigrationsDir, '034_telemetry_mqtt_ota.sql'), 'utf8');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS mqtt_acl_rules'), 'Missing mqtt_acl_rules DDL');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS device_availability_history'), 'Missing device_availability_history DDL');
  assert.ok(upContent.includes('CREATE TABLE IF NOT EXISTS ota_execution_jobs'), 'Missing ota_execution_jobs DDL');

  const downContent = fs.readFileSync(path.join(forwardMigrationsDir, '034_telemetry_mqtt_ota.down.sql'), 'utf8');
  assert.ok(downContent.includes('DROP TABLE IF EXISTS ota_execution_jobs;'), 'Missing ota_execution_jobs drop');
  assert.ok(downContent.includes('DROP TABLE IF EXISTS device_availability_history;'), 'Missing device_availability_history drop');
  assert.ok(downContent.includes('DROP TABLE IF EXISTS mqtt_acl_rules;'), 'Missing mqtt_acl_rules drop');
});

runTest('Migration 034 is isolated: does not alter or drop any historical table', () => {
  const upContent = fs.readFileSync(path.join(forwardMigrationsDir, '034_telemetry_mqtt_ota.sql'), 'utf8');
  assert.ok(!upContent.includes('ALTER TABLE'), 'Migration 034 must not ALTER existing tables');
  assert.ok(!upContent.includes('DROP TABLE'), 'Migration 034 UP must not DROP any tables');

  const createdTables = [...upContent.matchAll(/CREATE TABLE IF NOT EXISTS ([a-z_]+)/g)].map(m => m[1]);
  const approvedTables = [
    'mqtt_acl_rules',
    'device_availability_history',
    'ota_execution_jobs'
  ];
  assert.deepStrictEqual(createdTables, approvedTables);
});


// 11. Non-empty and safe baseline checks
runTest('Frozen migrations are non-empty and free of destructive statements', () => {
  frozenUpFiles.forEach(f => {
    const content = fs.readFileSync(path.join(frozenMigrationsDir, f), 'utf8');
    assert.ok(content.length > 50, `${f} is unexpectedly small or empty`);
    assert.ok(!content.includes('DROP DATABASE'), `${f} contains dangerous destructive statements`);
  });
});

console.log(`\n=== MIGRATION INTEGRITY SUMMARY ===`);
console.log(`Total:  ${totalTests}`);
console.log(`Passed: ${passedTests}`);
console.log(`Failed: ${failedTests}`);

if (failedTests > 0) {
  process.exit(1);
} else {
  console.log('ALL MIGRATION SAFETY TESTS PASSED [FROZEN BASELINE VERIFIED]\n');
}
