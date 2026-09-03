const path = require('path');
const { SchemaValidator } = require('../validator');

const validator = new SchemaValidator();

// Load all canonical schemas
const schemaFiles = [
  '../identity/device-identity.schema.json',
  '../identity/network-identity.schema.json',
  '../identity/device-credential.schema.json',
  '../authorization/home-membership.schema.json',
  '../authorization/device-authorization.schema.json',
  '../product/hardware-profile.schema.json',
  '../product/connectivity-profile.schema.json',
  '../product/product-metadata.schema.json',
  '../capability/capability-schema.schema.json',
  '../state/channel-state.schema.json',
  '../state/device-state.schema.json',
  '../command/command.schema.json',
  '../command/command-receipt.schema.json',
  '../events/device-event.schema.json',
  '../energy/energy-telemetry.schema.json',
  '../energy/energy.schema.json',
  '../energy/energy-automation.schema.json',
  '../energy/energy-cost.schema.json',
  '../telemetry/telemetry.schema.json',
  '../automation/automation-rule.schema.json',
  '../ota/ota-manifest.schema.json',
  '../api/api-envelope.schema.json'
];

schemaFiles.forEach(f => validator.loadSchema(path.join(__dirname, f)));

let passed = 0;
let failed = 0;

function assert(description, condition, details = '') {
  if (condition) {
    console.log(`  [PASS] ${description}`);
    passed++;
  } else {
    console.error(`  [FAIL] ${description} ${details}`);
    failed++;
  }
}

console.log('=== HARDENED CONTRACT VALIDATION TESTS ===\n');

// 1. DeviceIdentity Tests
console.log('1. DeviceIdentity:');
const validDevId = {
  schemaVersion: 1,
  deviceId: "0194fe23-7a1b-7890-a123-456789abcdef",
  serialNumber: "EH-SW3X-2026W12-00891",
  productVariantId: "eh-smart-switch-3x",
  hardwareRevision: "HW_1_0",
  firmwareFamily: "esp32c6-switch-platform"
};
assert('Valid DeviceIdentity passes', validator.validate('DeviceIdentity', validDevId).valid);
assert('Missing deviceId fails', !validator.validate('DeviceIdentity', { ...validDevId, deviceId: undefined }).valid);
assert('Non-UUID deviceId fails', !validator.validate('DeviceIdentity', { ...validDevId, deviceId: "not-a-uuid" }).valid);

// 2. DeviceCredential Hardening Tests
console.log('\n2. DeviceCredential Hardening:');
const validCred = {
  schemaVersion: 1,
  deviceId: "0194fe23-7a1b-7890-a123-456789abcdef",
  mqttUsername: "eh_dev_0194fe237a1b7890",
  mqttPasswordHash: "$argon2id$v=19$m=65536,t=3,p=4$dummyhash...",
  tlsClientCertFingerprint: null,
  localSessionKeyHash: "sha256_dummy_hash_for_factory_key",
  credentialState: "ACTIVE",
  createdAt: "2026-03-01T08:00:00Z",
  rotatedAt: null
};
assert('Valid DeviceCredential passes', validator.validate('DeviceCredential', validCred).valid);

const validStates = ["FACTORY", "PROVISIONED", "CLAIMED", "ACTIVE", "ROTATED", "REVOKED", "RESET"];
validStates.forEach(st => {
  assert(`credentialState '${st}' is valid`, validator.validate('DeviceCredential', { ...validCred, credentialState: st }).valid);
});

assert('Invalid credentialState fails enum', !validator.validate('DeviceCredential', { ...validCred, credentialState: "INVALID_STATE" }).valid);
assert('Missing deviceId in credential fails', !validator.validate('DeviceCredential', { ...validCred, deviceId: undefined }).valid);
assert('Missing localSessionKeyHash fails', !validator.validate('DeviceCredential', { ...validCred, localSessionKeyHash: undefined }).valid);

// 3. ProductMetadata & Profiles:
console.log('\n3. ProductMetadata & Profiles:');
const validProduct = {
  schemaVersion: 1,
  productVariantId: "eh-smart-switch-3x",
  productFamily: "smart_switch",
  displayName: "EH Smart Switch 3X",
  channelCount: 3,
  channels: [
    { channelIndex: 1, defaultLabel: "Light 1", capabilities: ["relay"] },
    { channelIndex: 2, defaultLabel: "Light 2", capabilities: ["relay"] },
    { channelIndex: 3, defaultLabel: "Light 3", capabilities: ["relay"] }
  ],
  hardwareProfile: {
    schemaVersion: 1,
    mcuFamily: "esp32-c6",
    flashSizeBytes: 4194304,
    hasEnergyMetering: true,
    maxRelayAmpsPerChannel: 10.0
  },
  connectivityProfile: {
    schemaVersion: 1,
    supportsWifi: true,
    supportsBle: true,
    supportsThread: false,
    supportsMatter: false
  },
  capabilities: ["switch", "relay", "energy", "ota"],
  electricalSpecifications: {
    voltageRange: "90V - 250V AC",
    frequencyHz: "50/60Hz"
  },
  firmwareFamily: "esp32c6-switch-platform",
  supportedHardwareRevisions: ["HW_1_0"]
};
assert('Valid ProductMetadata passes', validator.validate('ProductMetadata', validProduct).valid);
assert('Invalid productFamily fails enum', !validator.validate('ProductMetadata', { ...validProduct, productFamily: "unknown_family" }).valid);

// 4. DeviceState Hardening & Decoupling Tests
console.log('\n4. DeviceState & Decoupled State Semantics:');
const decoupledChannelState = {
  schemaVersion: 1,
  channelIndex: 1,
  desiredState: { power: true },   // Requested ON
  reportedState: { power: false }, // Physical switch reports OFF
  confidence: "CONFIRMED",
  updatedAt: "2026-03-01T12:00:00Z"
};
assert('desiredState != reportedState is valid (represents in-flight/overridden command)', validator.validate('ChannelState', decoupledChannelState).valid);

const validConnStates = ["ONLINE", "STALE", "OFFLINE"];
validConnStates.forEach(conn => {
  const stateWithConn = {
    schemaVersion: 1,
    deviceId: "0194fe23-7a1b-7890-a123-456789abcdef",
    connectionState: conn,
    channels: [decoupledChannelState],
    updatedAt: "2026-03-01T12:00:00Z"
  };
  assert(`connectionState '${conn}' is valid`, validator.validate('DeviceState', stateWithConn).valid);
});

assert('Invalid connectionState fails', !validator.validate('DeviceState', {
  schemaVersion: 1,
  deviceId: "0194fe23-7a1b-7890-a123-456789abcdef",
  connectionState: "DISCONNECTED",
  channels: [decoupledChannelState],
  updatedAt: "2026-03-01T12:00:00Z"
}).valid);

assert('Invalid confidence fails enum', !validator.validate('ChannelState', {
  ...decoupledChannelState,
  confidence: "MAYBE"
}).valid);

assert('Invalid channelIndex (0 or negative) fails minimum', !validator.validate('ChannelState', {
  ...decoupledChannelState,
  channelIndex: 0
}).valid);

// 5. Physical Switch Conflict Scenario Test
console.log('\n5. Physical Switch Conflict & Override Scenario:');
// Step 1: App dispatches command ON
const cloudCmd = {
  schemaVersion: 1,
  commandId: "0194fe23-7a1b-7890-a123-456789111111",
  deviceId: "0194fe23-7a1b-7890-a123-456789abcdef",
  channelIndex: 1,
  action: "setPower",
  params: { value: true },
  idempotencyKey: "idem_cloud_001",
  source: "APP",
  timestamp: "2026-03-01T12:00:00.000Z",
  expiresAt: "2026-03-01T12:00:15.000Z"
};
assert('Cloud command ON is valid', validator.validate('Command', cloudCmd).valid);

// Step 2: Physical switch toggles to OFF before cloud command applied
const physicalEvt = {
  schemaVersion: 1,
  eventId: "0194fe23-7a1b-7890-a123-456789222222",
  deviceId: "0194fe23-7a1b-7890-a123-456789abcdef",
  channelIndex: 1,
  eventType: "switch.changed",
  source: "PHYSICAL_SWITCH",
  payload: { power: false },
  timestamp: "2026-03-01T12:00:00.050Z",
  sequenceNumber: 101
};
assert('Physical switch event OFF is valid', validator.validate('DeviceEvent', physicalEvt).valid);

// Step 3: Command receipt records OVERRIDDEN
const overriddenReceipt = {
  schemaVersion: 1,
  commandId: cloudCmd.commandId,
  deviceId: cloudCmd.deviceId,
  channelIndex: cloudCmd.channelIndex,
  status: "OVERRIDDEN",
  failureReason: "Superseded by PHYSICAL_SWITCH toggle",
  timestamp: "2026-03-01T12:00:00.080Z"
};
assert('Command receipt status OVERRIDDEN is valid', validator.validate('CommandReceipt', overriddenReceipt).valid);

// Step 4: Final hardware reported state is OFF
const finalHardwareState = {
  schemaVersion: 1,
  deviceId: cloudCmd.deviceId,
  connectionState: "ONLINE",
  channels: [
    {
      schemaVersion: 1,
      channelIndex: 1,
      desiredState: { power: false },
      reportedState: { power: false },
      confidence: "CONFIRMED",
      updatedAt: "2026-03-01T12:00:00.085Z"
    }
  ],
  updatedAt: "2026-03-01T12:00:00.085Z"
};
assert('Final state correctly converges to physical OFF', validator.validate('DeviceState', finalHardwareState).valid && finalHardwareState.channels[0].reportedState.power === false);

// 6. EnergyTelemetry Hardening (Integer Fixed-Point Constraints)
console.log('\n6. EnergyTelemetry Hardening:');
const validEnergy = {
  schemaVersion: 1,
  deviceId: "0194fe23-7a1b-7890-a123-456789abcdef",
  channelIndex: 1,
  v_mv: 230450,       // 230.450 V
  i_ma: 812,          // 0.812 A
  p_mw: 187120,       // 187.120 W
  e_tot_wh: 142508,   // 142.508 kWh
  e_int_mwh: 259800,  // 259.800 Wh
  freq_mhz: 50010,    // 50.010 Hz
  pf_x1000: 980,      // 0.980
  flags: 0,
  timestamp: "2026-03-01T12:00:00Z",
  sequenceNumber: 48102
};
assert('Valid EnergyTelemetry passes', validator.validate('EnergyTelemetry', validEnergy).valid);

// Reset flag test
const energyWithReset = { ...validEnergy, flags: 1 }; // Bit 0 set (COUNTER_RESET)
assert('EnergyTelemetry with reset flag (1) is valid', validator.validate('EnergyTelemetry', energyWithReset).valid);

// Range tests
assert('Negative voltage fails', !validator.validate('EnergyTelemetry', { ...validEnergy, v_mv: -1 }).valid);
assert('Negative current fails', !validator.validate('EnergyTelemetry', { ...validEnergy, i_ma: -1 }).valid);
assert('Negative power fails', !validator.validate('EnergyTelemetry', { ...validEnergy, p_mw: -1 }).valid);
assert('Negative energy fails', !validator.validate('EnergyTelemetry', { ...validEnergy, e_tot_wh: -1 }).valid);
assert('Power factor > 1000 fails', !validator.validate('EnergyTelemetry', { ...validEnergy, pf_x1000: 1001 }).valid);
assert('Power factor < 0 fails', !validator.validate('EnergyTelemetry', { ...validEnergy, pf_x1000: -1 }).valid);
assert('Flags > 255 fails uint8 constraint', !validator.validate('EnergyTelemetry', { ...validEnergy, flags: 256 }).valid);

// Large cumulative energy (uint64 support)
const largeCumulativeEnergy = { ...validEnergy, e_tot_wh: 9007199254740991 }; // Max safe integer
assert('Large cumulative energy value passes', validator.validate('EnergyTelemetry', largeCumulativeEnergy).valid);

// 7. EnergyUsageSummary:
console.log('\n7. EnergyUsageSummary:');
const validSummary = {
  schemaVersion: 1,
  entityType: 'home',
  entityId: '0194fe23-7a1b-7890-a123-111111111111',
  period: 'today',
  currentPowerW: 450.5,
  totalEnergyKwh: 3.82,
  peakPowerW: 1850.0,
  avgPowerW: 320.2,
  minPowerW: 45.0,
  costEstimate: 0.57,
  currency: 'USD',
  dataQuality: 'GOOD',
  sampleCount: 120,
  lastUpdated: '2026-09-02T12:00:00Z'
};
assert('Valid EnergyUsageSummary passes', validator.validate('EnergyUsageSummary', validSummary).valid);
assert('Invalid entityType fails', !validator.validate('EnergyUsageSummary', { ...validSummary, entityType: 'invalid' }).valid);
assert('Negative power fails', !validator.validate('EnergyUsageSummary', { ...validSummary, currentPowerW: -10 }).valid);
assert('Invalid period fails', !validator.validate('EnergyUsageSummary', { ...validSummary, period: 'invalid_period' }).valid);

// 8. EnergyAutomationRule:
console.log('\n8. EnergyAutomationRule:');
const validEnergyRule = {
  schemaVersion: 1,
  id: 'auto_energy_01',
  homeId: '0194fe23-7a1b-7890-a123-111111111111',
  name: 'Oven High Power Auto-Off',
  description: 'Turn off switch when sustained power > 2000W for 60s',
  isEnabled: true,
  scopeType: 'device',
  scopeId: '0194fe23-7a1b-7890-a123-456789abcdef',
  triggerCondition: {
    metric: 'sustained_power',
    operator: 'GT',
    threshold: 2000.0,
    durationSeconds: 60,
    timeWindow: {
      startTime: '22:00',
      endTime: '06:00',
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7]
    }
  },
  hysteresis: {
    recoveryThreshold: 1500.0,
    cooldownSeconds: 300,
    minimumDurationSeconds: 60
  },
  actions: [
    {
      actionType: 'device_command',
      deviceId: '0194fe23-7a1b-7890-a123-456789abcdef',
      channelIndex: 1,
      command: 'setPower',
      params: { value: false }
    }
  ],
  cooldownSeconds: 300
};

assert('Valid EnergyAutomationRule passes', validator.validate('EnergyAutomationRule', validEnergyRule).valid);
assert('Missing triggerCondition fails', !validator.validate('EnergyAutomationRule', { ...validEnergyRule, triggerCondition: undefined }).valid);
assert('Invalid metric enum fails', !validator.validate('EnergyAutomationRule', {
  ...validEnergyRule,
  triggerCondition: { ...validEnergyRule.triggerCondition, metric: 'invalid_metric' }
}).valid);
assert('Invalid operator enum fails', !validator.validate('EnergyAutomationRule', {
  ...validEnergyRule,
  triggerCondition: { ...validEnergyRule.triggerCondition, operator: 'INVALID' }
}).valid);
assert('Empty actions fails minItems', !validator.validate('EnergyAutomationRule', { ...validEnergyRule, actions: [] }).valid);

// 9. ElectricityTariff:
console.log('\n9. ElectricityTariff:');
const validTariff = {
  schemaVersion: 1,
  id: 'tariff_tou_01',
  homeId: '0194fe23-7a1b-7890-a123-111111111111',
  name: 'Standard Time-Of-Use Tariff',
  tariffType: 'TIME_OF_USE',
  currency: 'USD',
  flatRatePerKwh: null,
  fixedDailyCharge: 0.50,
  effectiveFrom: '2026-01-01T00:00:00Z',
  effectiveTo: null,
  carbonIntensityGPerKwh: 420.0,
  isActive: true,
  periods: [
    {
      id: 'period_offpeak_1',
      periodType: 'OFF_PEAK',
      startTime: '22:00',
      endTime: '06:00',
      applicableWeekdays: [1, 2, 3, 4, 5, 6, 7],
      pricePerKwh: 0.08
    },
    {
      id: 'period_peak_1',
      periodType: 'PEAK',
      startTime: '14:00',
      endTime: '20:00',
      applicableWeekdays: [1, 2, 3, 4, 5],
      pricePerKwh: 0.28
    },
    {
      id: 'period_std_1',
      periodType: 'STANDARD',
      startTime: '06:00',
      endTime: '14:00',
      applicableWeekdays: [1, 2, 3, 4, 5],
      pricePerKwh: 0.15
    }
  ],
  metadata: { provider: 'Pacific Energy', planCode: 'TOU-EV2' }
};

assert('Valid ElectricityTariff passes', validator.validate('ElectricityTariff', validTariff).valid);
assert('Missing effectiveFrom fails', !validator.validate('ElectricityTariff', { ...validTariff, effectiveFrom: undefined }).valid);
assert('Invalid tariffType fails', !validator.validate('ElectricityTariff', { ...validTariff, tariffType: 'INVALID_TYPE' }).valid);
assert('Invalid currency code length fails', !validator.validate('ElectricityTariff', { ...validTariff, currency: 'US' }).valid);
assert('Invalid period startTime format fails', !validator.validate('ElectricityTariff', {
  ...validTariff,
  periods: [{ ...validTariff.periods[0], startTime: '25:99' }]
}).valid);
assert('Negative period price fails', !validator.validate('ElectricityTariff', {
  ...validTariff,
  periods: [{ ...validTariff.periods[0], pricePerKwh: -0.05 }]
}).valid);

console.log(`\n========================================`);
console.log(`Total Passed: ${passed}, Total Failed: ${failed}`);
console.log(`========================================\n`);

process.exit(failed > 0 ? 1 : 0);
