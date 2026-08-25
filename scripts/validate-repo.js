/**
 * EH Home — Monorepo Pre-Push Full Validation Script
 * Cross-platform script to run all 8 automated test suites across Node.js & Flutter.
 *
 * Usage:
 *   node scripts/validate-repo.js
 */

const { execSync } = require('child_process');
const path = require('path');

const rootDir = path.resolve(__dirname, '..');
const flutterDir = path.resolve(rootDir, 'smart_home_application_v1');

console.log('===============================================================');
console.log('       EH HOME MONOREPO — PRE-PUSH FULL VALIDATION SUITE       ');
console.log('===============================================================\n');

let failedSuites = 0;

function runStep(name, command, cwd = rootDir) {
  console.log(`\n>>> Running: ${name}`);
  console.log(`    Command: ${command}`);
  try {
    execSync(command, { cwd, stdio: 'inherit' });
    console.log(`    [PASS] ${name}`);
  } catch (err) {
    console.error(`    [FAIL] ${name} (Exit code: ${err.status})`);
    failedSuites++;
  }
}

const nodeBin = `"${process.execPath}"`;

// 1. Contracts & Schemas
runStep('1. Canonical Contract Hardening Tests', `${nodeBin} packages/contracts/tests/contract-test.js`);

// 2. Product Catalog Definitions
runStep('2. Product Catalog Definition Validation', `${nodeBin} product-definitions/tests/validate-products.js`);

// 3. Hardware Simulator Compliance
runStep('3. Device Simulator Contract Compliance', `${nodeBin} tools/device-simulator/test-simulator.js`);

// 4. SQL Migration Lifecycle & Parity
runStep('4. SQL Migration Lifecycle & Capability Sync', `${nodeBin} backend/migrations/verify-migrations.js`);

// 5. Backend Database & Repositories
runStep('5. Backend DB & Repository Integration Tests', `${nodeBin} backend/tests/integration.test.js`);

// 6. Backend Hardening Test Suite
runStep('6. Backend Hardening Test Suite (Auth, State, Idempotency)', `${nodeBin} backend/tests/hardening.test.js`);

// 7. Product Catalog Service & API Router
runStep('7. Product Catalog Service & API Router Tests', `${nodeBin} backend/tests/product-catalog.test.js`);

// 8. Phase 4 Backend Domain Model & Service Tests
runStep('8. Phase 4 Backend Domain Model & Service Tests', `${nodeBin} backend/tests/phase4-domain.test.js`);

// 9. Phase 5 Backend Secure Onboarding & Claiming Tests
runStep('9. Phase 5 Backend Secure Onboarding & Claiming Tests', `${nodeBin} backend/tests/phase5-onboarding.test.js`);

// 10. Phase 6 MQTT Device Transport Integration Tests
runStep('10. Phase 6 MQTT Device Transport Integration Tests', `${nodeBin} backend/tests/phase6-mqtt.test.js`);

// 11. Flutter Code Analysis
runStep('11. Flutter Analyzer (smart_home_application_v1)', 'flutter analyze', flutterDir);

// 12. Flutter Unit & Widget Test Suite
runStep('12. Flutter Test Suite (smart_home_application_v1)', 'flutter test --no-pub', flutterDir);

console.log('\n===============================================================');
if (failedSuites === 0) {
  console.log('  ALL TEST SUITES PASSED! REPOSITORY IS IN HEALTHY STATE.');
  console.log('===============================================================');
  process.exit(0);
} else {
  console.error(`  VALIDATION FAILED: ${failedSuites} test suite(s) failed.`);
  console.log('===============================================================');
  process.exit(1);
}
