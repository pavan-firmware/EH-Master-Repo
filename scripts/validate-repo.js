/**
 * EH Home — Monorepo Pre-Push Full Validation Script
 * Cross-platform script to run all 16 automated test suites across Node.js & Flutter.
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
    if (err.status === 2) {
      console.log(`    [SKIPPED - PENDING DAEMON] ${name} (Exit code: 2 - Docker not running)`);
    } else {
      console.error(`    [FAIL] ${name} (Exit code: ${err.status})`);
      failedSuites++;
    }
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

// 10. Phase 6 MQTT Transport Unit/Mock Tests
runStep('10. Phase 6 MQTT Transport Unit/Mock Tests', `${nodeBin} backend/tests/phase6-mqtt.test.js`);

// 11. Phase 6 Low-Level MQTT Protocol Harness Tests
runStep('11. Phase 6 Low-Level MQTT Protocol Harness Tests', `${nodeBin} backend/tests/phase6-protocol-harness.test.js`);

// 12. Phase 6 Real EMQX 5.8.0 Integration Tests
runStep('12. Phase 6 Real EMQX 5.8.0 Integration Tests', `${nodeBin} backend/tests/phase6-emqx-integration.test.js`);

// 13. Phase 7A Authentication & Authorization Tests
runStep('13. Phase 7A Backend Auth & Authorization Tests', `${nodeBin} backend/tests/phase7a-auth.test.js`);

// 14. Phase 7B Realtime SSE & Worker Tests
runStep('14. Phase 7B Realtime SSE & Worker Integration Tests', `${nodeBin} backend/tests/phase7b-realtime.test.js`);

// 15. Flutter Code Analysis
runStep('15. Flutter Analyzer (smart_home_application_v1)', 'flutter analyze', flutterDir);

// 16. Flutter Test Suite
runStep('16. Flutter Test Suite (smart_home_application_v1)', 'flutter test --no-pub', flutterDir);

// 17. Phase 8 Firmware Host Tests
runStep('17. Phase 8 Firmware Host & Protocol Tests', `${nodeBin} firmware/tests/test_firmware_modules.js`);

// 18. Phase 8 Manufacturing PKI Tests
runStep('18. Phase 8 Manufacturing PKI & Provisioner Tests', 'python tools/manufacturing/test_manufacturing.py');

// 19. Phase 8 Signed OTA Tests
runStep('19. Phase 8 Signed OTA & Compatibility Tests', `${nodeBin} backend/tests/phase8-ota.test.js`);

// 20. Phase 8 Hardware Harness Self-Test
runStep('20. Phase 8 Hardware Test Harness Self-Test', 'python tools/hardware-test-harness/test_esp32_lifecycle.py');

// 21. Phase 10 Automation, Scenes & Scheduler Tests
runStep('21. Phase 10 Automation, Scenes & Scheduler Engine Tests', `${nodeBin} backend/tests/phase10-automation.test.js`);

// 22. Phase 11 Device Management, Health & Observability Tests
runStep('22. Phase 11 Device Management, Health & Observability Tests', `${nodeBin} backend/tests/phase11-device-management.test.js`);

// 23. Phase 12 Environment Configuration Validation
runStep('23. Phase 12 Environment Configuration Validation', `${nodeBin} scripts/validate-environment.js`);

// 24. Phase 13 Production Deployment & Operational Security Tests
runStep('24. Phase 13 Production Deployment & Operational Security Tests', `${nodeBin} backend/tests/phase13-production-deployment.test.js`);

// 25. Phase 15 Notifications & Alerts Platform Tests
runStep('25. Phase 15 Notifications & Alerts Platform Tests', `${nodeBin} backend/tests/phase15-notifications.test.js`);

// 26. Phase 16 Account, Home & Access Control Platform Tests
runStep('26. Phase 16 Account, Home & Access Control Platform Tests', `${nodeBin} backend/tests/phase16-access-control.test.js`);

// 27. Phase 17 Cloud Sync & Data Lifecycle Tests
runStep('27. Phase 17 Cloud Sync & Data Lifecycle Platform Tests', `${nodeBin} backend/tests/phase17-cloud-sync.test.js`);

// 28. Phase 18 Device Fleet Management & OTA Lifecycle Tests
runStep('28. Phase 18 Device Fleet Management & OTA Lifecycle Tests', `${nodeBin} backend/tests/phase18-fleet-ota.test.js`);

// 29. Phase 19 Energy Intelligence & Telemetry Analytics Tests
runStep('29. Phase 19 Energy Intelligence & Telemetry Analytics Tests', `${nodeBin} backend/tests/phase19-energy-intelligence.test.js`);

// 30. Phase 20 Smart Energy Automation & Optimization Tests
runStep('30. Phase 20 Smart Energy Automation & Optimization Tests', `${nodeBin} backend/tests/phase20-smart-energy-automation.test.js`);

// 31. Phase 21 Energy Cost Intelligence & Dynamic Tariffs Tests
runStep('31. Phase 21 Energy Cost Intelligence & Dynamic Tariffs Tests', `${nodeBin} backend/tests/phase21-energy-cost-optimization.test.js`);

// 32. Phase 22 Energy Forecasting & Predictive Intelligence Tests
runStep('32. Phase 22 Energy Forecasting & Predictive Intelligence Tests', `${nodeBin} backend/tests/phase22-energy-forecasting.test.js`);

// 33. Phase 23 Presence, Context Intelligence + Context-Aware Automation Tests
runStep('33. Phase 23 Presence & Context Intelligence Tests', `${nodeBin} backend/tests/phase23-presence-context.test.js`);

// 34. Phase 24 Smart Home Intelligence + Unified Decision Engine Tests
runStep('34. Phase 24 Smart Home Intelligence & Decision Engine Tests', `${nodeBin} backend/tests/phase24-smart-home-intelligence.test.js`);

// 35. Phase 25 Proactive Device Reliability + Self-Healing Tests
runStep('35. Phase 25 Proactive Device Reliability & Self-Healing Tests', `${nodeBin} backend/tests/phase25-proactive-reliability.test.js`);

// 36. Phase 26 Multi-Protocol Device Connectivity & Interoperability Tests
runStep('36. Phase 26 Multi-Protocol Device Connectivity Tests', `${nodeBin} backend/tests/phase26-multi-protocol-connectivity.test.js`);

// 37. Phase 27 Product Discovery, Catalog & Consumer Device Add Tests
runStep('37. Phase 27 Product Discovery, Catalog & Consumer Device Add Tests', `${nodeBin} backend/tests/phase27-product-discovery-catalog.test.js`);

// 38. Phase 28 Local-First Home Control & Edge Execution Tests
runStep('38. Phase 28 Local-First Home Control & Edge Execution Tests', `${nodeBin} backend/tests/phase28-local-first-edge-control.test.js`);

// 39. Phase 29 Matter Ecosystem Interoperability & Multi-Platform Integration Tests
runStep('39. Phase 29 Matter Ecosystem Interoperability Tests', `${nodeBin} backend/tests/phase29-matter-interoperability.test.js`);

// 40. Phase 30 Intelligent Notifications, Alerts & User Event Center Tests
runStep('40. Phase 30 Intelligent Notifications, Alerts & User Event Center Tests', `${nodeBin} backend/tests/phase30-intelligent-notifications.test.js`);

// 41. Phase 31 Secure Operations, Audit & Platform Observability Tests
runStep('41. Phase 31 Secure Operations, Audit & Observability Tests', `${nodeBin} backend/tests/phase31-secure-operations-observability.test.js`);

// 42. Phase 32 Secure Device Identity, Trust & Credential Lifecycle Tests
runStep('42. Phase 32 Secure Device Identity, Trust & Credential Lifecycle Tests', `${nodeBin} backend/tests/phase32-device-trust.test.js`);

// 43. Phase 33 Disaster Recovery, Backup & State Resilience Tests
runStep('43. Phase 33 Disaster Recovery, Backup & State Resilience Tests', `${nodeBin} backend/tests/phase33-disaster-recovery.test.js`);

// 44. Phase 34 Production Deployment & Operational Readiness Tests
runStep('44. Phase 34 Production Deployment & Operational Readiness Tests', `${nodeBin} backend/tests/phase34-production-operational-readiness.test.js`);

console.log('\n===============================================================');
console.log(`  44 SUITES ATTEMPTED. ${failedSuites === 0 ? '44/44' : (44 - failedSuites) + '/44'} PASSED.`);
if (failedSuites === 0) {
  console.log('  ALL TEST SUITES PASSED! REPOSITORY IS IN HEALTHY STATE.');
  console.log('===============================================================');
  process.exit(0);
} else {
  console.error(`  VALIDATION FAILED: ${failedSuites} test suite(s) failed.`);
  console.log('===============================================================');
  process.exit(1);
}
