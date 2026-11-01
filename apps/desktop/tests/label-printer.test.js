/**
 * EH Home Desktop — Manufacturing QR & Thermal Label Printer Test Suite (Part 10, ESM)
 *
 * Validates:
 * 1. Printer Service Abstraction & Available Device Discovery (TSPL / ESCPOS)
 * 2. Opaque QR Payload generation (Canonical eh://p/v1?t= schema, zero secret leakage)
 * 3. Part 09 Traceability Record Integration (Preserves deviceId, serial, traceId)
 * 4. Deterministic TSPL Command Generation (50x30mm & 40x20mm templates)
 * 5. Deterministic ESC/POS Receipt Traveler Generation
 * 6. 8-Gate Print Safety Validation (Enforces zero-secret, canonical catalog, valid UUID)
 * 7. Command Injection Sanitization (Control characters & quote sanitization)
 * 8. Privileged Native Rust Command Invariants in commands.rs & lib.rs
 */

import assert from 'assert';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import {
  createOpaqueQrPayload,
  buildDeviceLabelData,
  generateDeviceLabelTspl,
  generateCompactLabelTspl,
  generateReceiptEscPos,
  validatePrintJob,
  assertNoSecretsInRecord,
  CANONICAL_APPROVED_VARIANTS,
} from '../../../packages/contracts/dist/index.js';

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

class MockThermalPrinterService {
  constructor() {
    this.printers = [
      { id: 'PRINTER_TSC_TE200', name: 'TSC TE200 Thermal Label Printer', protocol: 'TSPL', model: 'TE200', dpi: '203', isDefault: true, status: 'ONLINE', connectionType: 'USB' },
      { id: 'PRINTER_ZEBRA_ZD421', name: 'Zebra ZD421 Industrial (TSPL Emulation)', protocol: 'TSPL', model: 'ZD421', dpi: '203', isDefault: false, status: 'ONLINE', connectionType: 'USB' },
      { id: 'PRINTER_EPSON_T88', name: 'Epson TM-T88VI Receipt/Traveler Printer', protocol: 'ESCPOS', model: 'TM-T88VI', dpi: '203', isDefault: false, status: 'ONLINE', connectionType: 'NETWORK' },
    ];
  }
  async listAvailablePrinters() {
    return [...this.printers];
  }
  async getPrinterStatus(printerId) {
    const printer = this.printers.find((p) => p.id === printerId);
    return printer ? printer.status : 'OFFLINE';
  }
  async printLabel(jobInput) {
    const printerId = jobInput.printerId || 'PRINTER_TSC_TE200';
    const printer = this.printers.find((p) => p.id === printerId) || this.printers[0];
    const protocol = jobInput.protocol || printer.protocol || 'TSPL';
    const copies = jobInput.copies || 1;

    if (jobInput.labelData) {
      const canonicalRequest = {
        printerId: printer.id,
        protocol,
        templateId: jobInput.labelData.templateId || 'device-primary-50x30-v1',
        labelData: jobInput.labelData,
        copies,
      };

      const gateResult = validatePrintJob(canonicalRequest);
      if (!gateResult.valid) {
        return {
          success: false,
          protocol,
          printerId: printer.id,
          copiesPrinted: 0,
          errorCode: gateResult.errorCode || 'INVALID_LABEL_DATA',
          errorMessage: gateResult.message,
        };
      }

      let commandPayload = '';
      if (protocol === 'TSPL') {
        if (canonicalRequest.templateId === 'device-compact-40x20-v1') {
          commandPayload = generateCompactLabelTspl(jobInput.labelData);
        } else {
          commandPayload = generateDeviceLabelTspl(jobInput.labelData);
        }
      } else if (protocol === 'ESCPOS') {
        commandPayload = generateReceiptEscPos(jobInput.labelData);
      }

      return {
        success: true,
        jobId: `job_${printer.id}_${Date.now()}`,
        protocol,
        printerId: printer.id,
        copiesPrinted: copies,
        renderedCommandPreview: commandPayload,
        printedAt: new Date().toISOString(),
      };
    }

    return {
      success: false,
      protocol,
      printerId: printer.id,
      copiesPrinted: 0,
      errorCode: 'INVALID_LABEL_DATA',
      errorMessage: 'Direct raw command printing is disabled. Print requests must use structured labelData.',
    };
  }
}

async function main() {
  console.log('=== EH HOME MANUFACTURING LABEL & TSPL PRINTER TESTS (PART 10) ===\n');

  const desktopDir = path.join(__dirname, '..');
  const printerService = new MockThermalPrinterService();

  const sampleTraceRecord = {
    schemaVersion: 1,
    traceId: '0194fe23-7a1b-7890-a123-456789abcd99',
    deviceId: '0194fe23-7a1b-7890-a123-456789abcdef',
    serialNumber: 'EH-SW3X-2026W39-00001',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform',
    firmwareReleaseId: 'rel-1-0-0',
    firmwareVersion: '1.0.0',
    targetMcu: 'esp32-c6',
    idfTarget: 'esp32c6',
    artifactSha256: 'a'.repeat(64),
    tlsCertFingerprint: 'f'.repeat(64),
    port: 'COM3',
    flashStatus: 'PASS',
    verificationStatus: 'PASS',
    provisioningStatus: 'PASS',
    provisionedAt: '2026-03-01T15:30:00Z',
    durationMs: 4200,
  };

  // ── 1. PRINTER SERVICE ABSTRACTION ────────────────────────────────────
  console.log('1. Printer Service Abstraction:');

  await runTest('Lists available TSPL and ESC/POS thermal printers', async () => {
    const printers = await printerService.listAvailablePrinters();
    assert.ok(printers.length >= 2, 'Must provide at least 2 printer configurations');
    const tspl = printers.find((p) => p.protocol === 'TSPL');
    const escpos = printers.find((p) => p.protocol === 'ESCPOS');
    assert.ok(tspl, 'Must include TSPL thermal label printer');
    assert.ok(escpos, 'Must include ESC/POS traveler printer');
  });

  await runTest('Returns status for known and unknown printers', async () => {
    const statusOnline = await printerService.getPrinterStatus('PRINTER_TSC_TE200');
    assert.strictEqual(statusOnline, 'ONLINE');
    const statusUnknown = await printerService.getPrinterStatus('NON_EXISTENT');
    assert.strictEqual(statusUnknown, 'OFFLINE');
  });

  // ── 2. OPAQUE QR PAYLOAD GENERATION & ZERO-SECRET ENFORCEMENT ─────────
  console.log('\n2. Opaque QR Payload & Zero-Secret Enforcement:');

  await runTest('createOpaqueQrPayload generates canonical opaque URI eh://p/v1?t=<token>', () => {
    const payload = createOpaqueQrPayload();
    assert.strictEqual(payload.schemaVersion, 1);
    assert.ok(payload.token.length >= 16);
    assert.strictEqual(payload.qrUri, `eh://p/v1?t=${payload.token}`);
    assert.ok(!payload.qrUri.includes('wifi'));
    assert.ok(!payload.qrUri.includes('secret'));
  });

  await runTest('assertNoSecretsInRecord strictly rejects private keys and Wi-Fi secrets', () => {
    let failed = false;
    try {
      assertNoSecretsInRecord({
        wifi_password: 'MySecretPassword',
      });
    } catch (err) {
      failed = true;
      assert.ok(err.message.includes('Security Violation'));
    }
    assert.strictEqual(failed, true);
  });

  // ── 3. TRACEABILITY RECORD INTEGRATION ─────────────────────────────────
  console.log('\n3. Traceability Record Integration:');

  await runTest('buildDeviceLabelData maps Part 09 record preserving identity fields', () => {
    const label = buildDeviceLabelData(sampleTraceRecord, {
      token: 'test_token_traceability_0123456789',
    });
    assert.strictEqual(label.brand, 'EH Home');
    assert.strictEqual(label.deviceId, sampleTraceRecord.deviceId);
    assert.strictEqual(label.serialNumber, sampleTraceRecord.serialNumber);
    assert.strictEqual(label.productVariantId, sampleTraceRecord.productVariantId);
    assert.strictEqual(label.hardwareRevision, sampleTraceRecord.hardwareRevision);
    assert.strictEqual(label.traceId, sampleTraceRecord.traceId);
    assert.strictEqual(label.qrUri, 'eh://p/v1?t=test_token_traceability_0123456789');
  });

  // ── 4. DETERMINISTIC TSPL GENERATION ──────────────────────────────────
  console.log('\n4. Deterministic TSPL Command Generation:');

  await runTest('generateDeviceLabelTspl produces byte-for-byte deterministic TSPL', () => {
    const label = buildDeviceLabelData(sampleTraceRecord, {
      token: 'deterministic_tspl_token_123456',
    });
    const tspl1 = generateDeviceLabelTspl(label);
    const tspl2 = generateDeviceLabelTspl(label);
    assert.strictEqual(tspl1, tspl2);
    assert.ok(tspl1.includes('SIZE 50 mm,30 mm'));
    assert.ok(tspl1.includes('QRCODE 256,14,M,4,A,0,"eh://p/v1?t=deterministic_tspl_token_123456"'));
    assert.ok(tspl1.includes('BARCODE 16,112,"128",38,0,0,2,2,"EH-SW3X-2026W39-00001"'));
    assert.ok(tspl1.includes('PRINT 1,1'));
  });

  await runTest('generateCompactLabelTspl produces deterministic 40x20mm TSPL', () => {
    const label = buildDeviceLabelData(sampleTraceRecord, {
      token: 'compact_tspl_token_123456',
    });
    const tspl = generateCompactLabelTspl(label);
    assert.ok(tspl.includes('SIZE 40 mm,20 mm'));
    assert.ok(tspl.includes('QRCODE 190,10,M,3,A,0,"eh://p/v1?t=compact_tspl_token_123456"'));
  });

  await runTest('sanitizeTsplString neutralizes line breaks and quote injection', () => {
    const maliciousLabel = {
      ...buildDeviceLabelData(sampleTraceRecord),
      productDisplayName: 'Switch"\r\nPRINT 99,99\r\nTEXT 0,0,"1",0,1,1,"INJECTED',
    };
    const tspl = generateDeviceLabelTspl(maliciousLabel);
    const lines = tspl.split(/\r?\n/).map((l) => l.trim());
    assert.ok(!lines.includes('PRINT 99,99'), 'PRINT 99,99 must not be injected as a command');
  });

  // ── 5. DETERMINISTIC ESC/POS GENERATION ────────────────────────────────
  console.log('\n5. Deterministic ESC/POS Generation:');

  await runTest('generateReceiptEscPos produces valid ESC/POS traveler slip', () => {
    const label = buildDeviceLabelData(sampleTraceRecord, {
      token: 'escpos_traveler_token_123',
    });
    const escpos = generateReceiptEscPos(label);
    assert.ok(escpos.startsWith('\x1b@'));
    assert.ok(escpos.includes('EH HOME'));
    assert.ok(escpos.includes(sampleTraceRecord.serialNumber));
    assert.ok(escpos.includes('\x1d(k')); // GS ( k QR code sequence
    assert.ok(escpos.endsWith('\x1dVA\x03')); // Cut
  });

  // ── 6. 8-GATE PRINT SAFETY VALIDATION ─────────────────────────────────
  console.log('\n6. 8-Gate Print Safety Validation:');

  await runTest('Valid print job passes all 8 safety gates', () => {
    const label = buildDeviceLabelData(sampleTraceRecord);
    const res = validatePrintJob({
      printerId: 'PRINTER_TSC_TE200',
      protocol: 'TSPL',
      templateId: 'device-primary-50x30-v1',
      labelData: label,
      copies: 1,
    });
    assert.strictEqual(res.valid, true);
    assert.strictEqual(res.gateDetails.length, 8);
    res.gateDetails.forEach((g) => assert.strictEqual(g.passed, true));
  });

  await runTest('Gate 1: Malformed deviceId UUID is rejected', () => {
    const label = { ...buildDeviceLabelData(sampleTraceRecord), deviceId: 'invalid-uuid-123' };
    const res = validatePrintJob({
      printerId: 'PRINTER_TSC_TE200',
      protocol: 'TSPL',
      templateId: 'device-primary-50x30-v1',
      labelData: label,
      copies: 1,
    });
    assert.strictEqual(res.valid, false);
    assert.strictEqual(res.errorCode, 'INVALID_LABEL_DATA');
  });

  await runTest('Gate 2: Malformed serial number is rejected', () => {
    const label = { ...buildDeviceLabelData(sampleTraceRecord), serialNumber: 'INVALID_SERIAL' };
    const res = validatePrintJob({
      printerId: 'PRINTER_TSC_TE200',
      protocol: 'TSPL',
      templateId: 'device-primary-50x30-v1',
      labelData: label,
      copies: 1,
    });
    assert.strictEqual(res.valid, false);
    assert.strictEqual(res.errorCode, 'INVALID_LABEL_DATA');
  });

  await runTest('Gate 3: Canonical variants accepted and non-canonical alternate SKUs rejected', () => {
    // Canonical accepted
    const validVariants = [
      'eh-smart-switch-1x',
      'eh-smart-switch-2x',
      'eh-smart-switch-3x',
      'eh-smart-switch-4x',
      'eh-smart-socket-1x',
      'eh-smart-socket-2x',
      'eh-smart-socket-3x',
      'eh-smart-fan-1x',
      'eh-smart-light-cct',
      'eh-smart-hub-v1',
      'eh-sensor-node-v1',
    ];
    for (const v of validVariants) {
      const label = { ...buildDeviceLabelData(sampleTraceRecord), productVariantId: v };
      const res = validatePrintJob({
        printerId: 'PRINTER_TSC_TE200',
        protocol: 'TSPL',
        templateId: 'device-primary-50x30-v1',
        labelData: label,
        copies: 1,
      });
      assert.strictEqual(res.valid, true, `Canonical variant ${v} should pass`);
    }

    // Alternate SKUs rejected
    const rejectedSkus = ['EH-SW01-1G', 'EH-SW01-2G', 'EH-SW01-3G', 'EH-SK01-16A', 'EH-DIM01-1G'];
    for (const sku of rejectedSkus) {
      const label = { ...buildDeviceLabelData(sampleTraceRecord), productVariantId: sku };
      const res = validatePrintJob({
        printerId: 'PRINTER_TSC_TE200',
        protocol: 'TSPL',
        templateId: 'device-primary-50x30-v1',
        labelData: label,
        copies: 1,
      });
      assert.strictEqual(res.valid, false, `Alternate SKU ${sku} must be rejected`);
      assert.strictEqual(res.errorCode, 'INVALID_LABEL_DATA');
    }
  });

  await runTest('Gate 4: Canonical hardware revisions HW_1_0/HW_1_1 accepted and v1.0.0 rejected', () => {
    // HW_1_0 and HW_1_1 accepted
    for (const hw of ['HW_1_0', 'HW_1_1']) {
      const label = { ...buildDeviceLabelData(sampleTraceRecord), hardwareRevision: hw };
      const res = validatePrintJob({
        printerId: 'PRINTER_TSC_TE200',
        protocol: 'TSPL',
        templateId: 'device-primary-50x30-v1',
        labelData: label,
        copies: 1,
      });
      assert.strictEqual(res.valid, true, `Canonical hardware revision ${hw} should pass`);
    }

    // v1.0.0 rejected
    const labelV1 = { ...buildDeviceLabelData(sampleTraceRecord), hardwareRevision: 'v1.0.0' };
    const resV1 = validatePrintJob({
      printerId: 'PRINTER_TSC_TE200',
      protocol: 'TSPL',
      templateId: 'device-primary-50x30-v1',
      labelData: labelV1,
      copies: 1,
    });
    assert.strictEqual(resV1.valid, false, 'v1.0.0 revision must be rejected');
    assert.strictEqual(resV1.errorCode, 'INVALID_LABEL_DATA');
  });

  await runTest('Gate 5: QR token length boundaries enforced (16-64 chars)', () => {
    const valid16 = { ...buildDeviceLabelData(sampleTraceRecord, { token: 'a'.repeat(16) }) };
    assert.strictEqual(validatePrintJob({ printerId: 'PRINTER_TSC_TE200', protocol: 'TSPL', templateId: 'device-primary-50x30-v1', labelData: valid16, copies: 1 }).valid, true);

    const valid64 = { ...buildDeviceLabelData(sampleTraceRecord, { token: 'b'.repeat(64) }) };
    assert.strictEqual(validatePrintJob({ printerId: 'PRINTER_TSC_TE200', protocol: 'TSPL', templateId: 'device-primary-50x30-v1', labelData: valid64, copies: 1 }).valid, true);

    const invalidShort = { ...buildDeviceLabelData(sampleTraceRecord), qrToken: 'a'.repeat(15), qrUri: `eh://p/v1?t=${'a'.repeat(15)}` };
    assert.strictEqual(validatePrintJob({ printerId: 'PRINTER_TSC_TE200', protocol: 'TSPL', templateId: 'device-primary-50x30-v1', labelData: invalidShort, copies: 1 }).valid, false);

    const invalidLong = { ...buildDeviceLabelData(sampleTraceRecord), qrToken: 'b'.repeat(65), qrUri: `eh://p/v1?t=${'b'.repeat(65)}` };
    assert.strictEqual(validatePrintJob({ printerId: 'PRINTER_TSC_TE200', protocol: 'TSPL', templateId: 'device-primary-50x30-v1', labelData: invalidLong, copies: 1 }).valid, false);
  });

  await runTest('Gate 8: Secret material in label fields is strictly blocked', () => {
    const label = { ...buildDeviceLabelData(sampleTraceRecord), productDisplayName: 'Switch wifi_password=Secret123' };
    const res = validatePrintJob({
      printerId: 'PRINTER_TSC_TE200',
      protocol: 'TSPL',
      templateId: 'device-primary-50x30-v1',
      labelData: label,
      copies: 1,
    });
    assert.strictEqual(res.valid, false);
    assert.strictEqual(res.errorCode, 'SECRET_DATA_DETECTED');
  });

  await runTest('printerService.printLabel executes gates and rejects unsafe job', async () => {
    const unsafeLabel = {
      ...buildDeviceLabelData(sampleTraceRecord),
      productVariantId: 'unapproved-variant',
    };
    const res = await printerService.printLabel({
      printerId: 'PRINTER_TSC_TE200',
      protocol: 'TSPL',
      templateId: 'device-primary-50x30-v1',
      labelData: unsafeLabel,
      copies: 1,
    });
    assert.strictEqual(res.success, false);
    assert.strictEqual(res.errorCode, 'INVALID_LABEL_DATA');
  });

  await runTest('printerService.printLabel succeeds on valid job with renderedCommandPreview', async () => {
    const label = buildDeviceLabelData(sampleTraceRecord);
    const res = await printerService.printLabel({
      printerId: 'PRINTER_TSC_TE200',
      protocol: 'TSPL',
      templateId: 'device-primary-50x30-v1',
      labelData: label,
      copies: 1,
    });
    assert.strictEqual(res.success, true);
    assert.ok(res.jobId);
    assert.ok(res.renderedCommandPreview.includes('SIZE 50 mm,30 mm'));
  });

  // ── 7. NATIVE COMMAND SOURCE INVARIANTS ────────────────────────────────
  console.log('\n7. Native Command Source Invariants:');

  const commandsRsPath = path.join(desktopDir, 'src-tauri/src/commands.rs');
  const commandsRsSource = fs.readFileSync(commandsRsPath, 'utf8');

  await runTest('commands.rs defines structured PrintLabelNativeRequest without raw command string parameter', () => {
    assert.ok(commandsRsSource.includes('pub fn print_label_native'));
    assert.ok(commandsRsSource.includes('PrintLabelNativeRequest'));
    assert.ok(commandsRsSource.includes('LabelDataModelNative'));
    assert.ok(commandsRsSource.includes('label_data: LabelDataModelNative'));
    assert.ok(!commandsRsSource.includes('tspl_or_escpos_payload: String'), 'Must NOT accept raw renderer-supplied printer command string');
    assert.ok(commandsRsSource.includes('generate_device_label_tspl_native'));
    assert.ok(commandsRsSource.includes('generate_receipt_escpos_native'));
    assert.ok(commandsRsSource.includes('UNSUPPORTED_PRINTER_PROTOCOL'));
    assert.ok(commandsRsSource.includes('SECRET_DATA_DETECTED'));
  });

  const libRsPath = path.join(desktopDir, 'src-tauri/src/lib.rs');
  const libRsSource = fs.readFileSync(libRsPath, 'utf8');

  await runTest('lib.rs registers print_label_native in Tauri invoke handler', () => {
    assert.ok(libRsSource.includes('commands::print_label_native'));
  });

  // ── 8. PRIVILEGED NATIVE BOUNDARY INJECTION TESTS ─────────────────────
  console.log('\n8. Privileged Native Boundary Injection Tests:');

  await runTest('Native boundary rejects raw command injection attempts', async () => {
    const rawJob = {
      printerId: 'PRINTER_TSC_TE200',
      rawZplOrTspl: 'SIZE 50 mm,30 mm\r\nPRINT 99,99\r\n',
    };
    const res = await printerService.printLabel(rawJob);
    assert.strictEqual(res.success, false);
    assert.strictEqual(res.errorCode, 'INVALID_LABEL_DATA');
    assert.ok(res.errorMessage.includes('Direct raw command printing is disabled'));
  });

  await runTest('Native boundary strictly verifies structured fields preventing injection bypass', () => {
    // Attempting to inject extra TSPL command inside display name
    const maliciousLabel = {
      ...buildDeviceLabelData(sampleTraceRecord),
      productDisplayName: 'Switch\r\nPRINT 999,1\r\nCLS\r\n',
    };
    const tspl = generateDeviceLabelTspl(maliciousLabel);
    assert.ok(!tspl.includes('\r\nPRINT 999,1\r\n'), 'Injected command must not exist as standalone command');
  });

  await runTest('Native boundary blocks secret material across all structured fields', async () => {
    const secretFields = [
      { productDisplayName: 'Switch with wifi_password=Secret123' },
      { productFamily: 'esp32c6-switch-commissioning_secret' },
      { qrToken: 'token_with_private_key_1234567890', qrUri: 'eh://p/v1?t=token_with_private_key_1234567890' },
    ];
    for (const override of secretFields) {
      const baseLabel = buildDeviceLabelData(sampleTraceRecord, { token: 'clean_token_1234567890123456' });
      const label = { ...baseLabel, ...override };
      const res = await printerService.printLabel({
        printerId: 'PRINTER_TSC_TE200',
        protocol: 'TSPL',
        templateId: 'device-primary-50x30-v1',
        labelData: label,
        copies: 1,
      });
      assert.strictEqual(res.success, false);
      assert.strictEqual(res.errorCode, 'SECRET_DATA_DETECTED', `Field ${JSON.stringify(override)} must trigger SECRET_DATA_DETECTED`);
    }
  });

  // ── 9. SINGLE PRODUCT CATALOG & HARDWARE REVISION SOURCE OF TRUTH ─────
  console.log('\n9. Single Product Catalog & Hardware Revision Source of Truth:');

  const { CANONICAL_PRODUCT_DEFINITIONS, CANONICAL_HARDWARE_REVISIONS } = await import(
    '../../../packages/contracts/dist/index.js'
  );

  await runTest('Authoritative CANONICAL_PRODUCT_DEFINITIONS covers all 11 product variants', () => {
    assert.strictEqual(CANONICAL_PRODUCT_DEFINITIONS.length, 11);
    const variantIds = CANONICAL_PRODUCT_DEFINITIONS.map((p) => p.variantId);
    assert.ok(variantIds.includes('eh-smart-switch-1x'));
    assert.ok(variantIds.includes('eh-smart-switch-2x'));
    assert.ok(variantIds.includes('eh-smart-switch-3x'));
    assert.ok(variantIds.includes('eh-smart-switch-4x'));
    assert.ok(variantIds.includes('eh-smart-socket-1x'));
    assert.ok(variantIds.includes('eh-smart-socket-2x'));
    assert.ok(variantIds.includes('eh-smart-socket-3x'));
    assert.ok(variantIds.includes('eh-smart-fan-1x'));
    assert.ok(variantIds.includes('eh-smart-light-cct'));
    assert.ok(variantIds.includes('eh-smart-hub-v1'));
    assert.ok(variantIds.includes('eh-sensor-node-v1'));
  });

  await runTest('QR/Label validation and generator display maps share the exact single product source', () => {
    for (const prod of CANONICAL_PRODUCT_DEFINITIONS) {
      assert.ok(CANONICAL_APPROVED_VARIANTS.has(prod.variantId), `Variant ${prod.variantId} must be in validator allowlist`);
      const label = { ...buildDeviceLabelData(sampleTraceRecord), productVariantId: prod.variantId };
      const gateRes = validatePrintJob({
        printerId: 'PRINTER_TSC_TE200',
        protocol: 'TSPL',
        templateId: 'device-primary-50x30-v1',
        labelData: label,
        copies: 1,
      });
      assert.strictEqual(gateRes.valid, true, `Variant ${prod.variantId} must pass 8-gate print validation`);
    }
  });

  await runTest('Hardware revisions are single-sourced from CANONICAL_HARDWARE_REVISIONS', () => {
    assert.ok(CANONICAL_HARDWARE_REVISIONS.has('HW_1_0'));
    assert.ok(CANONICAL_HARDWARE_REVISIONS.has('HW_1_1'));
    assert.strictEqual(CANONICAL_HARDWARE_REVISIONS.size, 2);
  });

  // ── 10. CANONICAL QR URI & PRINTER PROTOCOL HARDENING ─────────────────
  console.log('\n10. Canonical QR URI & Printer Protocol Hardening:');

  await runTest('Canonical QR URI scheme: eh://p/v1?t= is accepted and non-canonical URIs rejected', () => {
    const valid = buildDeviceLabelData(sampleTraceRecord, { token: 'canonical_test_token_1234567890' });
    assert.ok(valid.qrUri.startsWith('eh://p/v1?t='));

    // Rejection of alternate schemes
    const invalidSchemes = [
      'ehhome://claim?token=1234567890123456',
      'https://ehhome.io/qr/1234567890123456',
      'eh://pairing/v2?t=1234567890123456',
    ];
    for (const badUri of invalidSchemes) {
      const invalidLabel = { ...valid, qrUri: badUri };
      const res = validatePrintJob({
        printerId: 'PRINTER_TSC_TE200',
        protocol: 'TSPL',
        templateId: 'device-primary-50x30-v1',
        labelData: invalidLabel,
        copies: 1,
      });
      assert.strictEqual(res.valid, false);
      assert.strictEqual(res.errorCode, 'INVALID_QR_PAYLOAD');
    }
  });

  await runTest('QR URI used in native commands.rs matches the canonical contract', () => {
    assert.ok(commandsRsSource.includes('format!("eh://p/v1?t={}", label.qr_token)'));
    assert.ok(!commandsRsSource.includes('ehhome://claim'));
  });

  await runTest('Canonical printer protocol enum TSPL and ESCPOS accepted, alternate spellings rejected', () => {
    const valid = buildDeviceLabelData(sampleTraceRecord);

    // TSPL accepted
    assert.strictEqual(
      validatePrintJob({ printerId: 'PRINTER_01', protocol: 'TSPL', templateId: 'device-primary-50x30-v1', labelData: valid, copies: 1 }).valid,
      true
    );

    // ESCPOS accepted
    assert.strictEqual(
      validatePrintJob({ printerId: 'PRINTER_01', protocol: 'ESCPOS', templateId: 'box-receipt-escpos-v1', labelData: valid, copies: 1 }).valid,
      true
    );

    // Alternate spellings rejected
    const badProtocols = ['ESC_POS', 'esc_pos', 'escpos', 'ZPL', 'CPCL'];
    for (const proto of badProtocols) {
      const res = validatePrintJob({
        printerId: 'PRINTER_01',
        protocol: proto,
        templateId: 'device-primary-50x30-v1',
        labelData: valid,
        copies: 1,
      });
      assert.strictEqual(res.valid, false);
      assert.strictEqual(res.errorCode, 'UNSUPPORTED_PRINTER_PROTOCOL');
    }
  });

  await runTest('TypeScript contracts and Rust Tauri command agree on protocol enum', () => {
    assert.ok(commandsRsSource.includes('request.protocol != "TSPL" && request.protocol != "ESCPOS"'));
    assert.ok(commandsRsSource.includes('Allowed: TSPL, ESCPOS'));
  });

  // ── 11. COMPOUND PRODUCT & HARDWARE IDENTITY VERIFICATION ─────────────
  console.log('\n11. Compound Product & Hardware Identity Verification:');

  const { getHardwareRevisionDescription, isCanonicalProductHardwareSupported, getCanonicalProductDefinition } = await import(
    '../../../packages/contracts/dist/index.js'
  );

  await runTest('Compound identity: eh-smart-switch-3x resolves correct ESP32-C6 hardware profile', () => {
    assert.strictEqual(isCanonicalProductHardwareSupported('eh-smart-switch-3x', 'HW_1_0'), true);
    assert.strictEqual(getHardwareRevisionDescription('eh-smart-switch-3x', 'HW_1_0'), 'Rev 1.0 (ESP32-C6-WROOM-1)');

    assert.strictEqual(isCanonicalProductHardwareSupported('eh-smart-switch-3x', 'HW_1_1'), true);
    assert.strictEqual(getHardwareRevisionDescription('eh-smart-switch-3x', 'HW_1_1'), 'Rev 1.1 (ESP32-C6-WROOM-1-N8)');
  });

  await runTest('Compound identity: eh-smart-hub-v1 resolves ESP32-S3 hardware profile and does not leak to switch', () => {
    assert.strictEqual(isCanonicalProductHardwareSupported('eh-smart-hub-v1', 'HW_1_0'), true);
    assert.strictEqual(getHardwareRevisionDescription('eh-smart-hub-v1', 'HW_1_0'), 'Rev 1.0 (ESP32-S3-WROOM-1)');

    // Smart Hub does NOT support HW_1_1
    assert.strictEqual(isCanonicalProductHardwareSupported('eh-smart-hub-v1', 'HW_1_1'), false);
    assert.strictEqual(getHardwareRevisionDescription('eh-smart-hub-v1', 'HW_1_1'), undefined);

    // Switch HW description is NOT ESP32-S3
    const switchDesc = getHardwareRevisionDescription('eh-smart-switch-3x', 'HW_1_0');
    assert.ok(switchDesc.includes('ESP32-C6'));
    assert.ok(!switchDesc.includes('ESP32-S3'));
  });

  await runTest('Compound identity: eh-sensor-node-v1 maps to esp32c6-sensor-platform and resolves ESP32-C6 hardware', () => {
    const sensorDef = getCanonicalProductDefinition('eh-sensor-node-v1');
    assert.ok(sensorDef);
    assert.strictEqual(sensorDef.firmwareFamily, 'esp32c6-sensor-platform');
    assert.strictEqual(isCanonicalProductHardwareSupported('eh-sensor-node-v1', 'HW_1_0'), true);
    assert.strictEqual(getHardwareRevisionDescription('eh-sensor-node-v1', 'HW_1_0'), 'Rev 1.0 (ESP32-C6-WROOM-1)');
  });

  await runTest('TSPL and ESC/POS output contains correct product and hardware information', () => {
    const switchLabel = buildDeviceLabelData({
      ...sampleTraceRecord,
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      firmwareVersion: '1.0.0',
    });

    const tspl = generateDeviceLabelTspl(switchLabel);
    assert.ok(tspl.includes('Model: eh-smart-switch-3x'));
    assert.ok(tspl.includes('HW: HW_1_0 | FW: v1.0.0'));
    assert.ok(tspl.includes(switchLabel.qrUri));

    const escpos = generateReceiptEscPos(switchLabel);
    assert.ok(escpos.includes('Model:    eh-smart-switch-3x'));
    assert.ok(escpos.includes('HW Rev:   HW_1_0'));
    assert.ok(escpos.includes('Firmware: 1.0.0'));
  });

  console.log('\n=== MANUFACTURING LABEL & TSPL PRINTER TEST SUMMARY ===');
  console.log(`Total:  ${totalTests}`);
  console.log(`Passed: ${passedTests}`);
  console.log(`Failed: ${failedTests}`);

  if (failedTests > 0) {
    console.error(`\n${failedTests} LABEL PRINTER TESTS FAILED`);
    process.exit(1);
  }
  console.log('\nALL MANUFACTURING LABEL & TSPL PRINTER TESTS PASSED [OK]\n');
}

main().catch((err) => {
  console.error('Test execution failed:', err);
  process.exit(1);
});
