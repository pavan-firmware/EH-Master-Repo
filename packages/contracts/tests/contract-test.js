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
  '../product/product-family.schema.json',
  '../product/product-model.schema.json',
  '../product/product-variant.schema.json',
  '../product/product-asset.schema.json',
  '../product/product-catalog-entry.schema.json',
  '../product/product-discovery-response.schema.json',
  '../product/product-search-result.schema.json',
  '../product/product-compatibility.schema.json',
  '../product/device-add-session.schema.json',
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
  '../energy/energy-forecasting.schema.json',
  '../context/presence-context.schema.json',
  '../intelligence/home-intelligence.schema.json',
  '../reliability/device-reliability.schema.json',
  '../connectivity/device-connectivity.schema.json',
  '../telemetry/telemetry.schema.json',
  '../automation/automation-rule.schema.json',
  '../ota/ota-manifest.schema.json',
  '../api/api-envelope.schema.json',
  '../edge/local-execution-request.schema.json',
  '../edge/execution-route-decision.schema.json',
  '../edge/local-connectivity-state.schema.json',
  '../edge/local-device-discovery.schema.json',
  '../edge/local-execution-result.schema.json',
  '../edge/local-state-event.schema.json',
  '../edge/edge-automation-execution.schema.json',
  '../matter/matter-device.schema.json',
  '../matter/matter-fabric.schema.json',
  '../matter/matter-endpoint.schema.json',
  '../matter/matter-commissioning-session.schema.json',
  '../matter/matter-sync-event.schema.json',
  '../matter/external-platform-link.schema.json',
  '../matter/interoperability-capability-mapping.schema.json',
  '../notification/platform-event.schema.json',
  '../notification/user-notification.schema.json',
  '../notification/notification-preference.schema.json',
  '../notification/notification-delivery.schema.json',
  '../notification/notification-action.schema.json',
  '../notification/notification-aggregation.schema.json',
  '../operations/operational-event.schema.json',
  '../operations/audit-record.schema.json',
  '../operations/operation-trace.schema.json',
  '../operations/system-health.schema.json'
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

// 10. Phase 22 Energy Forecasting & Predictive Intelligence Hardening Tests
console.log('\n10. Phase 22 Energy Forecasting & Predictive Intelligence:');

const validForecast = {
  id: 'fc_home_01_24h',
  homeId: 'home_01',
  scopeType: 'home',
  scopeId: 'home_01',
  horizon: 'next_24_hours',
  startTime: '2026-07-16T00:00:00Z',
  endTime: '2026-07-17T00:00:00Z',
  predictedKwh: 14.5,
  predictedCost: 3.25,
  currency: 'USD',
  confidenceScore: 0.88,
  methodology: 'HISTORICAL_HOURLY_PROFILE_DAY_OF_WEEK',
  dataCoverage: 'FULL',
  isEstimate: true,
  generatedAt: '2026-07-15T23:59:59Z',
  points: [
    {
      timestamp: '2026-07-16T00:00:00Z',
      predictedPowerW: 450,
      predictedEnergyWh: 450,
      predictedCost: 0.036,
      confidenceScore: 0.90
    }
  ]
};

assert('Valid EnergyForecast passes', validator.validate('EnergyForecast', validForecast).valid);
assert('Missing confidenceScore fails', !validator.validate('EnergyForecast', { ...validForecast, confidenceScore: undefined }).valid);
assert('isEstimate not true fails', !validator.validate('EnergyForecast', { ...validForecast, isEstimate: false }).valid);
assert('Invalid horizon fails', !validator.validate('EnergyForecast', { ...validForecast, horizon: 'next_century' }).valid);

const validBaseline = {
  id: 'base_dev_ac_01',
  homeId: 'home_01',
  scopeType: 'device',
  scopeId: 'dev_ac_01',
  typicalPowerW: 1850.0,
  typicalDailyEnergyKwh: 8.5,
  typicalOvernightWh: 120.0,
  typicalOperatingHours: [14, 15, 16, 17, 18, 19, 20],
  sampleCount: 48,
  confidence: 0.92,
  calculatedAt: '2026-07-15T23:59:59Z'
};

assert('Valid EnergyBaseline passes', validator.validate('EnergyBaseline', validBaseline).valid);
assert('Negative typicalPowerW fails', !validator.validate('EnergyBaseline', { ...validBaseline, typicalPowerW: -10 }).valid);
assert('Missing sampleCount fails', !validator.validate('EnergyBaseline', { ...validBaseline, sampleCount: undefined }).valid);

const validAnomaly = {
  id: 'anom_01',
  homeId: 'home_01',
  scopeType: 'device',
  scopeId: 'dev_ac_01',
  anomalyType: 'UNEXPECTED_OVERNIGHT_LOAD',
  severity: 'HIGH',
  observedValue: 1200.0,
  baselineValue: 120.0,
  deviationPercentage: 900.0,
  isConfirmed: true,
  confirmationCount: 3,
  evidence: { overnightPeriod: '02:00-05:00', durationHours: 3 },
  detectedAt: '2026-07-15T03:30:00Z'
};

assert('Valid EnergyAnomaly passes', validator.validate('EnergyAnomaly', validAnomaly).valid);
assert('Invalid anomaly severity fails', !validator.validate('EnergyAnomaly', { ...validAnomaly, severity: 'EXTREME' }).valid);
assert('Invalid anomalyType fails', !validator.validate('EnergyAnomaly', { ...validAnomaly, anomalyType: 'ALIEN_ATTACK' }).valid);

const validScore = {
  id: 'eff_home_01',
  homeId: 'home_01',
  score: 84.5,
  grade: 'A',
  factors: {
    standbyLossScore: 90.0,
    peakDemandScore: 82.0,
    thresholdViolationScore: 95.0,
    tariffEfficiencyScore: 78.0,
    trendScore: 78.0
  },
  evidence: { vampireDrawW: 35, peakHoursRatio: 0.18 },
  calculatedAt: '2026-07-15T23:59:59Z'
};

assert('Valid EnergyEfficiencyScore passes', validator.validate('EnergyEfficiencyScore', validScore).valid);
assert('Score above 100 fails', !validator.validate('EnergyEfficiencyScore', { ...validScore, score: 105 }).valid);
assert('Invalid grade fails', !validator.validate('EnergyEfficiencyScore', { ...validScore, grade: 'Z' }).valid);

const validOpt = {
  id: 'pred_opt_01',
  homeId: 'home_01',
  deviceId: 'dev_ev_01',
  category: 'PEAK_AVOIDANCE',
  priority: 'HIGH',
  title: 'Pre-cool living room before 4 PM peak tariff window',
  description: 'Forecasted peak temperature will cause high AC load during expensive $0.32/kWh peak window.',
  reason: 'Predicted peak price window (16:00-21:00) with expected high outdoor heat',
  evidence: { predictedPeakW: 3200, peakPricePerKwh: 0.32 },
  estimatedKwhSavings: 4.5,
  estimatedCostSavings: 1.08,
  currency: 'USD',
  confidence: 0.85,
  isEstimate: true,
  generatedAt: '2026-07-15T12:00:00Z',
  isDismissed: false
};

assert('Valid PredictiveOptimizationRecommendation passes', validator.validate('PredictiveOptimizationRecommendation', validOpt).valid);
console.log('\n--- Section 11: Phase 23 Presence and Context Intelligence Schemas ---');

validator.loadSchema(path.join(__dirname, '../context/presence-context.schema.json'));

const validSignal = {
  userId: 'usr_owner_01',
  homeId: 'home_01',
  source: 'mobile_app',
  state: 'HOME',
  confidence: 0.95,
  observedAt: '2026-07-16T14:30:00Z',
  expiresAt: '2026-07-16T15:30:00Z',
  evidence: { accuracyMeters: 15, batteryPercent: 82 }
};

assert('Valid PresenceSignal passes', validator.validate('PresenceSignal', validSignal).valid);
assert('Missing userId in PresenceSignal fails', !validator.validate('PresenceSignal', { ...validSignal, userId: '' }).valid);
assert('Invalid source in PresenceSignal fails', !validator.validate('PresenceSignal', { ...validSignal, source: 'telepathy' }).valid);
assert('Confidence > 1.0 fails', !validator.validate('PresenceSignal', { ...validSignal, confidence: 1.5 }).valid);
assert('Confidence < 0.0 fails', !validator.validate('PresenceSignal', { ...validSignal, confidence: -0.2 }).valid);
assert('Invalid presence state fails', !validator.validate('PresenceSignal', { ...validSignal, state: 'DISAPPEARED' }).valid);

const validSnapshot = {
  homeId: 'home_01',
  state: 'HOME',
  confidence: 0.90,
  isOccupied: true,
  activeUserCount: 1,
  userStates: {
    usr_owner_01: {
      state: 'HOME',
      confidence: 0.95,
      source: 'mobile_app',
      observedAt: '2026-07-16T14:30:00Z',
      isStale: false
    }
  },
  inferredRooms: [
    {
      roomId: 'room_living_01',
      isOccupied: true,
      confidence: 0.75,
      isInferred: true,
      inferenceReason: 'Recent light switch action',
      lastActivityAt: '2026-07-16T14:28:00Z'
    }
  ],
  calculatedAt: '2026-07-16T14:30:05Z'
};

assert('Valid PresenceSnapshot passes', validator.validate('PresenceSnapshot', validSnapshot).valid);
assert('Missing homeId in PresenceSnapshot fails', !validator.validate('PresenceSnapshot', { ...validSnapshot, homeId: '' }).valid);
assert('Negative activeUserCount in PresenceSnapshot fails', !validator.validate('PresenceSnapshot', { ...validSnapshot, activeUserCount: -1 }).valid);

const validOverride = {
  id: 'ovr_01',
  homeId: 'home_01',
  userId: 'usr_owner_01',
  mode: 'VACATION',
  state: 'AWAY',
  reason: 'Summer holiday trip',
  createdAt: '2026-07-16T10:00:00Z',
  expiresAt: '2026-07-23T10:00:00Z',
  isActive: true
};

assert('Valid PresenceOverride passes', validator.validate('PresenceOverride', validOverride).valid);
assert('Invalid mode in PresenceOverride fails', !validator.validate('PresenceOverride', { ...validOverride, mode: 'PARTY' }).valid);

const validContext = {
  homeId: 'home_01',
  mode: 'VACATION',
  previousMode: 'HOME',
  precedenceTier: 'MANUAL_OVERRIDE',
  activeOverride: {
    id: 'ovr_01',
    userId: 'usr_owner_01',
    mode: 'VACATION',
    reason: 'Summer holiday trip',
    expiresAt: '2026-07-23T10:00:00Z'
  },
  isVacation: true,
  isOccupied: false,
  confidence: 1.0,
  updatedAt: '2026-07-16T10:00:05Z'
};

assert('Valid HomeContext passes', validator.validate('HomeContext', validContext).valid);
assert('Invalid precedenceTier in HomeContext fails', !validator.validate('HomeContext', { ...validContext, precedenceTier: 'ARBITRARY' }).valid);

const validTransition = {
  id: 'trans_01',
  homeId: 'home_01',
  fromMode: 'HOME',
  toMode: 'AWAY',
  triggerSource: 'all_users_left',
  reason: 'Deterministic reconciliation: 0 active users remaining',
  evidence: { departedUserId: 'usr_owner_01' },
  timestamp: '2026-07-16T14:35:00Z'
};

assert('Valid ContextTransition passes', validator.validate('ContextTransition', validTransition).valid);
assert('Missing timestamp in ContextTransition fails', !validator.validate('ContextTransition', { ...validTransition, timestamp: undefined }).valid);

// 12. Phase 24 Intelligence & Decision Engine Contracts
console.log('\n--- Section 12: Phase 24 Intelligence and Unified Decision Schemas ---');
const validIntelSnapshot = {
  homeId: 'home_01',
  timestamp: '2026-07-16T15:00:00Z',
  homeContext: 'AWAY',
  presenceState: 'AWAY',
  isOccupied: false,
  deviceCount: 6,
  activeDevicesCount: 2,
  totalPowerW: 420.5,
  tariffPeriod: 'PEAK',
  tariffPrice: 0.35,
  forecastPredictedKwh: 12.4,
  activeAnomalyCount: 1,
  activeAutomationCount: 4,
  activeScheduleCount: 2
};

assert('Valid HomeIntelligenceSnapshot passes', validator.validate('HomeIntelligenceSnapshot', validIntelSnapshot).valid);
assert('Missing homeId in HomeIntelligenceSnapshot fails', !validator.validate('HomeIntelligenceSnapshot', { ...validIntelSnapshot, homeId: undefined }).valid);
assert('Negative totalPowerW in HomeIntelligenceSnapshot fails', !validator.validate('HomeIntelligenceSnapshot', { ...validIntelSnapshot, totalPowerW: -10 }).valid);

const validDecision = {
  id: 'dec_01',
  homeId: 'home_01',
  decisionType: 'LOAD_SHEDDING',
  priority: 'ENERGY_COST_OPTIMIZATION',
  priorityRank: 5,
  confidence: 'HIGH',
  confidenceScore: 0.95,
  risk: 'LOW',
  evidence: { currentTariff: 'PEAK', price: 0.35, powerW: 1500 },
  proposedAction: { actionType: 'device_command', deviceId: 'dev_ac_01', command: 'setPower', value: false },
  expectedEffect: 'Reduce peak power by 1500W and save $0.52/hr',
  isAutoExecutable: true,
  safetyResult: { isSafe: true, riskLevel: 'LOW', reason: 'Non-critical cooling load' },
  status: 'GENERATED',
  createdAt: '2026-07-16T15:00:00Z',
  expiresAt: '2026-07-16T16:00:00Z'
};

assert('Valid IntelligenceDecision passes', validator.validate('IntelligenceDecision', validDecision).valid);
assert('Invalid priority enum in IntelligenceDecision fails', !validator.validate('IntelligenceDecision', { ...validDecision, priority: 'SUPER_URGENT' }).valid);
assert('Invalid risk enum in IntelligenceDecision fails', !validator.validate('IntelligenceDecision', { ...validDecision, risk: 'EXTREME' }).valid);
assert('Invalid status in IntelligenceDecision fails', !validator.validate('IntelligenceDecision', { ...validDecision, status: 'DONE' }).valid);

const validRecommendation = {
  id: 'rec_01',
  homeId: 'home_01',
  recommendationType: 'TURN_OFF_UNUSED_DEVICE',
  priority: 'CONVENIENCE_RECOMMENDATION',
  priorityRank: 7,
  confidence: 'HIGH',
  risk: 'LOW',
  title: 'Turn Off Unused Basement Lights',
  description: 'Basement light switch has been drawing 60W for 8 hours with zero room presence.',
  evidence: { durationHours: 8, roomOccupied: false, deviceId: 'dev_light_base' },
  proposedAction: { deviceId: 'dev_light_base', command: 'setPower', params: { value: false } },
  expectedBenefit: 'Saves ~0.48 kWh ($0.12) per day',
  isAutoExecutable: true,
  status: 'GENERATED',
  createdAt: '2026-07-16T15:00:00Z'
};

assert('Valid IntelligenceRecommendation passes', validator.validate('IntelligenceRecommendation', validRecommendation).valid);
assert('Invalid recommendationType fails', !validator.validate('IntelligenceRecommendation', { ...validRecommendation, recommendationType: 'UNKNOWN_REC' }).valid);

const validOutcome = {
  id: 'out_01',
  decisionId: 'dec_01',
  homeId: 'home_01',
  status: 'EXECUTED',
  executedAt: '2026-07-16T15:01:00Z',
  previousState: { powerState: true },
  newState: { powerState: false },
  expectedBenefit: 'Save 1500W load',
  actualBenefit: 'Load dropped by 1485W',
  feedback: 'User confirmed via app'
};

assert('Valid DecisionOutcome passes', validator.validate('DecisionOutcome', validOutcome).valid);
assert('Missing decisionId in DecisionOutcome fails', !validator.validate('DecisionOutcome', { ...validOutcome, decisionId: undefined }).valid);

// ── Phase 25 — Device Reliability Contract Tests ──────────────────────────
console.log('\n14. DeviceReliabilitySnapshot:');
const validReliabilitySnapshot = {
  id: 'snap_01',
  homeId: 'home_01',
  deviceId: 'dev_01',
  healthState: 'HEALTHY',
  healthScore: 95.0,
  activeIncidents: 0,
  snapshottedAt: '2026-09-03T12:00:00Z',
  createdAt: '2026-09-03T12:00:00Z'
};
assert('Valid DeviceReliabilitySnapshot passes', validator.validate('DeviceReliabilitySnapshot', validReliabilitySnapshot).valid);
assert('Invalid healthState fails', !validator.validate('DeviceReliabilitySnapshot', { ...validReliabilitySnapshot, healthState: 'GREAT' }).valid);
assert('healthScore > 100 fails', !validator.validate('DeviceReliabilitySnapshot', { ...validReliabilitySnapshot, healthScore: 150 }).valid);

console.log('\n15. ReliabilityIncident:');
const validIncident = {
  id: 'inc_01',
  homeId: 'home_01',
  deviceId: 'dev_01',
  incidentType: 'DEVICE_OFFLINE',
  severity: 'HIGH',
  status: 'OPEN',
  title: 'Device went offline',
  signalCount: 3,
  firstObservedAt: '2026-09-03T10:00:00Z',
  lastObservedAt: '2026-09-03T11:00:00Z',
  createdAt: '2026-09-03T10:00:00Z'
};
assert('Valid ReliabilityIncident passes', validator.validate('ReliabilityIncident', validIncident).valid);
assert('Invalid incidentType fails', !validator.validate('ReliabilityIncident', { ...validIncident, incidentType: 'EXPLODED' }).valid);
assert('Invalid severity fails', !validator.validate('ReliabilityIncident', { ...validIncident, severity: 'EXTREME' }).valid);
assert('Invalid status fails', !validator.validate('ReliabilityIncident', { ...validIncident, status: 'DONE' }).valid);

console.log('\n16. RecoveryAttempt:');
const validRecovery = {
  id: 'rec_01',
  incidentId: 'inc_01',
  homeId: 'home_01',
  deviceId: 'dev_01',
  actionType: 'REFRESH_STATE',
  status: 'RECOVERED',
  commandAccepted: true,
  initiatedAt: '2026-09-03T12:00:00Z'
};
assert('Valid RecoveryAttempt passes', validator.validate('RecoveryAttempt', validRecovery).valid);
assert('Invalid actionType fails', !validator.validate('RecoveryAttempt', { ...validRecovery, actionType: 'FACTORY_RESET' }).valid);
assert('Invalid status fails', !validator.validate('RecoveryAttempt', { ...validRecovery, status: 'DONE' }).valid);

console.log('\n17. MaintenanceRecommendation:');
const validMaintenance = {
  id: 'maint_01',
  homeId: 'home_01',
  deviceId: 'dev_01',
  recommendationType: 'NETWORK_CHECK_REQUIRED',
  priority: 'MEDIUM',
  title: 'Check Wi-Fi',
  description: 'Device disconnects frequently',
  status: 'PENDING',
  createdAt: '2026-09-03T08:00:00Z'
};
assert('Valid MaintenanceRecommendation passes', validator.validate('MaintenanceRecommendation', validMaintenance).valid);
assert('Invalid recommendationType fails', !validator.validate('MaintenanceRecommendation', { ...validMaintenance, recommendationType: 'DETONATE' }).valid);
assert('Invalid status fails', !validator.validate('MaintenanceRecommendation', { ...validMaintenance, status: 'IGNORED' }).valid);

console.log('\n18. FleetHealthSummary:');
const validFleet = {
  homeId: 'home_01',
  totalDevices: 5,
  stateDistribution: { HEALTHY: 3, DEGRADED: 1, UNSTABLE: 0, UNAVAILABLE: 1, UNKNOWN: 0 },
  fleetHealthScore: 68.0,
  activeIncidents: 2,
  criticalIncidents: 0,
  pendingRecoveries: 1,
  generatedAt: '2026-09-03T15:00:00Z'
};
assert('Valid FleetHealthSummary passes', validator.validate('FleetHealthSummary', validFleet).valid);
assert('fleetHealthScore > 100 fails', !validator.validate('FleetHealthSummary', { ...validFleet, fleetHealthScore: 150 }).valid);

// ── Phase 26 — Multi-Protocol Connectivity Contract Tests ─────────────────
console.log('\n19. TransportCapability:');
const validCapability = {
  transportType: 'WIFI_MQTT',
  isSupported: true,
  isConfigured: true,
  priorityRank: 1,
  directIp: true,
  meshCapable: false,
  lowPower: false,
  localOnly: false,
  maxPayloadBytes: 65536
};
assert('Valid TransportCapability passes', validator.validate('TransportCapability', validCapability).valid);
assert('Invalid transportType fails', !validator.validate('TransportCapability', { ...validCapability, transportType: 'ZIGBEE' }).valid);

console.log('\n20. TransportHealth:');
const validHealth = {
  transportType: 'MATTER',
  availability: 'ONLINE',
  latencyMs: 42.5,
  errorRate: 0.02,
  reconnectCount: 1,
  lastSuccessfulCommand: '2026-09-03T18:00:00Z',
  lastSuccessfulTelemetry: '2026-09-03T18:05:00Z',
  signalRssi: -58
};
assert('Valid TransportHealth passes', validator.validate('TransportHealth', validHealth).valid);
assert('Invalid availability fails', !validator.validate('TransportHealth', { ...validHealth, availability: 'LOST' }).valid);
assert('errorRate > 1 fails', !validator.validate('TransportHealth', { ...validHealth, errorRate: 1.5 }).valid);

console.log('\n21. DeviceConnectionSnapshot:');
const validConnSnapshot = {
  deviceId: 'dev_01',
  homeId: 'home_01',
  activeTransport: 'WIFI_MQTT',
  connectionState: 'CONNECTED',
  supportedTransports: ['WIFI_MQTT', 'BLE'],
  transportHealth: {
    WIFI_MQTT: validHealth
  },
  lastSelectedReason: 'Primary active transport',
  reconnectCount: 0,
  updatedAt: '2026-09-03T18:10:00Z'
};
assert('Valid DeviceConnectionSnapshot passes', validator.validate('DeviceConnectionSnapshot', validConnSnapshot).valid);
assert('Invalid connectionState fails', !validator.validate('DeviceConnectionSnapshot', { ...validConnSnapshot, connectionState: 'SLEEPING' }).valid);

console.log('\n22. TransportSelection:');
const validSelection = {
  deviceId: 'dev_01',
  selectedTransport: 'WIFI_MQTT',
  reason: 'Lowest latency and highest availability',
  confidence: 0.95,
  fallbackOrder: ['BLE', 'THREAD']
};
assert('Valid TransportSelection passes', validator.validate('TransportSelection', validSelection).valid);
assert('confidence > 1 fails', !validator.validate('TransportSelection', { ...validSelection, confidence: 1.2 }).valid);

console.log('\n23. DeviceDiscoveryResult:');
const validDiscovery = {
  provisionalIdentity: 'matter_disc_01',
  protocol: 'MATTER',
  deviceModel: 'EH-Switch-4G',
  vendorId: '0x1234',
  productId: '0x5678',
  discriminator: 3840,
  isCommissionable: true,
  discoveredAt: '2026-09-03T18:15:00Z'
};
assert('Valid DeviceDiscoveryResult passes', validator.validate('DeviceDiscoveryResult', validDiscovery).valid);
assert('Missing provisionalIdentity fails', !validator.validate('DeviceDiscoveryResult', { ...validDiscovery, provisionalIdentity: undefined }).valid);

console.log('\n24. CommissioningSession & Result:');
const validSession = {
  sessionId: 'comm_sess_01',
  homeId: 'home_01',
  deviceId: 'dev_01',
  transportType: 'BLE',
  stage: 'AUTHENTICATING',
  startedAt: '2026-09-03T18:20:00Z'
};
assert('Valid CommissioningSession passes', validator.validate('CommissioningSession', validSession).valid);
assert('Invalid stage fails', !validator.validate('CommissioningSession', { ...validSession, stage: 'FINISHING' }).valid);

const validCommResult = {
  sessionId: 'comm_sess_01',
  deviceId: 'dev_01',
  homeId: 'home_01',
  transportType: 'BLE',
  success: true,
  assignedNetwork: 'ThreadMesh-1',
  completedAt: '2026-09-03T18:22:00Z'
};
assert('Valid CommissioningResult passes', validator.validate('CommissioningResult', validCommResult).valid);

// 25. ProductFamilyDef:
console.log('\n25. ProductFamilyDef:');
const validFamily = {
  familyId: 'smart_switch',
  slug: 'smart-switch',
  displayName: 'Smart Switches',
  category: 'switches',
  description: 'Modular smart in-wall switchboards',
  icon: 'switch_icon',
  sortOrder: 1
};
assert('Valid ProductFamilyDef passes', validator.validate('ProductFamilyDef', validFamily).valid);
assert('Invalid category fails enum', !validator.validate('ProductFamilyDef', { ...validFamily, category: 'cars' }).valid);

// 26. ProductModelDef:
console.log('\n26. ProductModelDef:');
const validModel = {
  modelId: 'eh-switch-gen1',
  familyId: 'smart_switch',
  marketingName: 'EH In-Wall Smart Switch',
  technicalName: 'EH-SW-GEN1',
  description: 'First generation ESP32-C6 smart switch',
  generation: 1,
  brand: 'EH'
};
assert('Valid ProductModelDef passes', validator.validate('ProductModelDef', validModel).valid);
assert('Missing marketingName fails', !validator.validate('ProductModelDef', { ...validModel, marketingName: undefined }).valid);

// 27. ProductAssetDef:
console.log('\n27. ProductAssetDef:');
const validAsset = {
  hero: 'assets/products/smart_switch_3x/hero.png',
  front: 'assets/products/smart_switch_3x/front.png',
  rear: 'assets/products/smart_switch_3x/rear.png',
  installed: 'assets/products/smart_switch_3x/installed.png',
  packaging: 'assets/products/smart_switch_3x/packaging.png',
  technicalDiagram: 'assets/products/smart_switch_3x/diagram.png',
  icon: 'assets/icons/switch.png',
  thumbnail: 'assets/products/smart_switch_3x/thumb.png'
};
assert('Valid ProductAssetDef passes', validator.validate('ProductAssetDef', validAsset).valid);

// 28. ProductCatalogEntry:
console.log('\n28. ProductCatalogEntry:');
const validCatalogEntry = {
  productId: 'eh-smart-switch',
  productFamilyId: 'smart_switch',
  modelId: 'eh-switch-gen1',
  variantId: 'eh-smart-switch-3x',
  sku: 'EH-SW3X-001',
  marketingName: 'EH Smart Switch 3X',
  technicalName: 'EH-SW-3X-ESP32C6',
  description: 'Triple-relay switchboard with energy metering',
  productStatus: 'ACTIVE',
  visibility: 'PUBLIC',
  category: 'switches',
  subcategory: 'wall_switch',
  channelCount: 3,
  capabilities: ['switch', 'relay', 'energy', 'voltage', 'current', 'power', 'ota'],
  controls: ['relay_ch1', 'relay_ch2', 'relay_ch3'],
  telemetry: ['v_mv', 'i_ma', 'p_mw', 'e_tot_wh'],
  automationCapabilities: ['schedule', 'scene', 'energy_threshold'],
  connectivityCapabilities: ['wifi', 'ble'],
  commissioningCapabilities: ['ble_provisioning', 'wifi_setup'],
  otaCapabilities: {
    supported: true,
    dualPartition: true,
    firmwareFamily: 'esp32c6-switch-platform'
  },
  supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'],
  supportedFirmwareVersions: ['1.0.0', '1.1.0'],
  matterSupport: false,
  threadSupport: false,
  wifiSupport: true,
  bleProvisioningSupport: true,
  energyMonitoringSupport: true,
  localControlSupport: true
};
assert('Valid ProductCatalogEntry passes', validator.validate('ProductCatalogEntry', validCatalogEntry).valid);
assert('Invalid productStatus fails', !validator.validate('ProductCatalogEntry', { ...validCatalogEntry, productStatus: 'UNKNOWN' }).valid);

// 29. ProductDiscoveryResponse:
console.log('\n29. ProductDiscoveryResponse:');
const validDiscoveryResp = {
  products: [validCatalogEntry],
  total: 1,
  page: 1,
  limit: 20,
  totalPages: 1,
  categories: [{ id: 'switches', displayName: 'Switches', count: 1 }],
  families: [{ id: 'smart_switch', displayName: 'Smart Switches', category: 'switches', count: 1 }],
  availableCapabilities: ['switch', 'energy']
};
assert('Valid ProductDiscoveryResponse passes', validator.validate('ProductDiscoveryResponse', validDiscoveryResp).valid);

// 30. ProductSearchResult:
console.log('\n30. ProductSearchResult:');
const validSearch = {
  query: 'Switch 3X',
  results: [
    {
      product: validCatalogEntry,
      matchedFields: ['marketingName', 'sku'],
      relevanceScore: 0.95
    }
  ],
  total: 1
};
assert('Valid ProductSearchResult passes', validator.validate('ProductSearchResult', validSearch).valid);

// 31. ProductCompatibility:
console.log('\n31. ProductCompatibility:');
const validCompatibility = {
  status: 'COMPATIBLE',
  isCompatible: true,
  reasons: [
    {
      code: 'WIFI_BLE_SUPPORTED',
      message: 'Home network has 2.4GHz Wi-Fi and BLE phone commissioning',
      severity: 'INFO',
      remedy: null
    }
  ],
  supportedTransports: ['WIFI_MQTT', 'BLE'],
  recommendedCommissioningTransport: 'BLE',
  unsupportedFeatures: [],
  evaluatedAt: '2026-09-04T12:00:00Z'
};
assert('Valid ProductCompatibility passes', validator.validate('ProductCompatibility', validCompatibility).valid);
assert('Invalid status fails', !validator.validate('ProductCompatibility', { ...validCompatibility, status: 'UNKNOWN' }).valid);

// 32. DeviceAddSession:
console.log('\n32. DeviceAddSession:');
const validAddSession = {
  sessionId: 'das_0194fe23',
  homeId: 'home_01',
  userId: 'user_01',
  entryMode: 'MANUAL_CATALOG',
  stage: 'PRODUCT_SELECTED',
  productVariantId: 'eh-smart-switch-3x',
  deviceId: null,
  commissioningSessionId: null,
  selectedRoomId: 'room_living',
  customDeviceName: 'Living Room Switch',
  channelLabels: { '1': 'Chandelier', '2': 'Fan', '3': 'Accent' },
  compatibilityStatus: 'COMPATIBLE',
  errorMessage: null,
  createdAt: '2026-09-04T12:05:00Z',
  updatedAt: '2026-09-04T12:05:00Z',
  completedAt: null
};
assert('Valid DeviceAddSession passes', validator.validate('DeviceAddSession', validAddSession).valid);
assert('Invalid stage fails', !validator.validate('DeviceAddSession', { ...validAddSession, stage: 'DONE_NOW' }).valid);

// 33. Phase 28 — Edge & Local-First Execution Contracts:
console.log('\n33. Phase 28 — LocalExecutionRequest:');
const validLocalExecReq = {
  commandId: 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
  deviceId: 'eh-switch-001',
  homeId: 'home_main',
  channelIndex: 1,
  action: 'setPower',
  params: { value: true },
  idempotencyKey: 'idem_key_12345678',
  preferredRoute: 'AUTO',
  maxTimeoutMs: 2500,
  expiresAt: '2026-09-04T18:00:00Z',
  actor: { userId: 'usr_01', role: 'OWNER', source: 'APP_LOCAL' },
  createdAt: '2026-09-04T14:00:00Z'
};
assert('Valid LocalExecutionRequest passes', validator.validate('LocalExecutionRequest', validLocalExecReq).valid);
assert('Invalid action fails', !validator.validate('LocalExecutionRequest', { ...validLocalExecReq, action: 'invalidAction' }).valid);

console.log('\n34. Phase 28 — ExecutionRouteDecision:');
const validRouteDecision = {
  decisionId: 'dec_01928374',
  deviceId: 'eh-switch-001',
  homeId: 'home_main',
  routeMode: 'LOCAL',
  selectedTransport: 'WIFI_MQTT',
  localEndpoint: '192.168.1.145:1883',
  confidenceScore: 0.95,
  fallbackOrder: ['BLE', 'CLOUD'],
  isCloudAvailable: true,
  isLocalAvailable: true,
  decisionRationale: 'Device reachable on local LAN with active session',
  decidedAt: '2026-09-04T14:00:01Z'
};
assert('Valid ExecutionRouteDecision passes', validator.validate('ExecutionRouteDecision', validRouteDecision).valid);
assert('Invalid routeMode fails', !validator.validate('ExecutionRouteDecision', { ...validRouteDecision, routeMode: 'TELEPATHY' }).valid);

console.log('\n35. Phase 28 — LocalConnectivityState:');
const validLocalConnState = {
  deviceId: 'eh-switch-001',
  homeId: 'home_main',
  isReachableLocally: true,
  transportType: 'WIFI_MQTT',
  localIp: '192.168.1.145',
  localPort: 1883,
  macAddress: 'AA:BB:CC:DD:EE:FF',
  rssiDbm: -58,
  latencyEstimateMs: 12.5,
  authFingerprint: 'sha256:abcd1234ef',
  isTlsSecured: true,
  lastSeenAt: '2026-09-04T14:00:00Z'
};
assert('Valid LocalConnectivityState passes', validator.validate('LocalConnectivityState', validLocalConnState).valid);

console.log('\n36. Phase 28 — LocalDeviceDiscovery:');
const validLocalDiscovery = {
  discoveryId: 'disc_98765',
  deviceId: 'eh-switch-001',
  homeId: 'home_main',
  productVariantId: 'eh-smart-switch-3x',
  macAddress: 'AA:BB:CC:DD:EE:FF',
  ipAddress: '192.168.1.145',
  port: 1883,
  transportType: 'WIFI_MQTT',
  protocolVersion: '1.2.0',
  firmwareVersion: '2.1.0',
  identityFingerprint: 'cert_fingerprint_hash',
  isTrusted: true,
  ttlSeconds: 300,
  discoveredAt: '2026-09-04T14:00:00Z'
};
assert('Valid LocalDeviceDiscovery passes', validator.validate('LocalDeviceDiscovery', validLocalDiscovery).valid);

console.log('\n37. Phase 28 — LocalExecutionResult:');
const validExecResult = {
  commandId: 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
  deviceId: 'eh-switch-001',
  channelIndex: 1,
  action: 'setPower',
  status: 'CONFIRMED',
  routeUsed: 'LOCAL',
  transportUsed: 'WIFI_MQTT',
  isConfirmedByDevice: true,
  confirmedState: { power: true },
  latencyMs: 18.4,
  errorMessage: null,
  isIdempotentReplay: false,
  queuedForCloudSync: true,
  executedAt: '2026-09-04T14:00:02Z'
};
assert('Valid LocalExecutionResult passes', validator.validate('LocalExecutionResult', validExecResult).valid);
assert('Invalid status fails', !validator.validate('LocalExecutionResult', { ...validExecResult, status: 'ASSUMED' }).valid);

console.log('\n38. Phase 28 — LocalStateEvent:');
const validLocalStateEvent = {
  eventId: 'evt_local_019',
  deviceId: 'eh-switch-001',
  homeId: 'home_main',
  channelIndex: 1,
  eventType: 'RELAY_STATE_CHANGED',
  payload: { state: 'ON', physicalSwitch: false },
  source: 'LOCAL_LAN',
  timestamp: '2026-09-04T14:00:02Z'
};
assert('Valid LocalStateEvent passes', validator.validate('LocalStateEvent', validLocalStateEvent).valid);

console.log('\n39. Phase 28 — EdgeAutomationExecution:');
const validEdgeAuto = {
  executionId: 'exec_edge_9988',
  homeId: 'home_main',
  ruleType: 'AUTOMATION',
  ruleId: 'rule_motion_lights',
  ruleName: 'Motion turns on Living Room Lights',
  triggerSource: 'sensor_pir_01',
  status: 'SUCCESS',
  actionsTotal: 2,
  actionsSuccessful: 2,
  actionsFailed: 0,
  actionResults: [{ deviceId: 'eh-switch-001', status: 'CONFIRMED' }],
  executionDurationMs: 45.2,
  executedAt: '2026-09-04T14:00:03Z'
};
assert('Valid EdgeAutomationExecution passes', validator.validate('EdgeAutomationExecution', validEdgeAuto).valid);
assert('Invalid status fails', !validator.validate('EdgeAutomationExecution', { ...validEdgeAuto, status: 'MAGIC' }).valid);

// 40. Phase 29 — Matter Ecosystem Interoperability Contracts
console.log('\n40. Phase 29 — MatterDevice:');
const validMatterDevice = {
  schemaVersion: 1,
  matterDeviceId: 'mat_dev_001',
  deviceId: '22222222-2222-4222-8222-222222222221',
  homeId: 'home_main',
  nodeId: '0x0000000000000001',
  vendorId: 65521,
  productId: 32768,
  matterDeviceType: 'ON_OFF_LIGHT',
  commissioningState: 'COMMISSIONED',
  subscriptionState: 'ACTIVE',
  softwareVersion: 1,
  softwareVersionString: '1.0.0',
  hardwareVersion: 1,
  hardwareVersionString: 'revA',
  discriminator: 3840,
  setupPasscode: 20202021,
  lastSynchronizedAt: '2026-09-04T15:00:00Z',
  createdAt: '2026-09-04T15:00:00Z',
  updatedAt: '2026-09-04T15:00:00Z'
};
assert('Valid MatterDevice passes', validator.validate('MatterDevice', validMatterDevice).valid);
assert('Invalid matterDeviceType fails', !validator.validate('MatterDevice', { ...validMatterDevice, matterDeviceType: 'INVALID_DEVICE' }).valid);
assert('Non-UUID deviceId fails', !validator.validate('MatterDevice', { ...validMatterDevice, deviceId: 'not-a-uuid' }).valid);

console.log('\n41. Phase 29 — MatterFabric:');
const validMatterFabric = {
  schemaVersion: 1,
  fabricId: '0x0000000000000001',
  matterDeviceId: 'mat_dev_001',
  fabricIndex: 1,
  fabricName: 'APPLE_HOME',
  vendorId: 4937,
  controllerNodeId: '0x0000000000000002',
  commissioningState: 'CONNECTED',
  label: 'Living Room Apple Home',
  pairedAt: '2026-09-04T15:00:00Z',
  lastSynchronizedAt: '2026-09-04T15:00:00Z',
  createdAt: '2026-09-04T15:00:00Z',
  updatedAt: '2026-09-04T15:00:00Z'
};
assert('Valid MatterFabric passes', validator.validate('MatterFabric', validMatterFabric).valid);
assert('Invalid fabricName fails', !validator.validate('MatterFabric', { ...validMatterFabric, fabricName: 'UNKNOWN_ECOSYSTEM' }).valid);

console.log('\n42. Phase 29 — MatterEndpoint:');
const validMatterEndpoint = {
  schemaVersion: 1,
  endpointId: 'mat_ep_001_1',
  matterDeviceId: 'mat_dev_001',
  endpointNumber: 1,
  deviceType: 'ON_OFF_LIGHT',
  channelIndex: 1,
  serverClusters: [
    {
      clusterId: 6,
      clusterName: 'On/Off',
      supportedAttributes: ['OnOff', 'GlobalSceneControl'],
      supportedCommands: ['Off', 'On', 'Toggle']
    }
  ]
};
assert('Valid MatterEndpoint passes', validator.validate('MatterEndpoint', validMatterEndpoint).valid);

console.log('\n43. Phase 29 — MatterCommissioningSession:');
const validCommissioningSession = {
  schemaVersion: 1,
  sessionId: 'mat_comm_sess_001',
  deviceId: '22222222-2222-4222-8222-222222222221',
  homeId: 'home_main',
  stage: 'ADVERTISING',
  targetFabric: 'GOOGLE_HOME',
  discriminator: 3840,
  setupPasscode: 20202021,
  qrCodePayload: 'MT:Y.K9042C00KA0648G00',
  manualPairingCode: '34970112332',
  errorMessage: null,
  expiresAt: '2026-09-04T15:15:00Z',
  createdAt: '2026-09-04T15:00:00Z',
  completedAt: null
};
assert('Valid MatterCommissioningSession passes', validator.validate('MatterCommissioningSession', validCommissioningSession).valid);
assert('Invalid stage fails', !validator.validate('MatterCommissioningSession', { ...validCommissioningSession, stage: 'UNSUPPORTED_STAGE' }).valid);

console.log('\n44. Phase 29 — MatterSyncEvent:');
const validMatterSyncEvent = {
  schemaVersion: 1,
  eventId: 'mat_evt_001',
  deviceId: '22222222-2222-4222-8222-222222222221',
  homeId: 'home_main',
  fabricId: '0x0000000000000001',
  endpointNumber: 1,
  clusterId: 6,
  attributeName: 'OnOff',
  attributeValue: true,
  direction: 'INBOUND_FROM_MATTER',
  stateVersion: 5,
  isPhysicalConfirmed: true,
  timestamp: '2026-09-04T15:00:01Z'
};
assert('Valid MatterSyncEvent passes', validator.validate('MatterSyncEvent', validMatterSyncEvent).valid);
assert('Invalid direction fails', !validator.validate('MatterSyncEvent', { ...validMatterSyncEvent, direction: 'SIDEWAYS' }).valid);

console.log('\n45. Phase 29 — ExternalPlatformLink:');
const validPlatformLink = {
  schemaVersion: 1,
  linkId: 'link_apple_home_001',
  homeId: 'home_main',
  deviceId: '22222222-2222-4222-8222-222222222221',
  platform: 'APPLE_HOME',
  status: 'CONNECTED',
  externalIdentifier: 'apple_accessory_123',
  displayName: 'Apple Home Living Room',
  syncStatus: 'SYNCHRONIZED',
  lastErrorMessage: null,
  linkedAt: '2026-09-04T15:00:00Z',
  lastSyncedAt: '2026-09-04T15:00:02Z',
  createdAt: '2026-09-04T15:00:00Z',
  updatedAt: '2026-09-04T15:00:02Z'
};
assert('Valid ExternalPlatformLink passes', validator.validate('ExternalPlatformLink', validPlatformLink).valid);
assert('Invalid platform fails', !validator.validate('ExternalPlatformLink', { ...validPlatformLink, platform: 'SMARTTHINGS' }).valid);

console.log('\n46. Phase 29 — InteroperabilityCapabilityMapping:');
const validCapMapping = {
  schemaVersion: 1,
  ehCapability: 'switch',
  productVariantId: 'eh-smart-switch-2x',
  isSupportedByHardware: true,
  matterClusterId: 6,
  matterClusterName: 'On/Off',
  matterDeviceType: 'ON_OFF_LIGHT',
  supportedMatterAttributes: ['OnOff'],
  supportedMatterCommands: ['Off', 'On', 'Toggle'],
  hardwareMeteringVerified: false,
  notes: 'Direct physical relay actuation'
};
assert('Valid InteroperabilityCapabilityMapping passes', validator.validate('InteroperabilityCapabilityMapping', validCapMapping).valid);

console.log('\n47. Phase 30 — PlatformEvent:');
const validPlatformEvent = {
  schemaVersion: 1,
  eventId: 'evt_dev_offline_001',
  eventType: 'DEVICE_OFFLINE',
  source: 'device',
  homeId: 'home_main',
  deviceId: '22222222-2222-4222-8222-222222222221',
  userId: null,
  severity: 'WARNING',
  title: 'Living Room Switch is offline',
  message: 'Living Room Switch lost connection.',
  data: { reason: 'PING_TIMEOUT', lastSeenAt: '2026-09-04T15:00:00Z' },
  occurredAt: '2026-09-04T15:00:00Z'
};
assert('Valid PlatformEvent passes', validator.validate('PlatformEvent', validPlatformEvent).valid);
assert('Invalid severity fails', !validator.validate('PlatformEvent', { ...validPlatformEvent, severity: 'FATAL' }).valid);
assert('Invalid source fails', !validator.validate('PlatformEvent', { ...validPlatformEvent, source: 'satellite' }).valid);

console.log('\n48. Phase 30 — UserNotification:');
const validUserNotification = {
  schemaVersion: 1,
  id: 'notif_001',
  userId: 'usr_alice',
  homeId: 'home_main',
  type: 'DEVICE_OFFLINE',
  category: 'alert',
  priority: 'HIGH',
  severity: 'WARNING',
  title: 'Living Room Switch is offline',
  body: 'Device lost connection or powered down.',
  entityType: 'device',
  entityId: '22222222-2222-4222-8222-222222222221',
  data: { deviceName: 'Living Room Switch' },
  readAt: null,
  deliveryStatus: 'DELIVERED',
  actionType: 'VIEW_DEVICE',
  actionTarget: '22222222-2222-4222-8222-222222222221',
  actionState: 'NONE',
  isAggregated: false,
  aggregatedCount: 1,
  aggregatedIds: [],
  idempotencyKey: 'dedup_home_main_dev_offline_001',
  createdAt: '2026-09-04T15:00:00Z'
};
assert('Valid UserNotification passes', validator.validate('UserNotification', validUserNotification).valid);
assert('Invalid deliveryStatus fails', !validator.validate('UserNotification', { ...validUserNotification, deliveryStatus: 'UNKNOWN' }).valid);

console.log('\n49. Phase 30 — NotificationPreference:');
const validNotificationPreference = {
  schemaVersion: 1,
  userId: 'usr_alice',
  pushEnabled: true,
  emailEnabled: true,
  inAppEnabled: true,
  criticalAlerts: true,
  deviceOffline: true,
  deviceHealth: true,
  automationFailure: true,
  firmwareUpdates: true,
  energyAlerts: true,
  securityAlerts: true,
  matterAlerts: true,
  memberAlerts: true,
  quietHoursEnabled: true,
  quietHoursStart: '22:00',
  quietHoursEnd: '07:00',
  updatedAt: '2026-09-04T15:00:00Z'
};
assert('Valid NotificationPreference passes', validator.validate('NotificationPreference', validNotificationPreference).valid);
assert('Invalid quietHours time format fails', !validator.validate('NotificationPreference', { ...validNotificationPreference, quietHoursStart: '25:00' }).valid);

console.log('\n50. Phase 30 — NotificationDelivery:');
const validNotificationDelivery = {
  schemaVersion: 1,
  deliveryId: 'del_001',
  notificationId: 'notif_001',
  channel: 'push',
  status: 'SENT',
  attempts: 1,
  lastError: null,
  createdAt: '2026-09-04T15:00:00Z',
  updatedAt: '2026-09-04T15:00:01Z'
};
assert('Valid NotificationDelivery passes', validator.validate('NotificationDelivery', validNotificationDelivery).valid);
assert('Invalid channel fails', !validator.validate('NotificationDelivery', { ...validNotificationDelivery, channel: 'fax' }).valid);

console.log('\n51. Phase 30 — NotificationAction:');
const validNotificationAction = {
  schemaVersion: 1,
  actionId: 'act_001',
  notificationId: 'notif_001',
  userId: 'usr_alice',
  actionType: 'VIEW_DEVICE',
  actionTarget: '22222222-2222-4222-8222-222222222221',
  actionState: 'ACTIONED',
  payload: { openedScreen: 'DeviceDetailPage' },
  executedAt: '2026-09-04T15:05:00Z'
};
assert('Valid NotificationAction passes', validator.validate('NotificationAction', validNotificationAction).valid);
assert('Invalid actionType fails', !validator.validate('NotificationAction', { ...validNotificationAction, actionType: 'EXPLODE' }).valid);

console.log('\n52. Phase 30 — NotificationAggregation:');
const validNotificationAggregation = {
  schemaVersion: 1,
  aggregationId: 'agg_001',
  aggregationKey: 'home_main:offline_cluster',
  homeId: 'home_main',
  roomId: 'room_living',
  eventType: 'DEVICE_OFFLINE',
  severity: 'WARNING',
  eventCount: 3,
  aggregatedIds: ['notif_001', 'notif_002', 'notif_003'],
  summaryTitle: '3 devices in Living Room are offline',
  summaryBody: 'Living Room Switch, Accent Light, and Ceiling Fan went offline.',
  windowSeconds: 60,
  createdAt: '2026-09-04T15:00:00Z',
  updatedAt: '2026-09-04T15:01:00Z'
};
assert('Valid NotificationAggregation passes', validator.validate('NotificationAggregation', validNotificationAggregation).valid);
assert('Invalid eventCount fails', !validator.validate('NotificationAggregation', { ...validNotificationAggregation, eventCount: 0 }).valid);

console.log('\n53. Phase 31 — OperationalEvent:');
const validOperationalEvent = {
  schemaVersion: 1,
  eventId: 'opevt_001',
  correlationId: 'corr_001',
  causationId: 'caus_001',
  homeId: 'home_01',
  deviceId: '22222222-2222-4222-8222-222222222221',
  subsystem: 'DEVICE',
  operation: 'EXECUTE_COMMAND',
  action: 'LIGHT_ON',
  source: 'USER_APP',
  executionPath: 'LOCAL_EDGE',
  severity: 'INFO',
  authorizationResult: 'AUTHORIZED',
  outcome: 'SUCCESS',
  durationMs: 42,
  timestamp: '2026-09-04T16:00:00Z'
};
assert('Valid OperationalEvent passes', validator.validate('OperationalEvent', validOperationalEvent).valid);
assert('Invalid subsystem in OperationalEvent fails', !validator.validate('OperationalEvent', { ...validOperationalEvent, subsystem: 'UNKNOWN_SUB' }).valid);
assert('Invalid executionPath in OperationalEvent fails', !validator.validate('OperationalEvent', { ...validOperationalEvent, executionPath: 'SATELLITE' }).valid);

console.log('\n54. Phase 31 — AuditRecord:');
const validAuditRecord = {
  schemaVersion: 1,
  auditId: 'sec_rec_001',
  sequenceNumber: 1,
  recordHash: 'a'.repeat(64),
  prevRecordHash: '0'.repeat(64),
  actorUserId: 'usr_alice',
  homeId: 'home_01',
  action: 'ROLE_ELEVATION',
  resourceType: 'MEMBER',
  resourceId: 'usr_bob',
  outcome: 'SUCCESS',
  canonicalPayload: { targetRole: 'ADMIN' },
  timestamp: '2026-09-04T16:00:00Z'
};
assert('Valid AuditRecord passes', validator.validate('AuditRecord', validAuditRecord).valid);
assert('Invalid hash length in AuditRecord fails', !validator.validate('AuditRecord', { ...validAuditRecord, recordHash: 'short' }).valid);
assert('Negative sequenceNumber fails', !validator.validate('AuditRecord', { ...validAuditRecord, sequenceNumber: -1 }).valid);

console.log('\n55. Phase 31 — OperationTrace:');
const validOperationTrace = {
  schemaVersion: 1,
  traceId: 'trace_001',
  correlationId: 'corr_001',
  rootOperation: 'EXECUTE_COMMAND',
  status: 'COMPLETED',
  startTime: '2026-09-04T16:00:00.000Z',
  endTime: '2026-09-04T16:00:00.085Z',
  totalDurationMs: 85,
  spans: [
    {
      spanId: 'span_001',
      parentSpanId: null,
      subsystem: 'COMMAND',
      operation: 'PARSE_COMMAND',
      executionPath: 'LOCAL_EDGE',
      outcome: 'SUCCESS',
      durationMs: 15,
      timestamp: '2026-09-04T16:00:00.000Z'
    },
    {
      spanId: 'span_002',
      parentSpanId: 'span_001',
      subsystem: 'EDGE_ROUTING',
      operation: 'DISPATCH_LOCAL',
      executionPath: 'LOCAL_EDGE',
      outcome: 'SUCCESS',
      durationMs: 70,
      timestamp: '2026-09-04T16:00:00.015Z'
    }
  ]
};
assert('Valid OperationTrace passes', validator.validate('OperationTrace', validOperationTrace).valid);
assert('Invalid status in OperationTrace fails', !validator.validate('OperationTrace', { ...validOperationTrace, status: 'EXPLODED' }).valid);

console.log('\n56. Phase 31 — SystemHealth:');
const validSystemHealth = {
  schemaVersion: 1,
  status: 'HEALTHY',
  timestamp: '2026-09-04T16:00:00Z',
  subsystems: {
    DATABASE: {
      status: 'HEALTHY',
      latencyMs: 8,
      lastCheckedAt: '2026-09-04T16:00:00Z'
    },
    MQTT: {
      status: 'HEALTHY',
      latencyMs: 12,
      lastCheckedAt: '2026-09-04T16:00:00Z'
    }
  }
};
assert('Valid SystemHealth passes', validator.validate('SystemHealth', validSystemHealth).valid);
assert('Invalid status in SystemHealth fails', !validator.validate('SystemHealth', { ...validSystemHealth, status: 'AWESOME' }).valid);

console.log(`\n========================================`);
console.log(`Total Passed: ${passed}, Total Failed: ${failed}`);
console.log(`========================================\n`);

process.exit(failed > 0 ? 1 : 0);

