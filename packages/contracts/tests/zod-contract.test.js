/**
 * EH Home — Zod Contract Validation Test Suite
 *
 * Validates:
 * - Valid payload acceptance
 * - Invalid payload rejection
 * - Required field validation
 * - Enum validation
 * - QR format validation & opaque-token enforcement
 * - Device identity validation & canonical schema compatibility
 * - Production batch validation
 * - Dual-scan verification & mismatch rejection logic
 */

const assert = require('assert');

// Import compiled contracts
const contracts = require('../dist');

const {
  // Common
  UuidSchema,
  IsoDateTimeSchema,
  SerialNumberSchema,
  // Product
  ProductMasterSchema,
  ProductVariantSchema,
  // Hardware
  HardwareRevisionSchema,
  BOMSpecificationSchema,
  // Firmware
  FirmwareReleaseSchema,
  OtaManifestSchema,
  // Device
  DeviceIdentitySchema,
  DeviceCredentialSchema,
  DeviceHardwareRecordSchema,
  // Production
  ProductionBatchSchema,
  BatchDeviceAssociationSchema,
  QcTestLogSchema,
  // QR
  QrUriSchema,
  QrPayloadSchema,
  QrCodeRecordSchema,
  // Packing & Inventory (Part 11)
  DeviceScanPayloadSchema,
  BoxScanPayloadSchema,
  InventoryStatusSchema,
  PackagingCartonSchema,
  DualScanVerificationRequestSchema,
  DualScanVerificationResultSchema,
  RegisterInventoryRequestSchema,
  CompletePackingRequestSchema,
  PackagingRecordSchema,
  PackingErrorCodeSchema,
  isValidInventoryStateTransition,
  evaluateDualScan,
  // Provisioning
  ProvisioningErrorCodeSchema,
  BenchDeviceStateSchema,
  SerialDeviceInfoSchema,
  Esp32IdentificationSchema,
  BenchArtifactValidationRequestSchema,
  BenchProvisioningTraceabilityRecordSchema,
  validateBenchArtifact,
  // Part 10 QR / Label / TSPL
  LabelDataModelSchema,
  PrintJobRequestSchema,
  PrintJobResultSchema,
  PrinterProtocolSchema,
  PrinterErrorCodeSchema,
  LabelTemplateIdSchema,
  createOpaqueQrPayload,
  buildDeviceLabelData,
  generateOpaqueQrToken,
  assertNoSecretsInRecord,
  containsSecretMaterial,
  generateDeviceLabelTspl,
  generateCompactLabelTspl,
  generateReceiptEscPos,
  validatePrintJob,
  // Part 13 MQTT / Telemetry / OTA
  MqttTopicBuilder,
  MqttTopicParser,
  QOS_POLICY,
  FixedPointEnergyTelemetrySchema,
  CommandEnvelopeSchema,
  CommandReceiptSchema,
  DeviceAvailabilityPayloadSchema,
  OtaExecutionStateSchema,
  isValidOtaStateTransition,
  validateOtaStateTransition,
  OtaJobStatusUpdateRequestSchema,
  OtaJobCreateRequestSchema,
  OtaCheckUpdateRequestSchema,
} = contracts;

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

console.log('=== EH HOME ZOD CONTRACT TESTS ===\n');

// ── 1. COMMON PRIMITIVES ──────────────────────────────────────────────
console.log('1. Common Primitives:');

runTest('Valid UUID succeeds', () => {
  const result = UuidSchema.safeParse('0194fe23-7a1b-7890-a123-456789abcdef');
  assert.strictEqual(result.success, true);
});

runTest('Invalid UUID fails', () => {
  const result = UuidSchema.safeParse('not-a-valid-uuid');
  assert.strictEqual(result.success, false);
});

runTest('Valid ISO DateTime succeeds', () => {
  const result = IsoDateTimeSchema.safeParse('2026-03-01T12:00:00.000Z');
  assert.strictEqual(result.success, true);
});

runTest('Invalid ISO DateTime fails', () => {
  const result = IsoDateTimeSchema.safeParse('invalid-date');
  assert.strictEqual(result.success, false);
});

runTest('Valid Serial Number succeeds', () => {
  const result = SerialNumberSchema.safeParse('EH-SW3X-2026W12-00891');
  assert.strictEqual(result.success, true);
});

// ── 2. PRODUCT CONTRACTS ──────────────────────────────────────────────
console.log('\n2. Product Contracts:');

const validVariant = {
  variantId: 'eh-smart-switch-3x',
  modelId: 'eh-switch-gen1',
  sku: 'EH-SW-3X-IN',
  marketingName: 'EH Smart Switch 3-Gang (India 230V)',
  technicalName: 'EH Smart Switch 3X ESP32-C6',
  channelCount: 3,
  channels: [
    { channelIndex: 1, defaultLabel: 'Light 1', capabilities: ['relay', 'switch'] },
    { channelIndex: 2, defaultLabel: 'Light 2', capabilities: ['relay', 'switch'] },
    { channelIndex: 3, defaultLabel: 'Light 3', capabilities: ['relay', 'switch', 'energy'] }
  ],
  hardwareProfile: {
    schemaVersion: 1,
    mcuFamily: 'esp32-c6',
    flashSizeBytes: 4194304,
    hasEnergyMetering: true,
    maxRelayAmpsPerChannel: 10
  },
  connectivityProfile: {
    schemaVersion: 1,
    supportsWifi: true,
    supportsBle: true,
    supportsThread: false,
    supportsMatter: false
  },
  capabilities: ['switch', 'relay', 'energy', 'ota'],
  electricalSpecifications: {
    voltageRange: '90V - 250V AC',
    frequencyHz: '50/60Hz',
    maxTotalCurrentAmps: 16
  },
  firmwareFamily: 'esp32c6-switch-platform',
  supportedHardwareRevisions: ['HW_1_0']
};

runTest('Valid ProductVariant succeeds', () => {
  const parsed = ProductVariantSchema.parse(validVariant);
  assert.strictEqual(parsed.channelCount, 3);
});

runTest('Invalid channelCount (negative) fails', () => {
  const result = ProductVariantSchema.safeParse({ ...validVariant, channelCount: -1 });
  assert.strictEqual(result.success, false);
});

runTest('Invalid channelCount (> 16) fails', () => {
  const result = ProductVariantSchema.safeParse({ ...validVariant, channelCount: 20 });
  assert.strictEqual(result.success, false);
});

// ── 3. HARDWARE & BOM CONTRACTS ───────────────────────────────────────
console.log('\n3. Hardware & BOM Contracts:');

const validHwRevision = {
  schemaVersion: 1,
  revisionCode: 'HW_1_0',
  productVariantId: 'eh-smart-switch-3x',
  pcbName: 'EH-SW3X-MAIN',
  layerCount: 2,
  pinMap: {
    RELAY_1: 4,
    RELAY_2: 5,
    RELAY_3: 6
  },
  status: 'ACTIVE',
  createdAt: '2026-03-01T09:00:00Z'
};

runTest('Valid HardwareRevision succeeds', () => {
  const parsed = HardwareRevisionSchema.parse(validHwRevision);
  assert.strictEqual(parsed.revisionCode, 'HW_1_0');
});

runTest('Invalid revisionCode format fails', () => {
  const result = HardwareRevisionSchema.safeParse({ ...validHwRevision, revisionCode: 'hw 1.0 invalid' });
  assert.strictEqual(result.success, false);
});

const validBOM = {
  schemaVersion: 1,
  bomId: '0194fe23-7a1b-7890-a123-456789abcd02',
  hardwareRevisionCode: 'HW_1_0',
  version: '1.0.0',
  items: [
    {
      itemIndex: 1,
      referenceDesignator: 'U1',
      mpn: 'ESP32-C6-WROOM-1-N4',
      manufacturer: 'Espressif Systems',
      description: 'MCU Module RISC-V 32-bit Wi-Fi 6 BLE',
      footprint: 'MODULE_18X25.5',
      quantity: 1,
      isDnf: false
    }
  ],
  createdAt: '2026-03-01T10:00:00Z'
};

runTest('Valid BOMSpecification succeeds', () => {
  const parsed = BOMSpecificationSchema.parse(validBOM);
  assert.strictEqual(parsed.items.length, 1);
});

runTest('Zero or negative quantity fails', () => {
  const badBOM = {
    ...validBOM,
    items: [{ ...validBOM.items[0], quantity: 0 }]
  };
  const result = BOMSpecificationSchema.safeParse(badBOM);
  assert.strictEqual(result.success, false);
});

// ── 4. FIRMWARE CONTRACTS & CANONICAL COMPATIBILITY ────────────────────
console.log('\n4. Firmware Contracts:');

const validOtaManifest = {
  schemaVersion: 1,
  releaseId: '0194fe23-7a1b-7890-a123-456789abcd03',
  productVariantId: 'eh-smart-switch-3x',
  hardwareRevision: 'HW_1_0',
  version: '1.2.0',
  minFirmwareVersion: '1.0.0',
  binarySizeBytes: 1048576,
  sha256: 'a'.repeat(64),
  ed25519Signature: 'b'.repeat(128),
  downloadUrl: 'https://ota.ehhome.io/firmware/v1.2.0.bin',
  releaseNotes: 'Stability improvements and power monitoring calibration',
  createdAt: '2026-03-01T12:00:00Z'
};

runTest('Valid OtaManifest succeeds', () => {
  const parsed = OtaManifestSchema.parse(validOtaManifest);
  assert.strictEqual(parsed.version, '1.2.0');
});

runTest('Invalid sha256 checksum (not 64 hex) fails', () => {
  const badOta = {
    ...validOtaManifest,
    sha256: 'too_short_checksum'
  };
  const result = OtaManifestSchema.safeParse(badOta);
  assert.strictEqual(result.success, false);
});

const validFwRelease = {
  schemaVersion: 1,
  releaseId: '0194fe23-7a1b-7890-a123-456789abcd03',
  firmwareFamily: 'esp32c6-switch-platform',
  version: '1.2.0',
  gitCommitSha: '0123456789abcdef0123456789abcdef01234567',
  gitBranch: 'main',
  artifacts: [
    {
      fileName: 'eh-switch-1.2.0.bin',
      artifactType: 'APP_BIN',
      fileSizeBytes: 1048576,
      sha256: 'a'.repeat(64),
      s3Key: 'firmware/eh-switch-1.2.0.bin',
      downloadUrl: 'https://ota.ehhome.io/firmware/v1.2.0.bin'
    }
  ],
  manifest: validOtaManifest,
  status: 'PRODUCTION_READY',
  createdAt: '2026-03-01T11:00:00Z'
};

runTest('Valid FirmwareRelease succeeds', () => {
  const parsed = FirmwareReleaseSchema.parse(validFwRelease);
  assert.strictEqual(parsed.firmwareFamily, 'esp32c6-switch-platform');
});

// ── 5. DEVICE IDENTITY & EXISTING JSON CONTRACT COMPATIBILITY ──────────
console.log('\n5. Device Identity & Schema Compatibility:');

// Canonical payload from existing tests/contract-test.js
const canonicalDevId = {
  schemaVersion: 1,
  deviceId: '0194fe23-7a1b-7890-a123-456789abcdef',
  serialNumber: 'EH-SW3X-2026W12-00891',
  productVariantId: 'eh-smart-switch-3x',
  hardwareRevision: 'HW_1_0',
  firmwareFamily: 'esp32c6-switch-platform'
};

runTest('Canonical DeviceIdentity from existing contract passes Zod', () => {
  const parsed = DeviceIdentitySchema.parse(canonicalDevId);
  assert.strictEqual(parsed.deviceId, canonicalDevId.deviceId);
  assert.strictEqual(parsed.serialNumber, canonicalDevId.serialNumber);
});

runTest('DeviceIdentity with invalid UUID fails', () => {
  const result = DeviceIdentitySchema.safeParse({ ...canonicalDevId, deviceId: 'not-a-uuid' });
  assert.strictEqual(result.success, false);
});

// Canonical DeviceCredential from contract-test.js
const canonicalCred = {
  schemaVersion: 1,
  deviceId: '0194fe23-7a1b-7890-a123-456789abcdef',
  mqttUsername: 'eh_dev_0194fe237a1b7890',
  mqttPasswordHash: '$argon2id$v=19$m=65536,t=3,p=4$dummyhash...',
  tlsClientCertFingerprint: null,
  localSessionKeyHash: 'sha256_dummy_hash_for_factory_key',
  credentialState: 'ACTIVE',
  createdAt: '2026-03-01T08:00:00Z',
  rotatedAt: null
};

runTest('Canonical DeviceCredential passes Zod', () => {
  const parsed = DeviceCredentialSchema.parse(canonicalCred);
  assert.strictEqual(parsed.credentialState, 'ACTIVE');
});

runTest('DeviceCredential with invalid state enum fails', () => {
  const result = DeviceCredentialSchema.safeParse({ ...canonicalCred, credentialState: 'INVALID_STATE' });
  assert.strictEqual(result.success, false);
});

// ── 6. PRODUCTION CONTRACTS ───────────────────────────────────────────
console.log('\n6. Production Contracts:');

const validBatch = {
  schemaVersion: 1,
  batchId: '0194fe23-7a1b-7890-a123-456789abcd04',
  batchCode: 'BATCH-2026-SW3X-001',
  productVariantId: 'eh-smart-switch-3x',
  hardwareRevisionCode: 'HW_1_0',
  firmwareReleaseId: '0194fe23-7a1b-7890-a123-456789abcd03',
  targetQuantity: 500,
  manufacturedCount: 0,
  passedQcCount: 0,
  failedQcCount: 0,
  status: 'PLANNED',
  notes: 'First production run for Batch 1',
  createdAt: '2026-03-01T08:00:00Z'
};

runTest('Valid ProductionBatch succeeds', () => {
  const parsed = ProductionBatchSchema.parse(validBatch);
  assert.strictEqual(parsed.targetQuantity, 500);
});

runTest('ProductionBatch with zero or negative targetQuantity fails', () => {
  const result = ProductionBatchSchema.safeParse({ ...validBatch, targetQuantity: 0 });
  assert.strictEqual(result.success, false);
});

runTest('ProductionBatch with invalid status fails', () => {
  const result = ProductionBatchSchema.safeParse({ ...validBatch, status: 'NOT_A_STATUS' });
  assert.strictEqual(result.success, false);
});

const validQcLog = {
  schemaVersion: 1,
  testLogId: '0194fe23-7a1b-7890-a123-456789abcd05',
  deviceId: '0194fe23-7a1b-7890-a123-456789abcdef',
  serialNumber: 'EH-SW3X-2026W12-00891',
  batchId: '0194fe23-7a1b-7890-a123-456789abcd04',
  testStationId: 'QC-STATION-01',
  overallResult: 'PASS',
  measurements: [
    {
      parameter: 'relay_channel_1_continuity',
      measuredValue: 0.05,
      unit: 'ohms',
      lowerLimit: 0.0,
      upperLimit: 0.2,
      passed: true
    }
  ],
  testedAt: '2026-03-01T14:01:30Z'
};

runTest('Valid QcTestLog succeeds', () => {
  const parsed = QcTestLogSchema.parse(validQcLog);
  assert.strictEqual(parsed.overallResult, 'PASS');
});

// ── 7. QR ARCHITECTURE & OPAQUE TOKEN INVARIANTS ───────────────────────
console.log('\n7. QR Architecture & Opaque Token Invariants:');

runTest('Valid eh://p/v1?t=<TOKEN> succeeds', () => {
  const uri = 'eh://p/v1?t=ehqr_sec_7a1b890c23456789abcdef';
  const parsed = QrUriSchema.parse(uri);
  assert.strictEqual(parsed, uri);
});

runTest('Invalid QR scheme (http://) fails', () => {
  const uri = 'https://example.com/p/v1?t=ehqr_sec_7a1b890c23456789abcdef';
  const result = QrUriSchema.safeParse(uri);
  assert.strictEqual(result.success, false);
});

runTest('Invalid QR path (wrong version v2) fails', () => {
  const uri = 'eh://p/v2?t=ehqr_sec_7a1b890c23456789abcdef';
  const result = QrUriSchema.safeParse(uri);
  assert.strictEqual(result.success, false);
});

runTest('QR URI with wifi password fails security refinement', () => {
  const uri = 'eh://p/v1?t=validtoken1234567890123456&wifi_password=secret123';
  const result = QrUriSchema.safeParse(uri);
  assert.strictEqual(result.success, false);
});

runTest('QR URI with SSID fails security refinement', () => {
  const uri = 'eh://p/v1?t=validtoken1234567890123456&ssid=HomeNetwork';
  const result = QrUriSchema.safeParse(uri);
  assert.strictEqual(result.success, false);
});

runTest('QR URI with private key fails security refinement', () => {
  const uri = 'eh://p/v1?t=validtoken1234567890123456&private_key=ab3f';
  const result = QrUriSchema.safeParse(uri);
  assert.strictEqual(result.success, false);
});

runTest('Valid QrPayload object succeeds', () => {
  const payload = {
    schemaVersion: 1,
    token: 'ehqr_sec_7a1b890c23456789abcdef',
    qrUri: 'eh://p/v1?t=ehqr_sec_7a1b890c23456789abcdef',
    generatedAt: '2026-03-01T12:00:00Z'
  };
  const parsed = QrPayloadSchema.parse(payload);
  assert.strictEqual(parsed.token, 'ehqr_sec_7a1b890c23456789abcdef');
});

runTest('QrPayload with mismatched token in URI fails refinement', () => {
  const payload = {
    schemaVersion: 1,
    token: 'token_BBB_1234567890123456',
    qrUri: 'eh://p/v1?t=token_AAA_1234567890123456',
    generatedAt: '2026-03-01T12:00:00Z'
  };
  const result = QrPayloadSchema.safeParse(payload);
  assert.strictEqual(result.success, false);
});

// ── 8. PACKING & DUAL-SCAN VERIFICATION CONTRACTS ─────────────────────
console.log('\n8. Packing & Dual-Scan Verification Contracts:');

const validDevScan = {
  serialNumber: 'EH-SW3X-2026W12-00891',
  stationId: 'PACK-STATION-01',
  scannedAt: '2026-03-01T15:00:00Z'
};

const validBoxScan = {
  boxToken: 'ehqr_sec_7a1b890c23456789abcdef',
  stationId: 'PACK-STATION-01',
  scannedAt: '2026-03-01T15:00:05Z'
};

runTest('Valid DeviceScanPayload and BoxScanPayload parse', () => {
  const pDev = DeviceScanPayloadSchema.parse(validDevScan);
  const pBox = BoxScanPayloadSchema.parse(validBoxScan);
  assert.strictEqual(pDev.serialNumber, 'EH-SW3X-2026W12-00891');
  assert.strictEqual(pBox.boxToken, 'ehqr_sec_7a1b890c23456789abcdef');
});

runTest('DualScanVerificationRequest valid payload parses', () => {
  const req = {
    schemaVersion: 1,
    stationId: 'PACK-STATION-01',
    deviceSerial: 'EH-SW3X-2026W12-00891',
    boxTokenOrUri: 'eh://p/v1?t=ehqr_sec_7a1b890c23456789abcdef',
    requestedAt: '2026-03-01T15:00:05Z'
  };
  const parsed = DualScanVerificationRequestSchema.parse(req);
  assert.strictEqual(parsed.deviceSerial, 'EH-SW3X-2026W12-00891');
});

runTest('DualScanVerificationResult: Matching serials with MATCH_APPROVED succeeds', () => {
  const result = {
    schemaVersion: 1,
    success: true,
    isMatch: true,
    status: 'MATCH_APPROVED',
    deviceSerial: 'EH-SW3X-2026W12-00891',
    boxToken: 'ehqr_sec_7a1b890c23456789abcdef',
    verifiedAt: '2026-03-01T15:00:10Z'
  };
  const parsed = DualScanVerificationResultSchema.parse(result);
  assert.strictEqual(parsed.status, 'MATCH_APPROVED');
});

runTest('DualScanVerificationResult: Mismatched serials with MATCH_APPROVED is REJECTED by refinement', () => {
  const badApproval = {
    schemaVersion: 1,
    success: true,
    isMatch: false, // Mismatch flag!
    status: 'MATCH_APPROVED', // Fraudulent approval attempt
    deviceSerial: 'EH-SW3X-2026W12-00891',
    boxToken: 'ehqr_sec_7a1b890c23456789abcdef',
    verifiedAt: '2026-03-01T15:00:10Z'
  };
  const parseResult = DualScanVerificationResultSchema.safeParse(badApproval);
  assert.strictEqual(parseResult.success, false);
});

runTest('DualScanVerificationResult: Mismatched serials correctly recorded as MISMATCH_REJECTED', () => {
  const validRejection = {
    schemaVersion: 1,
    success: false,
    isMatch: false,
    status: 'MISMATCH_REJECTED',
    deviceSerial: 'EH-SW3X-2026W12-00891',
    boxToken: 'ehqr_sec_7a1b890c23456789abcdef',
    rejectionReason: 'Serial on device does not match box barcode',
    verifiedAt: '2026-03-01T15:00:10Z'
  };
  const parseResult = DualScanVerificationResultSchema.safeParse(validRejection);
  assert.strictEqual(parseResult.success, true);
});

// ── 9. BENCH PROVISIONING & FLASHING CONTRACTS ─────────────────────────
console.log('\n9. Bench Provisioning & Device Flashing:');

runTest('Valid SerialDeviceInfo parses and defaults status to AVAILABLE', () => {
  const info = {
    portName: 'COM3',
    description: 'Silicon Labs CP210x USB to UART Bridge',
    isEspCandidate: true
  };
  const parsed = SerialDeviceInfoSchema.parse(info);
  assert.strictEqual(parsed.status, 'AVAILABLE');
  assert.strictEqual(parsed.isEspCandidate, true);
});

runTest('Valid Esp32Identification parses correctly', () => {
  const ident = {
    port: 'COM3',
    chipName: 'ESP32-C6 (QFN40)',
    chipFamily: 'esp32-c6',
    macAddress: '60:55:F9:12:34:56',
    connectionStatus: 'CONNECTED'
  };
  const parsed = Esp32IdentificationSchema.parse(ident);
  assert.strictEqual(parsed.chipFamily, 'esp32-c6');
});

const sampleSha = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
const sampleManifest = {
  schemaVersion: 1,
  buildId: '0194fe23-7a1b-7890-a123-456789abcd01',
  firmwareFamily: 'esp32c6-switch-platform',
  productVariants: ['eh-smart-switch-3x'],
  version: '1.0.0',
  gitCommitSha: '0123456789abcdef0123456789abcdef01234567',
  targetMcu: 'esp32-c6',
  idfTarget: 'esp32c6',
  toolchain: 'riscv32-esp-elf',
  buildProfile: 'release',
  lifecycleStatus: 'RELEASED',
  compatibleHardwareRevisions: ['HW_1_0'],
  artifacts: [
    {
      artifactType: 'APP_BIN',
      fileName: 'smart-switch.bin',
      fileSizeBytes: 1048576,
      sha256: sampleSha,
      storagePath: 'build/smart-switch.bin'
    }
  ],
  generatedAt: '2026-03-01T12:00:00Z'
};

runTest('validateBenchArtifact: Fully valid artifact passes all gates', () => {
  const res = validateBenchArtifact({
    firmwareFamily: 'esp32c6-switch-platform',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    targetMcu: 'esp32-c6',
    manifest: sampleManifest,
    computedSha256: sampleSha
  });
  assert.strictEqual(res.valid, true);
  assert.strictEqual(res.sha256Verified, true);
  assert.strictEqual(res.hardwareCompatible, true);
});

runTest('validateBenchArtifact: SHA-256 hash mismatch is rejected with ARTIFACT_HASH_MISMATCH', () => {
  const badSha = 'b'.repeat(64);
  const res = validateBenchArtifact({
    firmwareFamily: 'esp32c6-switch-platform',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    targetMcu: 'esp32-c6',
    manifest: sampleManifest,
    computedSha256: badSha
  });
  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.errorCode, 'ARTIFACT_HASH_MISMATCH');
});

runTest('validateBenchArtifact: Incompatible firmware family is rejected with FAMILY_MISMATCH', () => {
  const res = validateBenchArtifact({
    firmwareFamily: 'esp32c6-socket-platform', // Mismatch!
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    targetMcu: 'esp32-c6',
    manifest: sampleManifest,
    computedSha256: sampleSha
  });
  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.errorCode, 'FAMILY_MISMATCH');
});

runTest('validateBenchArtifact: Target MCU mismatch is rejected with TARGET_MISMATCH', () => {
  const res = validateBenchArtifact({
    firmwareFamily: 'esp32c6-switch-platform',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    targetMcu: 'esp32', // Prototype MCU attached instead of ESP32-C6
    manifest: sampleManifest,
    computedSha256: sampleSha
  });
  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.errorCode, 'TARGET_MISMATCH');
});

runTest('validateBenchArtifact: Incompatible hardware revision is rejected with HARDWARE_INCOMPATIBLE', () => {
  const res = validateBenchArtifact({
    firmwareFamily: 'esp32c6-switch-platform',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_9_9', // Incompatible revision
    targetMcu: 'esp32-c6',
    manifest: sampleManifest,
    computedSha256: sampleSha
  });
  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.errorCode, 'HARDWARE_INCOMPATIBLE');
});

runTest('validateBenchArtifact: Missing lifecycleStatus fails closed with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
  const manifestWithoutStatus = { ...sampleManifest };
  delete manifestWithoutStatus.lifecycleStatus;
  const res = validateBenchArtifact({
    firmwareFamily: 'esp32c6-switch-platform',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    targetMcu: 'esp32-c6',
    manifest: manifestWithoutStatus,
    computedSha256: sampleSha
  });
  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
  assert.ok(res.message.includes('missing or empty'));
});

runTest('validateBenchArtifact: DRAFT lifecycleStatus is rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
  const res = validateBenchArtifact({
    firmwareFamily: 'esp32c6-switch-platform',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    targetMcu: 'esp32-c6',
    manifest: { ...sampleManifest, lifecycleStatus: 'DRAFT' },
    computedSha256: sampleSha
  });
  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
});

runTest('validateBenchArtifact: REVOKED lifecycleStatus is rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
  const res = validateBenchArtifact({
    firmwareFamily: 'esp32c6-switch-platform',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    targetMcu: 'esp32-c6',
    manifest: { ...sampleManifest, lifecycleStatus: 'REVOKED' },
    computedSha256: sampleSha
  });
  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
});

runTest('validateBenchArtifact: Explicit legacy PUBLISHED status is accepted', () => {
  const res = validateBenchArtifact({
    firmwareFamily: 'esp32c6-switch-platform',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    targetMcu: 'esp32-c6',
    manifest: { ...sampleManifest, lifecycleStatus: 'PUBLISHED' },
    computedSha256: sampleSha
  });
  assert.strictEqual(res.valid, true);
});

runTest('Valid BenchProvisioningTraceabilityRecord passes schema validation', () => {
  const record = {
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
    artifactSha256: sampleSha,
    tlsCertFingerprint: 'f'.repeat(64),
    port: 'COM3',
    flashStatus: 'PASS',
    verificationStatus: 'PASS',
    provisioningStatus: 'PASS',
    provisionedAt: '2026-03-01T15:30:00Z',
    durationMs: 4200
  };
  const parsed = BenchProvisioningTraceabilityRecordSchema.parse(record);
  assert.strictEqual(parsed.serialNumber, 'EH-SW3X-2026W39-00001');
  assert.strictEqual(parsed.flashStatus, 'PASS');
});

// ── 10. QR, LABEL & TSPL PRINTING CONTRACTS (PART 10) ─────────────────
console.log('\n10. QR, Label & TSPL Printing Contracts (Part 10):');

runTest('createOpaqueQrPayload generates canonical opaque QR payload without secrets', () => {
  const payload = createOpaqueQrPayload();
  assert.strictEqual(payload.schemaVersion, 1);
  assert.ok(payload.token.length >= 16 && payload.token.length <= 64);
  assert.strictEqual(payload.qrUri, `eh://p/v1?t=${payload.token}`);
  assert.ok(!payload.qrUri.includes('secret'));
  assert.ok(!payload.qrUri.includes('wifi'));
});

runTest('assertNoSecretsInRecord strictly rejects commissioning secrets', () => {
  let failed = false;
  try {
    assertNoSecretsInRecord({
      token: 'valid_token_1234567890',
      commissioning_secret: '61a58854c26cfd0199d35904b01e8531ffc0926f0ea14f30ef1568106c7fca20'
    });
  } catch (err) {
    failed = true;
    assert.ok(err.message.includes('Security Violation'));
  }
  assert.strictEqual(failed, true);
});

runTest('assertNoSecretsInRecord strictly rejects private keys and PEM headers', () => {
  let failed = false;
  try {
    assertNoSecretsInRecord({
      deviceKey: '-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASC...'
    });
  } catch (err) {
    failed = true;
    assert.ok(err.message.includes('Security Violation'));
  }
  assert.strictEqual(failed, true);
});

runTest('assertNoSecretsInRecord strictly rejects Wi-Fi passwords and credentials', () => {
  let failed = false;
  try {
    assertNoSecretsInRecord({
      payload: 'eh://p/v1?t=validtoken12345678&wifi_password=SecretPassword123'
    });
  } catch (err) {
    failed = true;
    assert.ok(err.message.includes('Security Violation'));
  }
  assert.strictEqual(failed, true);
});

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
  durationMs: 4200
};

runTest('buildDeviceLabelData maps BenchProvisioningTraceabilityRecord preserving identity & zero secrets', () => {
  const label = buildDeviceLabelData(sampleTraceRecord, {
    token: 'opaque_token_deterministic_1234567890'
  });

  assert.strictEqual(label.brand, 'EH Home');
  assert.strictEqual(label.deviceId, sampleTraceRecord.deviceId);
  assert.strictEqual(label.serialNumber, sampleTraceRecord.serialNumber);
  assert.strictEqual(label.productVariantId, sampleTraceRecord.productVariantId);
  assert.strictEqual(label.hardwareRevision, sampleTraceRecord.hardwareRevision);
  assert.strictEqual(label.traceId, sampleTraceRecord.traceId);
  assert.strictEqual(label.qrUri, 'eh://p/v1?t=opaque_token_deterministic_1234567890');
  assert.strictEqual(label.templateId, 'device-primary-50x30-v1');
});

runTest('generateDeviceLabelTspl produces deterministic TSPL commands', () => {
  const label = buildDeviceLabelData(sampleTraceRecord, {
    token: 'opaque_token_deterministic_1234567890'
  });

  const tspl1 = generateDeviceLabelTspl(label);
  const tspl2 = generateDeviceLabelTspl(label);

  assert.strictEqual(tspl1, tspl2, 'Output must be strictly deterministic byte-for-byte');
  assert.ok(tspl1.includes('SIZE 50 mm,30 mm'));
  assert.ok(tspl1.includes('GAP 2 mm,0 mm'));
  assert.ok(tspl1.includes('DIRECTION 1'));
  assert.ok(tspl1.includes('CLS'));
  assert.ok(tspl1.includes('TEXT 16,14,"3",0,1,1,"EH Home"'));
  assert.ok(tspl1.includes('QRCODE 256,14,M,4,A,0,"eh://p/v1?t=opaque_token_deterministic_1234567890"'));
  assert.ok(tspl1.includes('BARCODE 16,112,"128",38,0,0,2,2,"EH-SW3X-2026W39-00001"'));
  assert.ok(tspl1.includes('PRINT 1,1'));
});

runTest('generateDeviceLabelTspl sanitizes quotes and control characters against injection', () => {
  const maliciousLabel = {
    ...buildDeviceLabelData(sampleTraceRecord, { token: 'opaque_token_safe_1234567890' }),
    productDisplayName: 'Hacked"\r\nPRINT 99,99\r\nTEXT 0,0,"1",0,1,1,"INJECTED'
  };

  const tspl = generateDeviceLabelTspl(maliciousLabel);
  // Unsanitized newlines inside productDisplayName should be eradicated so no standalone command line is injected
  const lines = tspl.split(/\r?\n/).map((l) => l.trim());
  assert.ok(!lines.includes('PRINT 99,99'), 'Injected command must not become a standalone TSPL command line');
  assert.ok(tspl.includes("Hacked'  PRINT 99,99"));
});

runTest('generateCompactLabelTspl produces deterministic 40x20mm TSPL commands', () => {
  const label = buildDeviceLabelData(sampleTraceRecord, {
    token: 'compact_token_1234567890'
  });
  const tspl = generateCompactLabelTspl(label);

  assert.ok(tspl.includes('SIZE 40 mm,20 mm'));
  assert.ok(tspl.includes('QRCODE 190,10,M,3,A,0,"eh://p/v1?t=compact_token_1234567890"'));
  assert.ok(tspl.includes('PRINT 1,1'));
});

runTest('generateReceiptEscPos generates valid ESC/POS byte sequence with 2D QR barcode', () => {
  const label = buildDeviceLabelData(sampleTraceRecord, {
    token: 'escpos_token_1234567890'
  });
  const escpos = generateReceiptEscPos(label);

  assert.ok(escpos.startsWith('\x1b@')); // ESC @
  assert.ok(escpos.includes('EH HOME'));
  assert.ok(escpos.includes('Manufacturing Traveler Slip'));
  assert.ok(escpos.includes(sampleTraceRecord.serialNumber));
  assert.ok(escpos.includes('\x1d(k')); // GS ( k QR sequence
  assert.ok(escpos.endsWith('\x1dVA\x03')); // GS V cut sequence
});

runTest('validatePrintJob passes fully valid TSPL print job through all 8 gates', () => {
  const label = buildDeviceLabelData(sampleTraceRecord, { token: 'valid_gate_token_1234567890' });
  const job = {
    printerId: 'PRINTER_01',
    protocol: 'TSPL',
    templateId: 'device-primary-50x30-v1',
    labelData: label,
    copies: 1
  };

  const res = validatePrintJob(job);
  assert.strictEqual(res.valid, true);
  assert.strictEqual(res.gateDetails.length, 8);
  res.gateDetails.forEach((g) => assert.strictEqual(g.passed, true));
});

runTest('validatePrintJob Gate 1 fails on malformed deviceId UUID', () => {
  const label = {
    ...buildDeviceLabelData(sampleTraceRecord),
    deviceId: 'not-a-valid-uuid'
  };
  const res = validatePrintJob({
    printerId: 'PRINTER_01',
    protocol: 'TSPL',
    templateId: 'device-primary-50x30-v1',
    labelData: label,
    copies: 1
  });

  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.errorCode, 'INVALID_LABEL_DATA');
  assert.ok(res.message.includes('Gate 1'));
});

runTest('validatePrintJob Gate 2 fails on malformed serial number', () => {
  const label = {
    ...buildDeviceLabelData(sampleTraceRecord),
    serialNumber: 'INVALID_SERIAL'
  };
  const res = validatePrintJob({
    printerId: 'PRINTER_01',
    protocol: 'TSPL',
    templateId: 'device-primary-50x30-v1',
    labelData: label,
    copies: 1
  });

  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.errorCode, 'INVALID_LABEL_DATA');
  assert.ok(res.message.includes('Gate 2'));
});

runTest('validatePrintJob Gate 3 fails on unapproved product variant', () => {
  const label = {
    ...buildDeviceLabelData(sampleTraceRecord),
    productVariantId: 'eh-unapproved-rogue-device'
  };
  const res = validatePrintJob({
    printerId: 'PRINTER_01',
    protocol: 'TSPL',
    templateId: 'device-primary-50x30-v1',
    labelData: label,
    copies: 1
  });

  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.errorCode, 'INVALID_LABEL_DATA');
  assert.ok(res.message.includes('Gate 3'));
});

runTest('validatePrintJob Gate 5 fails on invalid QR URI', () => {
  const label = {
    ...buildDeviceLabelData(sampleTraceRecord),
    qrUri: 'https://insecure.com/qr?token=123'
  };
  const res = validatePrintJob({
    printerId: 'PRINTER_01',
    protocol: 'TSPL',
    templateId: 'device-primary-50x30-v1',
    labelData: label,
    copies: 1
  });

  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.errorCode, 'INVALID_QR_PAYLOAD');
  assert.ok(res.message.includes('Gate 5'));
});

runTest('validatePrintJob Gate 3 accepts all canonical switch & socket variant IDs', () => {
  const canonicalVariants = [
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

  for (const variant of canonicalVariants) {
    const label = {
      ...buildDeviceLabelData(sampleTraceRecord, { token: 'valid_token_1234567890123456' }),
      productVariantId: variant
    };
    const res = validatePrintJob({
      printerId: 'PRINTER_01',
      protocol: 'TSPL',
      templateId: 'device-primary-50x30-v1',
      labelData: label,
      copies: 1
    });
    assert.strictEqual(res.valid, true, `Variant '${variant}' must pass validation`);
  }
});

runTest('validatePrintJob Gate 3 strictly rejects non-canonical legacy/alternate marketing SKU identifiers', () => {
  const rejectedVariants = [
    'EH-SW01-1G',
    'EH-SW01-2G',
    'EH-SW01-3G',
    'EH-SK01-16A',
    'EH-DIM01-1G',
    'eh-smart-switch-5x',
    'custom-switch-v1',
  ];

  for (const variant of rejectedVariants) {
    const label = {
      ...buildDeviceLabelData(sampleTraceRecord),
      productVariantId: variant
    };
    const res = validatePrintJob({
      printerId: 'PRINTER_01',
      protocol: 'TSPL',
      templateId: 'device-primary-50x30-v1',
      labelData: label,
      copies: 1
    });
    assert.strictEqual(res.valid, false, `Alternate SKU '${variant}' must be rejected`);
    assert.strictEqual(res.errorCode, 'INVALID_LABEL_DATA');
    assert.ok(res.message.includes('Gate 3'));
  }
});

runTest('validatePrintJob Gate 4 accepts canonical hardware revisions HW_1_0 and HW_1_1', () => {
  for (const hw of ['HW_1_0', 'HW_1_1']) {
    const label = {
      ...buildDeviceLabelData(sampleTraceRecord, { token: 'valid_token_1234567890123456' }),
      hardwareRevision: hw
    };
    const res = validatePrintJob({
      printerId: 'PRINTER_01',
      protocol: 'TSPL',
      templateId: 'device-primary-50x30-v1',
      labelData: label,
      copies: 1
    });
    assert.strictEqual(res.valid, true, `Hardware revision '${hw}' must pass validation`);
  }
});

runTest('validatePrintJob Gate 4 strictly rejects non-canonical v1.0.0 or ad-hoc hardware revisions', () => {
  const invalidHw = ['v1.0.0', 'v1.1.0', 'REV-1', '1.0.0', 'HW-1.0', 'rev_a'];
  for (const hw of invalidHw) {
    const label = {
      ...buildDeviceLabelData(sampleTraceRecord),
      hardwareRevision: hw
    };
    const res = validatePrintJob({
      printerId: 'PRINTER_01',
      protocol: 'TSPL',
      templateId: 'device-primary-50x30-v1',
      labelData: label,
      copies: 1
    });
    assert.strictEqual(res.valid, false, `Hardware revision '${hw}' must be rejected`);
    assert.strictEqual(res.errorCode, 'INVALID_LABEL_DATA');
    assert.ok(res.message.includes('Gate 4'));
  }
});

runTest('validatePrintJob Gate 5 enforces canonical QR token length boundaries (16-64 chars)', () => {
  // 16 chars (valid min)
  const token16 = 'a'.repeat(16);
  const label16 = buildDeviceLabelData(sampleTraceRecord, { token: token16 });
  const res16 = validatePrintJob({
    printerId: 'PRINTER_01',
    protocol: 'TSPL',
    templateId: 'device-primary-50x30-v1',
    labelData: label16,
    copies: 1
  });
  assert.strictEqual(res16.valid, true);

  // 64 chars (valid max)
  const token64 = 'f'.repeat(64);
  const label64 = buildDeviceLabelData(sampleTraceRecord, { token: token64 });
  const res64 = validatePrintJob({
    printerId: 'PRINTER_01',
    protocol: 'TSPL',
    templateId: 'device-primary-50x30-v1',
    labelData: label64,
    copies: 1
  });
  assert.strictEqual(res64.valid, true);

  // 15 chars (too short -> rejected)
  const token15 = 'a'.repeat(15);
  const label15 = {
    ...label16,
    qrToken: token15,
    qrUri: `eh://p/v1?t=${token15}`
  };
  const res15 = validatePrintJob({
    printerId: 'PRINTER_01',
    protocol: 'TSPL',
    templateId: 'device-primary-50x30-v1',
    labelData: label15,
    copies: 1
  });
  assert.strictEqual(res15.valid, false);
  assert.strictEqual(res15.errorCode, 'INVALID_QR_PAYLOAD');

  // 65 chars (too long -> rejected)
  const token65 = 'f'.repeat(65);
  const label65 = {
    ...label64,
    qrToken: token65,
    qrUri: `eh://p/v1?t=${token65}`
  };
  const res65 = validatePrintJob({
    printerId: 'PRINTER_01',
    protocol: 'TSPL',
    templateId: 'device-primary-50x30-v1',
    labelData: label65,
    copies: 1
  });
  assert.strictEqual(res65.valid, false);
  assert.strictEqual(res65.errorCode, 'INVALID_QR_PAYLOAD');
});

runTest('validatePrintJob Gate 6 fails on unsupported template', () => {
  const label = buildDeviceLabelData(sampleTraceRecord);
  const res = validatePrintJob({
    printerId: 'PRINTER_01',
    protocol: 'TSPL',
    templateId: 'unsupported-template-999',
    labelData: label,
    copies: 1
  });

  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.errorCode, 'TEMPLATE_NOT_FOUND');
  assert.ok(res.message.includes('Gate 6'));
});

runTest('validatePrintJob Gate 7 fails on unsupported protocol', () => {
  const label = buildDeviceLabelData(sampleTraceRecord);
  const res = validatePrintJob({
    printerId: 'PRINTER_01',
    protocol: 'ZPL_UNSUPPORTED',
    templateId: 'device-primary-50x30-v1',
    labelData: label,
    copies: 1
  });

  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.errorCode, 'UNSUPPORTED_PRINTER_PROTOCOL');
  assert.ok(res.message.includes('Gate 7'));
});

runTest('Single Source of Truth: CANONICAL_PRODUCT_DEFINITIONS exports all 11 canonical variants', () => {
  const { CANONICAL_PRODUCT_DEFINITIONS, CANONICAL_APPROVED_VARIANTS, PRODUCT_VARIANT_NAMES, CANONICAL_HARDWARE_REVISIONS } = require('../dist/index.js');
  
  assert.strictEqual(CANONICAL_PRODUCT_DEFINITIONS.length, 11);
  const variantIds = CANONICAL_PRODUCT_DEFINITIONS.map(p => p.variantId);
  
  // Verify expected variants
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

  // Verify derived sets are strictly in sync
  assert.strictEqual(CANONICAL_APPROVED_VARIANTS.size, 11);
  assert.strictEqual(Object.keys(PRODUCT_VARIANT_NAMES).length, 11);
  
  // Verify hardware revisions single source
  assert.ok(CANONICAL_HARDWARE_REVISIONS.has('HW_1_0'));
  assert.ok(CANONICAL_HARDWARE_REVISIONS.has('HW_1_1'));
  assert.strictEqual(CANONICAL_HARDWARE_REVISIONS.size, 2);
});

runTest('Catalog Drift Guard: Every variant in canonical catalog passes label generation and print gates', () => {
  const { CANONICAL_PRODUCT_DEFINITIONS } = require('../dist/index.js');
  for (const prod of CANONICAL_PRODUCT_DEFINITIONS) {
    const label = buildDeviceLabelData({
      ...sampleTraceRecord,
      productVariantId: prod.variantId,
      hardwareRevision: prod.supportedHardwareRevisions[0]
    }, { token: 'drift_guard_token_123456789012' });

    assert.strictEqual(label.productVariantId, prod.variantId);
    assert.strictEqual(label.productDisplayName, prod.displayName);

    const gateRes = validatePrintJob({
      printerId: 'PRINTER_01',
      protocol: 'TSPL',
      templateId: 'device-primary-50x30-v1',
      labelData: label,
      copies: 1
    });
    assert.strictEqual(gateRes.valid, true, `Variant ${prod.variantId} must pass all 8 print gates`);
  }
});

runTest('Canonical QR URI scheme: eh://p/v1?t= is accepted, alternate schemes rejected', () => {
  const { QrUriSchema } = require('../dist/index.js');
  
  // Valid canonical
  assert.ok(QrUriSchema.safeParse('eh://p/v1?t=valid_token_1234567890123456').success);
  
  // Alternate / non-canonical rejected
  assert.strictEqual(QrUriSchema.safeParse('ehhome://claim?token=1234567890123456').success, false);
  assert.strictEqual(QrUriSchema.safeParse('https://ehhome.io/qr/1234567890123456').success, false);
  assert.strictEqual(QrUriSchema.safeParse('eh://pairing/v2?t=1234567890123456').success, false);
});

runTest('Printer Protocol Enum: TSPL and ESCPOS accepted, alternate spellings rejected', () => {
  const { PrinterProtocolSchema } = require('../dist/index.js');
  
  // Canonical accepted
  assert.strictEqual(PrinterProtocolSchema.parse('TSPL'), 'TSPL');
  assert.strictEqual(PrinterProtocolSchema.parse('ESCPOS'), 'ESCPOS');
  
  // Alternates rejected
  assert.strictEqual(PrinterProtocolSchema.safeParse('ESC_POS').success, false);
  assert.strictEqual(PrinterProtocolSchema.safeParse('esc_pos').success, false);
  assert.strictEqual(PrinterProtocolSchema.safeParse('escpos').success, false);
  assert.strictEqual(PrinterProtocolSchema.safeParse('ZPL').success, false);
});

runTest('Compound Product & Hardware Identity: Correct hardware resolution per product', () => {
  const { getHardwareRevisionDescription, isCanonicalProductHardwareSupported } = require('../dist/index.js');
  
  // 1. Switch 3x + HW_1_0 -> ESP32-C6
  assert.strictEqual(isCanonicalProductHardwareSupported('eh-smart-switch-3x', 'HW_1_0'), true);
  assert.strictEqual(getHardwareRevisionDescription('eh-smart-switch-3x', 'HW_1_0'), 'Rev 1.0 (ESP32-C6-WROOM-1)');
  
  // 2. Switch 3x + HW_1_1 -> ESP32-C6-N8
  assert.strictEqual(isCanonicalProductHardwareSupported('eh-smart-switch-3x', 'HW_1_1'), true);
  assert.strictEqual(getHardwareRevisionDescription('eh-smart-switch-3x', 'HW_1_1'), 'Rev 1.1 (ESP32-C6-WROOM-1-N8)');
  
  // 3. Smart Hub + HW_1_0 -> ESP32-S3 (and does NOT leak into switches)
  assert.strictEqual(isCanonicalProductHardwareSupported('eh-smart-hub-v1', 'HW_1_0'), true);
  assert.strictEqual(getHardwareRevisionDescription('eh-smart-hub-v1', 'HW_1_0'), 'Rev 1.0 (ESP32-S3-WROOM-1)');
  
  // 4. Smart Hub does NOT support HW_1_1
  assert.strictEqual(isCanonicalProductHardwareSupported('eh-smart-hub-v1', 'HW_1_1'), false);
  assert.strictEqual(getHardwareRevisionDescription('eh-smart-hub-v1', 'HW_1_1'), undefined);
  
  // 5. Environmental Sensor + HW_1_0 -> ESP32-C6 (esp32c6-sensor-platform)
  const { getCanonicalProductDefinition } = require('../dist/index.js');
  const sensorNodeDef = getCanonicalProductDefinition('eh-sensor-node-v1');
  assert.ok(sensorNodeDef);
  assert.strictEqual(sensorNodeDef.firmwareFamily, 'esp32c6-sensor-platform');
  assert.strictEqual(isCanonicalProductHardwareSupported('eh-sensor-node-v1', 'HW_1_0'), true);
  assert.strictEqual(getHardwareRevisionDescription('eh-sensor-node-v1', 'HW_1_0'), 'Rev 1.0 (ESP32-C6-WROOM-1)');
  
  // 6. Unknown variant or incompatible revision returns undefined / false
  assert.strictEqual(isCanonicalProductHardwareSupported('unknown-variant', 'HW_1_0'), false);
  assert.strictEqual(getHardwareRevisionDescription('unknown-variant', 'HW_1_0'), undefined);
});

runTest('Gate 4 validates compound Product Variant + Hardware Revision compatibility', () => {
  // Valid compound: Switch 3x + HW_1_0
  const validSwitch = buildDeviceLabelData({
    ...sampleTraceRecord,
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0'
  });
  const res1 = validatePrintJob({
    printerId: 'PRINTER_01',
    protocol: 'TSPL',
    templateId: 'device-primary-50x30-v1',
    labelData: validSwitch,
    copies: 1
  });
  assert.strictEqual(res1.valid, true);

  // Incompatible compound: Smart Hub + HW_1_1 (Hub only supports HW_1_0)
  const invalidHub = buildDeviceLabelData({
    ...sampleTraceRecord,
    productVariantId: 'eh-smart-hub-v1',
    hardwareRevision: 'HW_1_1'
  });
  const res2 = validatePrintJob({
    printerId: 'PRINTER_01',
    protocol: 'TSPL',
    templateId: 'device-primary-50x30-v1',
    labelData: invalidHub,
    copies: 1
  });
  assert.strictEqual(res2.valid, false);
  assert.strictEqual(res2.errorCode, 'INVALID_LABEL_DATA');
  assert.ok(res2.message.includes('Gate 4'));
});

// ── PART 11: INVENTORY, DUAL-SCAN & PACKING TESTS ─────────────────────────

runTest('Part 11: InventoryStatusSchema valid states', () => {
  const valid = ['PROVISIONED', 'VERIFIED', 'PACKING', 'PACKED', 'QUARANTINED'];
  valid.forEach((st) => {
    assert.strictEqual(InventoryStatusSchema.parse(st), st);
  });
  assert.throws(() => InventoryStatusSchema.parse('SHIPPED_UNKNOWN'));
  assert.throws(() => InventoryStatusSchema.parse('DESTROYED'));
});

runTest('Part 11: Inventory State Machine Transitions', () => {
  // Valid transitions
  assert.strictEqual(isValidInventoryStateTransition('PROVISIONED', 'VERIFIED'), true);
  assert.strictEqual(isValidInventoryStateTransition('VERIFIED', 'PACKING'), true);
  assert.strictEqual(isValidInventoryStateTransition('PACKING', 'PACKED'), true);
  assert.strictEqual(isValidInventoryStateTransition('PACKING', 'VERIFIED'), true);
  assert.strictEqual(isValidInventoryStateTransition('PROVISIONED', 'QUARANTINED'), true);
  assert.strictEqual(isValidInventoryStateTransition('VERIFIED', 'QUARANTINED'), true);
  assert.strictEqual(isValidInventoryStateTransition('PACKING', 'QUARANTINED'), true);
  assert.strictEqual(isValidInventoryStateTransition('QUARANTINED', 'PROVISIONED'), true);

  // Invalid transitions
  assert.strictEqual(isValidInventoryStateTransition('PACKED', 'VERIFIED'), false);
  assert.strictEqual(isValidInventoryStateTransition('PACKED', 'PROVISIONED'), false);
  assert.strictEqual(isValidInventoryStateTransition('PACKED', 'PACKING'), false);
  assert.strictEqual(isValidInventoryStateTransition('PROVISIONED', 'PACKED'), false); // Cannot bypass verification
});

runTest('Part 11: PackagingCartonSchema validation', () => {
  const validCarton = {
    id: 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
    cartonCode: 'CARTON-2026-001',
    productVariantId: 'eh-smart-switch-1x',
    hardwareRevision: 'HW_1_0',
    currentUnits: 0,
    targetCapacity: 1,
    status: 'OPEN',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  const parsed = PackagingCartonSchema.parse(validCarton);
  assert.strictEqual(parsed.cartonCode, 'CARTON-2026-001');

  // Negative: invalid status
  assert.throws(() => PackagingCartonSchema.parse({ ...validCarton, status: 'DISPATCHED' }));
});

runTest('Part 11: Dual-Scan Evaluation — Success Case', () => {
  const result = evaluateDualScan({
    item: {
      id: '0194fe23-7a1b-7890-a123-456789abcd01',
      deviceId: '0194fe23-7a1b-7890-a123-456789abcd02',
      serialNumber: 'EH-SW1X-2026W12-00001',
      productVariantId: 'eh-smart-switch-1x',
      hardwareRevision: 'HW_1_0',
      firmwareFamily: 'esp32c6-switch-platform',
      firmwareVersion: '1.0.0',
      traceId: '0194fe23-7a1b-7890-a123-456789abcd03',
      status: 'PROVISIONED',
      qcStatus: 'PASS',
      registeredAt: new Date().toISOString(),
    },
    scannedTokenOrUri: 'eh://p/v1?t=eh-tok-sw01-a1b2c3d4e5f607182930',
    stationId: 'STATION-01',
  });

  assert.strictEqual(result.isMatch, true);
  assert.strictEqual(result.status, 'MATCH_APPROVED');
  assert.strictEqual(result.errorCode, undefined);
  assert.ok(result.deviceId);
});

runTest('Part 11: Dual-Scan Evaluation — Rejections', () => {
  const baseItem = {
    id: '0194fe23-7a1b-7890-a123-456789abcd01',
    deviceId: '0194fe23-7a1b-7890-a123-456789abcd02',
    serialNumber: 'EH-SW1X-2026W12-00001',
    productVariantId: 'eh-smart-switch-1x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform',
    firmwareVersion: '1.0.0',
    traceId: '0194fe23-7a1b-7890-a123-456789abcd03',
    status: 'PROVISIONED',
    qcStatus: 'PASS',
    registeredAt: new Date().toISOString(),
  };

  // 1. Hardware Revision Mismatch
  const r1 = evaluateDualScan({
    item: { ...baseItem, hardwareRevision: 'HW_2_0' },
    scannedTokenOrUri: 'eh://p/v1?t=eh-tok-sw01-a1b2c3d4e5f607182930',
    stationId: 'STATION-01',
  });
  assert.strictEqual(r1.isMatch, false);
  assert.strictEqual(r1.errorCode, 'HARDWARE_REVISION_MISMATCH');

  // 2. Firmware Family Mismatch
  const r2 = evaluateDualScan({
    item: { ...baseItem, firmwareFamily: 'esp32c6-sensor-platform' },
    scannedTokenOrUri: 'eh://p/v1?t=eh-tok-sw01-a1b2c3d4e5f607182930',
    stationId: 'STATION-01',
  });
  assert.strictEqual(r2.isMatch, false);
  assert.strictEqual(r2.errorCode, 'FIRMWARE_FAMILY_MISMATCH');

  // 3. Already Packed Device
  const r3 = evaluateDualScan({
    item: { ...baseItem, status: 'PACKED' },
    scannedTokenOrUri: 'eh://p/v1?t=eh-tok-sw01-a1b2c3d4e5f607182930',
    stationId: 'STATION-01',
  });
  assert.strictEqual(r3.isMatch, false);
  assert.strictEqual(r3.errorCode, 'DEVICE_ALREADY_PACKED');

  // 4. Carton Variant Mismatch
  const r4 = evaluateDualScan({
    item: baseItem,
    scannedTokenOrUri: 'eh://p/v1?t=eh-tok-sw01-a1b2c3d4e5f607182930',
    stationId: 'STATION-01',
    carton: {
      id: 'carton-B',
      cartonCode: 'CARTON-B',
      productVariantId: 'eh-smart-switch-2x',
      hardwareRevision: 'HW_1_0',
      packedCount: 0,
      targetCapacity: 1,
      status: 'OPEN',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    },
  });
  assert.strictEqual(r4.isMatch, false);
  assert.strictEqual(r4.errorCode, 'VARIANT_MISMATCH');
});

runTest('Part 11: Zero-Secret Invariant on Inventory & Packing Payloads', () => {
  const cleanPackagingRecord = {
    id: 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
    traceId: '0194fe23-7a1b-7890-a123-456789abcd03',
    deviceId: '0194fe23-7a1b-7890-a123-456789abcd02',
    serialNumber: 'EH-SW1X-2026W12-00001',
    productVariantId: 'eh-smart-switch-1x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform',
    firmwareVersion: '1.0.0',
    cartonId: 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6e',
    verificationId: '0194fe23-7a1b-7890-a123-456789abcd04',
    stationId: 'STATION-01',
    operatorUserId: 'OP-01',
    packedAt: new Date().toISOString(),
  };

  assert.doesNotThrow(() => assertNoSecretsInRecord(cleanPackagingRecord));

  // Tainted records with secret keys must throw
  const tainted1 = { ...cleanPackagingRecord, commissioningSecret: 'super-secret-123' };
  assert.throws(() => assertNoSecretsInRecord(tainted1), /Security Violation/i);

  const tainted2 = { ...cleanPackagingRecord, privateKey: '0x1234567890' };
  assert.throws(() => assertNoSecretsInRecord(tainted2), /Security Violation/i);

  const tainted3 = { ...cleanPackagingRecord, wifiPassword: 'password123' };
  assert.throws(() => assertNoSecretsInRecord(tainted3), /Security Violation/i);
});

// ── PART 13: MQTT, TELEMETRY & SIGNED OTA TESTS ─────────────────────────
console.log('\n11. Part 13: MQTT, Telemetry & Signed OTA Contracts:');

runTest('Part 13: MqttTopicBuilder produces canonical topics', () => {
  const deviceId = '0194fe23-7a1b-7890-a123-456789abcdef';
  assert.strictEqual(MqttTopicBuilder.commands(deviceId), `eh/v1/devices/${deviceId}/commands`);
  assert.strictEqual(MqttTopicBuilder.commandReceipts(deviceId), `eh/v1/devices/${deviceId}/command-receipts`);
  assert.strictEqual(MqttTopicBuilder.state(deviceId), `eh/v1/devices/${deviceId}/state`);
  assert.strictEqual(MqttTopicBuilder.events(deviceId), `eh/v1/devices/${deviceId}/events`);
  assert.strictEqual(MqttTopicBuilder.telemetry(deviceId), `eh/v1/devices/${deviceId}/telemetry`);
  assert.strictEqual(MqttTopicBuilder.availability(deviceId), `eh/v1/devices/${deviceId}/availability`);
  assert.strictEqual(MqttTopicBuilder.ota(deviceId), `eh/v1/devices/${deviceId}/ota`);
  assert.strictEqual(MqttTopicBuilder.backendSubscribe('telemetry'), 'eh/v1/devices/+/telemetry');
});

runTest('Part 13: MqttTopicParser parses valid topic and rejects wildcards / malformed topics', () => {
  const deviceId = '0194fe23-7a1b-7890-a123-456789abcdef';
  const parsed = MqttTopicParser.parse(`eh/v1/devices/${deviceId}/commands`);
  assert.strictEqual(parsed.deviceId, deviceId);
  assert.strictEqual(parsed.category, 'commands');

  // Wildcards rejected
  assert.throws(() => MqttTopicParser.parse('eh/v1/devices/+/commands'), /wildcard/i);
  assert.throws(() => MqttTopicParser.parse('eh/v1/devices/#'), /wildcard/i);

  // Malformed deviceId rejected
  assert.throws(() => MqttTopicParser.parse('eh/v1/devices/not-a-uuid/commands'), /malformed/i);

  // Extra or empty segments rejected
  assert.throws(() => MqttTopicParser.parse(`eh/v1/devices/${deviceId}/commands/extra`), /segments/i);
  assert.throws(() => MqttTopicParser.parse(`eh/v1/devices/${deviceId}//commands`), /segment/i);
});

runTest('Part 13: QoS & Retain policy conforms to architectural specifications', () => {
  assert.deepStrictEqual(QOS_POLICY.commands, { qos: 1, retain: false });
  assert.deepStrictEqual(QOS_POLICY['command-receipts'], { qos: 1, retain: false });
  assert.deepStrictEqual(QOS_POLICY.state, { qos: 1, retain: false });
  assert.deepStrictEqual(QOS_POLICY.events, { qos: 1, retain: false });
  assert.deepStrictEqual(QOS_POLICY.telemetry, { qos: 0, retain: false });
  assert.deepStrictEqual(QOS_POLICY.availability, { qos: 1, retain: true });
  assert.deepStrictEqual(QOS_POLICY.ota, { qos: 1, retain: false });
});

runTest('Part 13: FixedPointEnergyTelemetrySchema validates range constraints', () => {
  const validTelem = {
    schemaVersion: 1,
    deviceId: '0194fe23-7a1b-7890-a123-456789abcdef',
    channelIndex: 1,
    v_mv: 230000,
    i_ma: 1250,
    p_mw: 287500,
    e_tot_wh: 15420,
    e_int_mwh: 120,
    freq_mhz: 50000,
    pf_x1000: 985,
    flags: 0,
    sequenceNumber: 1042,
    timestamp: new Date().toISOString()
  };
  const parsed = FixedPointEnergyTelemetrySchema.parse(validTelem);
  assert.strictEqual(parsed.v_mv, 230000);
  assert.strictEqual(parsed.pf_x1000, 985);

  // Negative voltage fails
  assert.throws(() => FixedPointEnergyTelemetrySchema.parse({ ...validTelem, v_mv: -5 }));
  // Power factor > 1000 fails
  assert.throws(() => FixedPointEnergyTelemetrySchema.parse({ ...validTelem, pf_x1000: 1050 }));
  // Negative current fails
  assert.throws(() => FixedPointEnergyTelemetrySchema.parse({ ...validTelem, i_ma: -1 }));
});

runTest('Part 13: CommandEnvelopeSchema & CommandReceiptSchema validation', () => {
  const validCmd = {
    schemaVersion: 1,
    commandId: '0194fe23-7a1b-7890-a123-456789abcd11',
    deviceId: '0194fe23-7a1b-7890-a123-456789abcdef',
    channelIndex: 2,
    action: 'setPower',
    params: { value: true },
    idempotencyKey: 'idem_test_part13_001',
    source: 'APP',
    expiresAt: new Date(Date.now() + 30000).toISOString()
  };
  const parsedCmd = CommandEnvelopeSchema.parse(validCmd);
  assert.strictEqual(parsedCmd.action, 'setPower');

  const validReceipt = {
    schemaVersion: 1,
    commandId: validCmd.commandId,
    deviceId: validCmd.deviceId,
    channelIndex: 2,
    status: 'APPLIED',
    timestamp: new Date().toISOString()
  };
  const parsedReceipt = CommandReceiptSchema.parse(validReceipt);
  assert.strictEqual(parsedReceipt.status, 'APPLIED');

  // Invalid receipt status fails
  assert.throws(() => CommandReceiptSchema.parse({ ...validReceipt, status: 'UNKNOWN_STATUS' }));
});

runTest('Part 13: DeviceAvailabilityPayloadSchema validation', () => {
  assert.strictEqual(DeviceAvailabilityPayloadSchema.parse('ONLINE'), 'ONLINE');
  assert.strictEqual(DeviceAvailabilityPayloadSchema.parse('OFFLINE'), 'OFFLINE');
  const objPayload = DeviceAvailabilityPayloadSchema.parse({ status: 'ONLINE', timestamp: new Date().toISOString() });
  assert.strictEqual(objPayload.status, 'ONLINE');
});

runTest('Part 13: OtaExecutionStateSchema enum validation', () => {
  const validStates = [
    'REQUESTED',
    'AUTHORIZED',
    'AVAILABLE',
    'DOWNLOADING',
    'VERIFYING',
    'INSTALLING',
    'SUCCEEDED',
    'FAILED',
    'ROLLED_BACK',
    'CANCELLED'
  ];
  for (const s of validStates) {
    assert.strictEqual(OtaExecutionStateSchema.parse(s), s);
  }
  assert.throws(() => OtaExecutionStateSchema.parse('INVALID_STATE'));
  assert.throws(() => OtaExecutionStateSchema.parse('UNKNOWN'));
});

runTest('Part 13: OTA legal forward lifecycle transitions validation', () => {
  // REQUESTED -> AUTHORIZED -> AVAILABLE -> DOWNLOADING -> VERIFYING -> INSTALLING -> SUCCEEDED
  assert.strictEqual(isValidOtaStateTransition('REQUESTED', 'AUTHORIZED'), true);
  assert.strictEqual(isValidOtaStateTransition('AUTHORIZED', 'AVAILABLE'), true);
  assert.strictEqual(isValidOtaStateTransition('AVAILABLE', 'DOWNLOADING'), true);
  assert.strictEqual(isValidOtaStateTransition('DOWNLOADING', 'VERIFYING'), true);
  assert.strictEqual(isValidOtaStateTransition('VERIFYING', 'INSTALLING'), true);
  assert.strictEqual(isValidOtaStateTransition('INSTALLING', 'SUCCEEDED'), true);

  // Idempotent transitions
  assert.strictEqual(isValidOtaStateTransition('DOWNLOADING', 'DOWNLOADING'), true);
  assert.strictEqual(isValidOtaStateTransition('SUCCEEDED', 'SUCCEEDED'), true);
});

runTest('Part 13: OTA failure, rollback & cancellation transitions validation', () => {
  // Failures from active states
  assert.strictEqual(isValidOtaStateTransition('REQUESTED', 'FAILED'), true);
  assert.strictEqual(isValidOtaStateTransition('AUTHORIZED', 'FAILED'), true);
  assert.strictEqual(isValidOtaStateTransition('AVAILABLE', 'FAILED'), true);
  assert.strictEqual(isValidOtaStateTransition('DOWNLOADING', 'FAILED'), true);
  assert.strictEqual(isValidOtaStateTransition('VERIFYING', 'FAILED'), true);
  assert.strictEqual(isValidOtaStateTransition('INSTALLING', 'FAILED'), true);

  // Rollback from verifying/installing/failed
  assert.strictEqual(isValidOtaStateTransition('VERIFYING', 'ROLLED_BACK'), true);
  assert.strictEqual(isValidOtaStateTransition('INSTALLING', 'ROLLED_BACK'), true);
  assert.strictEqual(isValidOtaStateTransition('FAILED', 'ROLLED_BACK'), true);

  // Cancellation from pre-download states
  assert.strictEqual(isValidOtaStateTransition('REQUESTED', 'CANCELLED'), true);
  assert.strictEqual(isValidOtaStateTransition('AUTHORIZED', 'CANCELLED'), true);
  assert.strictEqual(isValidOtaStateTransition('AVAILABLE', 'CANCELLED'), true);
});

runTest('Part 13: OTA invalid transitions rejection', () => {
  // Terminal -> active transitions rejected
  assert.strictEqual(isValidOtaStateTransition('SUCCEEDED', 'DOWNLOADING'), false);
  assert.strictEqual(isValidOtaStateTransition('CANCELLED', 'AUTHORIZED'), false);
  assert.strictEqual(isValidOtaStateTransition('ROLLED_BACK', 'INSTALLING'), false);

  // Backwards transitions rejected
  assert.strictEqual(isValidOtaStateTransition('DOWNLOADING', 'REQUESTED'), false);
  assert.strictEqual(isValidOtaStateTransition('INSTALLING', 'DOWNLOADING'), false);

  // Skipping verification rejected
  assert.strictEqual(isValidOtaStateTransition('AVAILABLE', 'INSTALLING'), false);
  assert.strictEqual(isValidOtaStateTransition('REQUESTED', 'INSTALLING'), false);

  // Cancellation after download started rejected
  assert.strictEqual(isValidOtaStateTransition('DOWNLOADING', 'CANCELLED'), false);
  assert.strictEqual(isValidOtaStateTransition('INSTALLING', 'CANCELLED'), false);

  // validateOtaStateTransition helper throws on invalid
  assert.throws(() => validateOtaStateTransition('REQUESTED', 'INSTALLING'), /Invalid OTA state transition/);
});

runTest('Part 13: OtaJobStatusUpdateRequestSchema & OtaJobCreateRequestSchema validation', () => {
  const validUpdate = {
    jobId: '0194fe23-7a1b-7890-a123-456789abcd22',
    status: 'DOWNLOADING',
    progressPercent: 50
  };
  const parsedUpdate = OtaJobStatusUpdateRequestSchema.parse(validUpdate);
  assert.strictEqual(parsedUpdate.progressPercent, 50);

  const validCreate = {
    deviceId: '0194fe23-7a1b-7890-a123-456789abcdef',
    releaseId: '0194fe23-7a1b-7890-a123-456789111111',
    fromVersion: '1.0.0'
  };
  const parsedCreate = OtaJobCreateRequestSchema.parse(validCreate);
  assert.strictEqual(parsedCreate.fromVersion, '1.0.0');

  // Invalid progress percent fails
  assert.throws(() => OtaJobStatusUpdateRequestSchema.parse({ ...validUpdate, progressPercent: 150 }));
});

// ── PART 14: RBAC, SECURITY & AUDIT CONTRACT TESTS ──────────────────────────

const {
  UserRoleSchema,
  HomeRoleSchema,
  PermissionSchema,
  PrincipalStatusSchema,
  PrincipalSchema,
  SecurityContextSchema,
  hasRolePermission,
  hasHomeRolePermission,
  evaluateAuthorization,
  AuditActionSchema,
  AuditResourceTypeSchema,
  AuditOutcomeSchema,
  AuditSeveritySchema,
  AuditRecordSchema,
  AuditQueryFilterSchema,
  assertNoSecretsInAuditPayload
} = require('../dist/index.js');

runTest('Part 14: UserRoleSchema, HomeRoleSchema & PrincipalStatusSchema validation', () => {
  const platformRoles = ['ADMIN', 'OPERATOR', 'RELEASE_ENGINEER', 'AUDITOR', 'USER', 'SERVICE'];
  platformRoles.forEach((r) => assert.strictEqual(UserRoleSchema.parse(r), r));
  assert.throws(() => UserRoleSchema.parse('SUPERUSER'));
  assert.throws(() => UserRoleSchema.parse('ROOT'));

  const homeRoles = ['OWNER', 'HOME_ADMIN', 'MEMBER', 'GUEST', 'VIEWER'];
  homeRoles.forEach((r) => assert.strictEqual(HomeRoleSchema.parse(r), r));
  assert.throws(() => HomeRoleSchema.parse('STRANGER'));
  assert.throws(() => HomeRoleSchema.parse('ADMIN'));

  const statuses = ['ACTIVE', 'DISABLED', 'REVOKED', 'PENDING_ACTIVATION'];
  statuses.forEach((s) => assert.strictEqual(PrincipalStatusSchema.parse(s), s));
  assert.throws(() => PrincipalStatusSchema.parse('BANNED'));
});

runTest('Part 14: Actionable PermissionSchema validation', () => {
  const samplePerms = [
    'product:read', 'product:write',
    'hardware:read', 'hardware:write',
    'firmware:read', 'firmware:write', 'firmware:approve', 'firmware:release', 'firmware:revoke',
    'ota:read', 'ota:authorize', 'ota:execute',
    'manufacturing:provision', 'manufacturing:qc', 'manufacturing:pack', 'manufacturing:inventory', 'manufacturing:print',
    'device:read', 'device:write', 'device:control', 'device:claim', 'device:unclaim', 'device:transfer', 'device:revoke',
    'home:read', 'home:write', 'home:delete', 'home:manage_members',
    'user:read', 'user:write', 'user:manage_roles',
    'audit:read', 'security:admin'
  ];
  samplePerms.forEach((p) => assert.strictEqual(PermissionSchema.parse(p), p));
  assert.throws(() => PermissionSchema.parse('unrestricted:*'));
  assert.throws(() => PermissionSchema.parse('delete:all'));
});

runTest('Part 14: RBAC hasRolePermission & hasHomeRolePermission mapping', () => {
  // ADMIN has universal role permissions
  assert.strictEqual(hasRolePermission('ADMIN', 'security:admin'), true);
  assert.strictEqual(hasRolePermission('ADMIN', 'firmware:approve'), true);
  assert.strictEqual(hasRolePermission('ADMIN', 'manufacturing:pack'), true);

  // RELEASE_ENGINEER
  assert.strictEqual(hasRolePermission('RELEASE_ENGINEER', 'firmware:approve'), true);
  assert.strictEqual(hasRolePermission('RELEASE_ENGINEER', 'ota:authorize'), true);
  assert.strictEqual(hasRolePermission('RELEASE_ENGINEER', 'manufacturing:pack'), false);
  assert.strictEqual(hasRolePermission('RELEASE_ENGINEER', 'user:manage_roles'), false);

  // OPERATOR
  assert.strictEqual(hasRolePermission('OPERATOR', 'manufacturing:pack'), true);
  assert.strictEqual(hasRolePermission('OPERATOR', 'manufacturing:qc'), true);
  assert.strictEqual(hasRolePermission('OPERATOR', 'firmware:approve'), false);
  assert.strictEqual(hasRolePermission('OPERATOR', 'security:admin'), false);

  // AUDITOR
  assert.strictEqual(hasRolePermission('AUDITOR', 'audit:read'), true);
  assert.strictEqual(hasRolePermission('AUDITOR', 'device:read'), true);
  assert.strictEqual(hasRolePermission('AUDITOR', 'device:write'), false);
  assert.strictEqual(hasRolePermission('AUDITOR', 'firmware:release'), false);

  // Home roles
  assert.strictEqual(hasHomeRolePermission('OWNER', 'home:delete'), true);
  assert.strictEqual(hasHomeRolePermission('MEMBER', 'home:delete'), false);
  assert.strictEqual(hasHomeRolePermission('MEMBER', 'device:control'), true);
  assert.strictEqual(hasHomeRolePermission('VIEWER', 'device:control'), false);
  assert.strictEqual(hasHomeRolePermission('VIEWER', 'home:read'), true);
});

runTest('Part 14: Default-Deny fail-closed evaluation', () => {
  const activeUser = {
    id: 'user-001',
    email: 'user@ehhome.io',
    role: 'USER',
    status: 'ACTIVE',
    homeMemberships: [{ homeId: 'home-100', role: 'MEMBER' }]
  };

  const activeContext = {
    principal: activeUser,
    authenticatedAt: new Date().toISOString()
  };

  // 1. Missing context -> DENIED
  assert.strictEqual(evaluateAuthorization(null, 'device:control').authorized, false);
  assert.strictEqual(evaluateAuthorization(undefined, 'device:control').authorized, false);

  // 2. Disabled user -> DENIED
  const disabledContext = {
    principal: { ...activeUser, status: 'DISABLED' },
    authenticatedAt: new Date().toISOString()
  };
  assert.strictEqual(evaluateAuthorization(disabledContext, 'device:control').authorized, false);

  // 3. Revoked user -> DENIED
  const revokedContext = {
    principal: { ...activeUser, status: 'REVOKED' },
    authenticatedAt: new Date().toISOString()
  };
  assert.strictEqual(evaluateAuthorization(revokedContext, 'device:control').authorized, false);

  // 4. Resource authorization: Home member authorized for Home 100
  const home100Decision = evaluateAuthorization(activeContext, 'device:control', { homeId: 'home-100' });
  assert.strictEqual(home100Decision.authorized, true);

  // 5. Cross-home authorization: Home member rejected for Home 200 (not a member)
  const home200Decision = evaluateAuthorization(activeContext, 'device:control', { homeId: 'home-200' });
  assert.strictEqual(home200Decision.authorized, false);

  // 6. Direct device ownership: Device claimed by another user is rejected
  const crossDeviceDecision = evaluateAuthorization(activeContext, 'device:control', {
    deviceId: 'dev-999',
    claimedByUserId: 'user-other'
  });
  assert.strictEqual(crossDeviceDecision.authorized, false);
});

runTest('Part 14: AuditAction, ResourceType & Severity schemas', () => {
  const validActions = [
    'AUTH_LOGIN_SUCCESS', 'AUTH_LOGIN_FAILED', 'PERMISSION_DENIED',
    'FIRMWARE_RELEASE_APPROVED', 'OTA_JOB_AUTHORIZED', 'DEVICE_CLAIMED',
    'PACKING_VERIFIED', 'SECURITY_POLICY_CHANGED'
  ];
  validActions.forEach((a) => assert.strictEqual(AuditActionSchema.parse(a), a));
  assert.throws(() => AuditActionSchema.parse('UNKNOWN_ACTION'));

  const validTypes = ['USER', 'HOME', 'DEVICE', 'FIRMWARE_RELEASE', 'OTA_JOB', 'BATCH', 'PACKAGING_RECORD'];
  validTypes.forEach((t) => assert.strictEqual(AuditResourceTypeSchema.parse(t), t));
});

runTest('Part 14: Zero-Secret Invariant on Audit Logging', () => {
  // Valid non-sensitive audit metadata
  const cleanMeta = {
    releaseId: '0194fe23-7a1b-7890-a123-456789abcdef',
    targetMcu: 'esp32-c6',
    progress: 100
  };
  assert.doesNotThrow(() => assertNoSecretsInAuditPayload(cleanMeta));

  // Metadata with password -> REJECTED
  assert.throws(() => assertNoSecretsInAuditPayload({ password: 'secretpassword123' }), /Security Violation/);
  assert.throws(() => assertNoSecretsInAuditPayload({ user: { wifiPassword: 'my-wifi-key' } }), /Security Violation/);
  assert.throws(() => assertNoSecretsInAuditPayload({ token: 'bearer-jwt-token' }), /Security Violation/);
  assert.throws(() => assertNoSecretsInAuditPayload({ privateKey: '-----BEGIN PRIVATE KEY-----' }), /Security Violation/);
});

runTest('Part 14: AuditRecordSchema and AuditQueryFilterSchema validation', () => {
  const validRecord = {
    id: '0194fe23-7a1b-7890-a123-456789abcdef',
    timestamp: new Date().toISOString(),
    actorId: 'user-admin-1',
    actorRole: 'ADMIN',
    action: 'FIRMWARE_RELEASE_APPROVED',
    resourceType: 'FIRMWARE_RELEASE',
    resourceId: 'rel-v1-0-0',
    outcome: 'SUCCESS',
    severity: 'INFO',
    metadata: { version: '1.0.0', channel: 'production' }
  };
  const parsed = AuditRecordSchema.parse(validRecord);
  assert.strictEqual(parsed.action, 'FIRMWARE_RELEASE_APPROVED');

  const validFilter = {
    action: 'FIRMWARE_RELEASE_APPROVED',
    outcome: 'SUCCESS',
    limit: 25,
    offset: 0
  };
  const parsedFilter = AuditQueryFilterSchema.parse(validFilter);
  assert.strictEqual(parsedFilter.limit, 25);

  // Filter with limit > 200 fails
  assert.throws(() => AuditQueryFilterSchema.parse({ limit: 500 }));
});

// ── SUMMARY ───────────────────────────────────────────────────────────
console.log(`\n=== ZOD CONTRACT TESTS SUMMARY ===`);
console.log(`Total:  ${totalTests}`);
console.log(`Passed: ${passedTests}`);
console.log(`Failed: ${failedTests}`);

if (failedTests > 0) {
  process.exit(1);
} else {
  console.log('ALL ZOD CONTRACT TESTS PASSED [OK]\n');
}

