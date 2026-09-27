/**
 * EH Home Desktop UI Reconciliation Test Suite (Parts 05–11)
 *
 * Validates:
 * 1. Sidebar navigation resolution across all 11 domains (zero placeholder screens for completed parts)
 * 2. Products (Part 05) workspace & canonical catalog integration
 * 3. Hardware & BOM (Part 06) workspace & BOM specification integration
 * 4. Firmware & Releases (Part 07/08) workspace & canonical lifecycle integration
 * 5. Bench Provisioner (Part 09) native boundary & 8-gate validation
 * 6. Label & QR Printer (Part 10) canonical QR & TSPL integration
 * 7. Device Fleet (Parts 07/09/11) device records & registration status
 * 8. Production & QC (Parts 09/11) station verification logs & FPY telemetry
 * 9. Packing & Dual-Scan (Part 11) dual-scan verification & match enforcement
 * 10. Finished Goods Inventory (Part 11) stock registry & master carton management
 * 11. Settings foundation & clear future separation
 * 12. Static data audit & single source of truth verification
 */

import assert from 'assert';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

async function runTest(name, fn) {
  totalTests++;
  try {
    await fn();
    console.log(`  [PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  [FAIL] ${name}: ${err.message}`);
    failedTests++;
  }
}

async function main() {
  console.log('=== EH HOME DESKTOP UI RECONCILIATION TESTS (PARTS 05–11) ===\n');

  const desktopDir = path.join(__dirname, '..');
  const srcDir = path.join(desktopDir, 'src');

  // ── 1. SIDEBAR & ROUTING RESOLUTION ───────────────────────────────────
  console.log('1. Navigation & Route Resolution:');

  await runTest('Sidebar defines all 11 platform domains with accurate Part badges', () => {
    const sidebarSource = fs.readFileSync(path.join(srcDir, 'components/Sidebar.tsx'), 'utf8');
    const expectedTabs = [
      'dashboard', 'products', 'hardware', 'firmware',
      'provisioner', 'labels', 'devices', 'production',
      'packing', 'inventory', 'settings'
    ];

    expectedTabs.forEach((tab) => {
      assert.ok(sidebarSource.includes(`id: '${tab}'`), `Sidebar must contain navigation tab '${tab}'`);
    });

    // Zero placeholder flags in completed parts
    assert.strictEqual(sidebarSource.includes('isPlaceholder: true'), false, 'Completed parts must not have isPlaceholder: true');
  });

  await runTest('App.tsx mounts dedicated domain view components for every completed domain', () => {
    const appSource = fs.readFileSync(path.join(srcDir, 'App.tsx'), 'utf8');
    assert.ok(appSource.includes('<DashboardView />'), 'App.tsx must mount DashboardView');
    assert.ok(appSource.includes('<ProductsView />'), 'App.tsx must mount ProductsView');
    assert.ok(appSource.includes('<HardwareBomView />'), 'App.tsx must mount HardwareBomView');
    assert.ok(appSource.includes('<FirmwareReleasesView />'), 'App.tsx must mount FirmwareReleasesView');
    assert.ok(appSource.includes('<ProvisionerView />'), 'App.tsx must mount ProvisionerView');
    assert.ok(appSource.includes('<LabelPrinterView />'), 'App.tsx must mount LabelPrinterView');
    assert.ok(appSource.includes('<DeviceFleetView />'), 'App.tsx must mount DeviceFleetView');
    assert.ok(appSource.includes('<ProductionQcView />'), 'App.tsx must mount ProductionQcView');
    assert.ok(appSource.includes('<ProductionPackingView />'), 'App.tsx must mount ProductionPackingView');
    assert.ok(appSource.includes('<InventoryView />'), 'App.tsx must mount InventoryView');
    assert.ok(appSource.includes('<SettingsView />'), 'App.tsx must mount SettingsView');
  });

  // ── 2. PRODUCTS (PART 05) WORKSPACE ──────────────────────────────────
  console.log('\n2. Products Workspace (Part 05):');

  await runTest('ProductsView consumes apps/api /api/v1/products & @eh-home/contracts', () => {
    const prodSource = fs.readFileSync(path.join(srcDir, 'features/products/ProductsView.tsx'), 'utf8');
    assert.ok(prodSource.includes('apiClient.listProducts'), 'ProductsView must invoke apiClient.listProducts');
    assert.ok(prodSource.includes('apiClient.listProductFamilies'), 'ProductsView must invoke apiClient.listProductFamilies');
    assert.ok(prodSource.includes('CANONICAL_PRODUCT_DEFINITIONS'), 'ProductsView must consume canonical contracts as baseline');
    assert.ok(prodSource.includes('compatibleHardwareRevisions'), 'ProductsView must render hardware compatibility');
    assert.ok(prodSource.includes('capabilities'), 'ProductsView must render capability badges');
  });

  // ── 3. HARDWARE & BOM (PART 06) WORKSPACE ────────────────────────────
  console.log('\n3. Hardware & BOM Workspace (Part 06):');

  await runTest('HardwareBomView exposes PCB revisions, BOM specs, MPNs and Gerber checksums', () => {
    const hwSource = fs.readFileSync(path.join(srcDir, 'features/hardware/HardwareBomView.tsx'), 'utf8');
    assert.ok(hwSource.includes('apiClient.listHardwareRevisions'), 'HardwareBomView must invoke apiClient.listHardwareRevisions');
    assert.ok(hwSource.includes('apiClient.getBOM'), 'HardwareBomView must invoke apiClient.getBOM');
    assert.ok(hwSource.includes('CANONICAL_HARDWARE_REVISIONS'), 'HardwareBomView must reference canonical revisions');
    assert.ok(hwSource.includes('gerberSha256'), 'HardwareBomView must expose Gerber integrity');
    assert.ok(hwSource.includes('manufacturerPartNumber'), 'HardwareBomView must display MPNs');
  });

  // ── 4. FIRMWARE & RELEASES (PART 07/08) WORKSPACE ────────────────────
  console.log('\n4. Firmware & Releases Workspace (Part 07 & 08):');

  await runTest('FirmwareReleasesView preserves canonical 7-stage lifecycle and cryptographic SHA-256', () => {
    const fwSource = fs.readFileSync(path.join(srcDir, 'features/firmware/FirmwareReleasesView.tsx'), 'utf8');
    assert.ok(fwSource.includes('apiClient.listFirmwareReleases'), 'FirmwareReleasesView must invoke apiClient.listFirmwareReleases');
    assert.ok(fwSource.includes('DRAFT'), 'Must include DRAFT state');
    assert.ok(fwSource.includes('BUILDING'), 'Must include BUILDING state');
    assert.ok(fwSource.includes('VALIDATION'), 'Must include VALIDATION state');
    assert.ok(fwSource.includes('APPROVED'), 'Must include APPROVED state');
    assert.ok(fwSource.includes('RELEASED'), 'Must include RELEASED state');
    assert.ok(fwSource.includes('DEPRECATED'), 'Must include DEPRECATED state');
    assert.ok(fwSource.includes('REVOKED'), 'Must include REVOKED terminal state');
    assert.ok(fwSource.includes('sha256'), 'Must display cryptographic artifact SHA-256');
  });

  // ── 5. BENCH PROVISIONER (PART 09) NATIVE INTEGRATION ────────────────
  console.log('\n5. Bench Provisioner (Part 09):');

  await runTest('Bench Provisioner is integrated with Tauri native boundary', () => {
    const provSource = fs.readFileSync(path.join(srcDir, 'features/provisioner/ProvisionerView.tsx'), 'utf8');
    assert.ok(provSource.includes('getSerialService'), 'ProvisionerView must use getSerialService');
    assert.ok(provSource.includes('getFlasherService'), 'ProvisionerView must use getFlasherService');
    assert.ok(provSource.includes('BenchArtifactValidationResult'), 'Must enforce artifact validation');
    assert.ok(provSource.includes('BenchProvisioningTraceabilityRecord'), 'Must record structured traceability');
  });

  // ── 6. LABEL & QR PRINTER (PART 10) INTEGRATION ──────────────────────
  console.log('\n6. Label & QR Printer (Part 10):');

  await runTest('Label printer view renders canonical QR format and TSPL preview', () => {
    const labelSource = fs.readFileSync(path.join(srcDir, 'features/label-printer/LabelPrinterView.tsx'), 'utf8');
    assert.ok(labelSource.includes('printerService'), 'Must use printerService');
    assert.ok(labelSource.includes('validatePrintJob'), 'Must enforce 8-gate print validation');
  });

  // ── 7. DEVICE FLEET (PARTS 07/09/11) WORKSPACE ───────────────────────
  console.log('\n7. Device Fleet Workspace:');

  await runTest('DeviceFleetView exposes device records & registration without out-of-scope telemetry', () => {
    const devSource = fs.readFileSync(path.join(srcDir, 'features/devices/DeviceFleetView.tsx'), 'utf8');
    assert.ok(devSource.includes('serialNumber'), 'Must display serial number');
    assert.ok(devSource.includes('productVariantId'), 'Must display product variant ID');
    assert.ok(devSource.includes('hardwareRevision'), 'Must display hardware revision');
    assert.ok(devSource.includes('firmwareVersion'), 'Must display firmware version');
    assert.ok(devSource.includes('Scope Invariant'), 'Must explicitly acknowledge Part 13 telemetry boundary');
  });

  // ── 8. PRODUCTION & QC (PARTS 09/11) WORKSPACE ───────────────────────
  console.log('\n8. Production & QC Workspace:');

  await runTest('ProductionQcView renders station logs, first-pass yield, and station pass/fail audit trail', () => {
    const qcSource = fs.readFileSync(path.join(srcDir, 'features/production/ProductionQcView.tsx'), 'utf8');
    assert.ok(qcSource.includes('First-Pass Yield'), 'Must compute and display FPY');
    assert.ok(qcSource.includes('Station Verification Audit Trail'), 'Must display verification logs');
    assert.ok(qcSource.includes('FLASHING_BENCH'), 'Must support flashing bench logs');
    assert.ok(qcSource.includes('DUAL_SCAN_PACKING'), 'Must support dual-scan packing logs');
  });

  // ── 9. PACKING & DUAL-SCAN (PART 11) WORKSPACE ───────────────────────
  console.log('\n9. Packing & Dual-Scan Workspace:');

  await runTest('ProductionPackingView enforces dual-scan scan A and scan B workflow', () => {
    const packSource = fs.readFileSync(path.join(srcDir, 'features/packing/ProductionPackingView.tsx'), 'utf8');
    assert.ok(packSource.includes('apiClient.dualScanVerify'), 'Must invoke dualScanVerify endpoint');
    assert.ok(packSource.includes('apiClient.completePacking'), 'Must invoke completePacking endpoint');
    assert.ok(packSource.includes('Scan A'), 'Must include Scan A step');
    assert.ok(packSource.includes('Scan B'), 'Must include Scan B step');
  });

  // ── 10. FINISHED GOODS INVENTORY (PART 11) WORKSPACE ──────────────────
  console.log('\n10. Finished Goods Inventory Workspace:');

  await runTest('InventoryView exposes warehouse stock, master cartons, and packed unit registry', () => {
    const invSource = fs.readFileSync(path.join(srcDir, 'features/inventory/InventoryView.tsx'), 'utf8');
    assert.ok(invSource.includes('apiClient.getPackingHistory'), 'Must query inventory history');
    assert.ok(invSource.includes('Active Master Cartons'), 'Must compute carton allocations');
    assert.ok(invSource.includes('Stock Registry'), 'Must render finished goods table');
  });

  // ── 11. SETTINGS & FUTURE SEPARATION ─────────────────────────────────
  console.log('\n11. Settings & Future Separation:');

  await runTest('SettingsView configures local hardware/API settings and active Part 13-16 cloud integration', () => {
    const setSource = fs.readFileSync(path.join(srcDir, 'features/settings/SettingsView.tsx'), 'utf8');
    assert.ok(setSource.includes('API Base URL'), 'Must configure API base URL');
    assert.ok(setSource.includes('Default COM Port'), 'Must configure COM port');
    assert.ok(setSource.includes('Default Label Printer'), 'Must configure printer');
    assert.ok(setSource.includes('Cloud Sync, MQTT Broker & Storage Integration'), 'Must include active cloud integration');
  });

  // ── 12. STATIC DATA & ARCHITECTURAL PURITY AUDIT ─────────────────────
  console.log('\n12. Static Data & Architectural Purity:');

  await runTest('No stale "Scheduled for Part 05/06/07" placeholder text remains in active UI views', () => {
    const views = [
      'features/products/ProductsView.tsx',
      'features/hardware/HardwareBomView.tsx',
      'features/firmware/FirmwareReleasesView.tsx',
      'features/devices/DeviceFleetView.tsx',
      'features/production/ProductionQcView.tsx',
      'features/inventory/InventoryView.tsx',
      'features/settings/SettingsView.tsx'
    ];

    views.forEach((v) => {
      const content = fs.readFileSync(path.join(srcDir, v), 'utf8');
      assert.strictEqual(content.includes('Implementation deferred by design'), false, `${v} must not contain deferred placeholders`);
      assert.strictEqual(content.includes('Scheduled for Part 05'), false, `${v} must not contain Part 05 placeholder`);
      assert.strictEqual(content.includes('Scheduled for Part 06'), false, `${v} must not contain Part 06 placeholder`);
    });
  });

  console.log('\n========================================');
  console.log(`Total Passed: ${passedTests}, Total Failed: ${failedTests}`);
  console.log('========================================');

  if (failedTests > 0) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
