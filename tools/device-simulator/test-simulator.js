const { DeviceSimulator } = require('./simulator');
const { SchemaValidator } = require('../../packages/contracts/validator');
const path = require('path');

const validator = new SchemaValidator();

// Load canonical schemas for validation
[
  '../../packages/contracts/identity/device-identity.schema.json',
  '../../packages/contracts/state/channel-state.schema.json',
  '../../packages/contracts/state/device-state.schema.json',
  '../../packages/contracts/command/command.schema.json',
  '../../packages/contracts/command/command-receipt.schema.json',
  '../../packages/contracts/events/device-event.schema.json',
  '../../packages/contracts/energy/energy-telemetry.schema.json'
].forEach(f => validator.loadSchema(path.join(__dirname, f)));

console.log('=== TESTING DEVICE SIMULATOR CONTRACT COMPLIANCE ===\n');

const sim = new DeviceSimulator();

// 1. Identity
const ident = sim.getIdentity();
console.log('1. Device Identity:');
const identRes = validator.validate('DeviceIdentity', ident);
if (!identRes.valid) {
  console.error('FAIL: Identity invalid:', identRes.errors);
  process.exit(1);
}
console.log('  [PASS] Simulator DeviceIdentity conforms to canonical schema');

// 2. Initial State
console.log('\n2. Device State:');
const state = sim.getState();
const stateRes = validator.validate('DeviceState', state);
if (!stateRes.valid) {
  console.error('FAIL: State invalid:', stateRes.errors);
  process.exit(1);
}
console.log('  [PASS] Simulator DeviceState conforms to canonical schema (Channels: 3, Power: OFF)');

// 3. Physical Toggle Event
console.log('\n3. Physical Switch Event:');
const evt = sim.handlePhysicalToggle(1);
const evtRes = validator.validate('DeviceEvent', evt);
if (!evtRes.valid) {
  console.error('FAIL: Event invalid:', evtRes.errors);
  process.exit(1);
}
console.log(`  [PASS] Physical toggle emitted valid DeviceEvent (Channel 1 -> ${evt.payload.power ? 'ON' : 'OFF'})`);

// 4. Command Handling
console.log('\n4. Command Handling & Receipt:');
const cmd = {
  schemaVersion: 1,
  commandId: "0194fe23-7a1b-7890-a123-456789777777",
  deviceId: ident.deviceId,
  channelIndex: 2,
  action: "setPower",
  params: { value: true },
  idempotencyKey: "idem_test_cmd_001",
  source: "APP",
  timestamp: new Date().toISOString(),
  expiresAt: new Date(Date.now() + 15000).toISOString()
};
const receipt = sim.handleCommand(cmd);
const receiptRes = validator.validate('CommandReceipt', receipt);
if (!receiptRes.valid) {
  console.error('FAIL: Receipt invalid:', receiptRes.errors);
  process.exit(1);
}
console.log(`  [PASS] Simulator command processed -> valid CommandReceipt (Status: ${receipt.status})`);

// 5. Fixed-Point Energy Telemetry
console.log('\n5. Fixed-Point Energy Telemetry:');
const telemetry = sim.generateTelemetry(1);
const telRes = validator.validate('EnergyTelemetry', telemetry);
if (!telRes.valid) {
  console.error('FAIL: Telemetry invalid:', telRes.errors);
  process.exit(1);
}
console.log(`  [PASS] Telemetry generated -> Voltage: ${telemetry.v_mv / 1000}V, Power: ${telemetry.p_mw / 1000}W, EnergyTotal: ${telemetry.e_tot_wh}Wh`);

console.log('\n========================================');
console.log('ALL SIMULATOR CONTRACT TESTS PASSED!');
console.log('========================================\n');
