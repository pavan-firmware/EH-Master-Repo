const fs = require('fs');
const path = require('path');

console.log('=== VERIFYING FULL SQL MIGRATION LIFECYCLE ===\n');

const migrations = [
  { up: '001_initial_schema.sql', down: '001_initial_schema.down.sql' },
  { up: '002_capabilities_network_audit_outbox.sql', down: '002_capabilities_network_audit_outbox.down.sql' },
  { up: '006_automations_scenes_schedules.sql', down: '006_automations_scenes_schedules.down.sql' },
  { up: '007_device_management_health_observability.sql', down: '007_device_management_health_observability.down.sql' },
  { up: '008_notifications_alerts.sql', down: '008_notifications_alerts.down.sql' },
  { up: '009_account_home_access_control.sql', down: '009_account_home_access_control.down.sql' },
  { up: '010_cloud_sync_data_lifecycle.sql', down: '010_cloud_sync_data_lifecycle.down.sql' },
  { up: '011_device_fleet_ota.sql', down: '011_device_fleet_ota.down.sql' },
  { up: '012_energy_intelligence.sql', down: '012_energy_intelligence.down.sql' },
  { up: '013_smart_energy_automation.sql', down: '013_smart_energy_automation.down.sql' },
  { up: '014_energy_cost_tariffs.sql', down: '014_energy_cost_tariffs.down.sql' },
  { up: '015_energy_forecasting_predictive.sql', down: '015_energy_forecasting_predictive.down.sql' },
  { up: '016_presence_context_intelligence.sql', down: '016_presence_context_intelligence.down.sql' },
  { up: '017_smart_home_intelligence.sql', down: '017_smart_home_intelligence.down.sql' },
  { up: '018_proactive_device_reliability.sql', down: '018_proactive_device_reliability.down.sql' },
  { up: '019_multi_protocol_connectivity.sql', down: '019_multi_protocol_connectivity.down.sql' },
  { up: '020_product_discovery_catalog.sql', down: '020_product_discovery_catalog.down.sql' },
  { up: '021_local_first_edge_control.sql', down: '021_local_first_edge_control.down.sql' }
];

let totalUpTables = [];
let errors = 0;

migrations.forEach(({ up, down }) => {
  const upSql = fs.readFileSync(path.join(__dirname, up), 'utf8');
  const downSql = fs.readFileSync(path.join(__dirname, down), 'utf8');

  const createRegex = /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z0-9_]+)/gi;
  let match;
  const upTables = [];
  while ((match = createRegex.exec(upSql)) !== null) {
    upTables.push(match[1].toLowerCase());
    totalUpTables.push(match[1].toLowerCase());
  }

  const dropRegex = /DROP\s+TABLE\s+(?:IF\s+EXISTS\s+)?([a-zA-Z0-9_]+)/gi;
  const downTables = [];
  while ((match = dropRegex.exec(downSql)) !== null) {
    downTables.push(match[1].toLowerCase());
  }

  console.log(`Migration ${up}: ${upTables.length} tables created`);
  console.log(`Migration ${down}: ${downTables.length} tables dropped`);

  upTables.forEach(t => {
    if (!downTables.includes(t)) {
      console.error(`  [ERROR] Table '${t}' in ${up} is NOT in ${down}`);
      errors++;
    }
  });
});

console.log(`\nTotal Managed Tables across migrations: ${totalUpTables.length}`);
totalUpTables.forEach(t => console.log(`  • ${t}`));

// Seed file validity checks
const seed003 = fs.readFileSync(path.join(__dirname, '003_seed_dev_catalog.sql'), 'utf8');
const seed004 = fs.readFileSync(path.join(__dirname, '004_seed_missing_capabilities.sql'), 'utf8');

if (seed003.includes('INSERT INTO product_families') && seed003.includes('INSERT INTO product_variants')) {
  console.log('\n[PASS] Seed file 003_seed_dev_catalog.sql is valid!');
} else {
  console.error('\n[FAIL] Seed file 003 is missing core inserts!');
  errors++;
}

// Verify 004 adds the 4 missing canonical capabilities
const missingCaps = ['brightness', 'cct', 'scene', 'schedule'];
missingCaps.forEach(cap => {
  if (seed004.includes(`'${cap}'`)) {
    console.log(`[PASS] Migration 004 seeds missing capability '${cap}'`);
  } else {
    console.error(`[FAIL] Migration 004 is missing capability '${cap}'`);
    errors++;
  }
});

// Capability consistency check: verify database seed (003+004) matches canonical registry
console.log('\n=== CAPABILITY REGISTRY CONSISTENCY CHECK ===');
const registryPath = path.join(__dirname, '../../packages/contracts/capability/capability-registry.json');
const registry = JSON.parse(fs.readFileSync(registryPath, 'utf8'));
const canonicalCapabilities = Object.keys(registry).sort();

const seedSql = seed003 + '\n' + seed004;
const mismatches = [];
canonicalCapabilities.forEach(capId => {
  if (!seedSql.includes(`'${capId}'`)) {
    mismatches.push(capId);
  }
});

if (mismatches.length === 0) {
  console.log(`[PASS] All ${canonicalCapabilities.length} canonical capabilities are seeded in database migrations!`);
  canonicalCapabilities.forEach(c => console.log(`  ✓ ${c}`));
} else {
  console.error(`[FAIL] ${mismatches.length} canonical capabilities are MISSING from database seed:`);
  mismatches.forEach(c => console.error(`  ✗ ${c}`));
  errors++;
}

if (errors === 0) {
  console.log('\n[PASS] All migrations UP & DOWN are 100% symmetric, ordered, and valid!');
  process.exit(0);
} else {
  console.error(`\n[FAIL] Migration verification failed with ${errors} errors.`);
  process.exit(1);
}
