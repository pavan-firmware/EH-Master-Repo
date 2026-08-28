/**
 * EH Home — Firmware Host Unit & Protocol Test Suite (Phase 8)
 *
 * Tests C firmware module logic, state machines, debounce algorithms,
 * BL0942 energy telemetry frame parsing, and OTA anti-rollback checks.
 */

const assert = require('assert');

console.log('\n================================================================');
console.log('       EH HOME — PHASE 8 FIRMWARE HOST TEST SUITE               ');
console.log('================================================================\n');

let passCount = 0;
function test(name, fn) {
  try {
    fn();
    console.log(`  [PASS] ${name}`);
    passCount++;
  } catch (err) {
    console.error(`  [FAIL] ${name}:`, err.message);
    process.exit(1);
  }
}

// ---------------------------------------------------------------------------
// 1. Lifecycle State Machine Logic Simulation
// ---------------------------------------------------------------------------
const APP_STATES = {
  FACTORY_NEW: 'FACTORY_NEW',
  BLE_COMMISSIONING: 'BLE_COMMISSIONING',
  WIFI_CONNECTING: 'WIFI_CONNECTING',
  MQTT_CONNECTING: 'MQTT_CONNECTING',
  ACTIVE: 'ACTIVE',
  ERROR_RECOVERY: 'ERROR_RECOVERY'
};

class LifecycleSimulator {
  constructor() {
    this.state = APP_STATES.FACTORY_NEW;
    this.commissioned = false;
  }
  canTransitionTo(newState) {
    switch (this.state) {
      case APP_STATES.FACTORY_NEW:
        return newState === APP_STATES.BLE_COMMISSIONING || newState === APP_STATES.WIFI_CONNECTING;
      case APP_STATES.BLE_COMMISSIONING:
        return newState === APP_STATES.WIFI_CONNECTING || newState === APP_STATES.ERROR_RECOVERY || newState === APP_STATES.FACTORY_NEW;
      case APP_STATES.WIFI_CONNECTING:
        return newState === APP_STATES.MQTT_CONNECTING || newState === APP_STATES.ERROR_RECOVERY || newState === APP_STATES.BLE_COMMISSIONING;
      case APP_STATES.MQTT_CONNECTING:
        return newState === APP_STATES.ACTIVE || newState === APP_STATES.ERROR_RECOVERY || newState === APP_STATES.WIFI_CONNECTING;
      case APP_STATES.ACTIVE:
        return newState === APP_STATES.ERROR_RECOVERY || newState === APP_STATES.WIFI_CONNECTING || newState === APP_STATES.FACTORY_NEW;
      case APP_STATES.ERROR_RECOVERY:
        return newState === APP_STATES.WIFI_CONNECTING || newState === APP_STATES.BLE_COMMISSIONING || newState === APP_STATES.FACTORY_NEW;
      default:
        return false;
    }
  }
  transition(newState) {
    if (!this.canTransitionTo(newState)) return false;
    this.state = newState;
    return true;
  }
  isSecretAccessible() {
    return (!this.commissioned) && (this.state === APP_STATES.FACTORY_NEW || this.state === APP_STATES.BLE_COMMISSIONING);
  }
  markCommissioned() {
    this.commissioned = true;
  }
}

test('1. Lifecycle: Valid factory provisioning progression', () => {
  const lc = new LifecycleSimulator();
  assert.strictEqual(lc.state, APP_STATES.FACTORY_NEW);
  assert.strictEqual(lc.isSecretAccessible(), true);

  assert.strictEqual(lc.transition(APP_STATES.BLE_COMMISSIONING), true);
  assert.strictEqual(lc.isSecretAccessible(), true);

  assert.strictEqual(lc.transition(APP_STATES.WIFI_CONNECTING), true);
  assert.strictEqual(lc.transition(APP_STATES.MQTT_CONNECTING), true);
  assert.strictEqual(lc.transition(APP_STATES.ACTIVE), true);

  lc.markCommissioned();
  assert.strictEqual(lc.isSecretAccessible(), false);
});

test('2. Lifecycle: Invalid transitions rejected', () => {
  const lc = new LifecycleSimulator();
  assert.strictEqual(lc.transition(APP_STATES.ACTIVE), false); // Cannot jump FACTORY_NEW -> ACTIVE
  assert.strictEqual(lc.transition(APP_STATES.MQTT_CONNECTING), false);
});

test('3. Lifecycle: Secret lock on active commissioning', () => {
  const lc = new LifecycleSimulator();
  lc.transition(APP_STATES.BLE_COMMISSIONING);
  lc.transition(APP_STATES.WIFI_CONNECTING);
  lc.transition(APP_STATES.MQTT_CONNECTING);
  lc.transition(APP_STATES.ACTIVE);
  lc.markCommissioned();

  // Re-entering error recovery must NOT expose secret
  lc.transition(APP_STATES.ERROR_RECOVERY);
  assert.strictEqual(lc.isSecretAccessible(), false);
});

// ---------------------------------------------------------------------------
// 2. Physical Switch 50ms Debounce Logic Simulation
// ---------------------------------------------------------------------------
class DebounceSimulator {
  constructor(debounceMs = 50) {
    this.debounceMs = debounceMs;
    this.lastTriggerMs = {};
  }
  feed(ch, timestampMs) {
    const last = this.lastTriggerMs[ch] || 0;
    if (timestampMs - last >= this.debounceMs || last === 0) {
      this.lastTriggerMs[ch] = timestampMs;
      return true;
    }
    return false;
  }
}

test('4. Debounce: Suppresses rapid chatter within 50ms window', () => {
  const deb = new DebounceSimulator(50);
  assert.strictEqual(deb.feed(1, 100), true);  // Initial press accepted
  assert.strictEqual(deb.feed(1, 110), false); // Contact bounce @ +10ms rejected
  assert.strictEqual(deb.feed(1, 125), false); // Contact bounce @ +25ms rejected
  assert.strictEqual(deb.feed(1, 149), false); // Contact bounce @ +49ms rejected
  assert.strictEqual(deb.feed(1, 155), true);  // Valid secondary toggle @ +55ms accepted
});

test('5. Debounce: Independent per-channel tracking', () => {
  const deb = new DebounceSimulator(50);
  assert.strictEqual(deb.feed(1, 100), true);
  assert.strictEqual(deb.feed(2, 105), true); // Channel 2 independent of Channel 1
  assert.strictEqual(deb.feed(3, 110), true); // Channel 3 independent
  assert.strictEqual(deb.feed(1, 115), false); // Channel 1 still in debounce window
});

// ---------------------------------------------------------------------------
// 3. Relay Logic & Physical Switch Override
// ---------------------------------------------------------------------------
class RelaySimulator {
  constructor(channelCount = 3) {
    this.states = new Array(channelCount).fill(false);
  }
  set(ch, power) {
    if (ch < 1 || ch > this.states.length) return false;
    this.states[ch - 1] = power;
    return true;
  }
  toggle(ch) {
    if (ch < 1 || ch > this.states.length) return false;
    this.states[ch - 1] = !this.states[ch - 1];
    return this.states[ch - 1];
  }
  get(ch) {
    return this.states[ch - 1];
  }
}

test('6. Relay: Safe boot state is strictly OFF', () => {
  const r = new RelaySimulator(3);
  assert.strictEqual(r.get(1), false);
  assert.strictEqual(r.get(2), false);
  assert.strictEqual(r.get(3), false);
});

test('7. Relay: Physical switch toggle overrides app state immediately', () => {
  const r = new RelaySimulator(3);
  r.set(1, true); // Turned ON by app
  assert.strictEqual(r.get(1), true);

  r.toggle(1);    // Physical switch flipped
  assert.strictEqual(r.get(1), false); // Immediately OFF
});

// ---------------------------------------------------------------------------
// 4. BL0942 Energy Telemetry Frame Parsing & Checksum Verification
// ---------------------------------------------------------------------------
function parseBl0942Frame(buffer) {
  if (!buffer || buffer.length < 23) return null;
  if (buffer[0] !== 0x55) return null;

  let sum = 0;
  for (let i = 0; i < 22; i++) {
    sum = (sum + buffer[i]) & 0xFF;
  }
  const expectedChecksum = (~sum) & 0xFF;
  if (buffer[22] !== expectedChecksum) {
    return null; // Checksum failure
  }

  // 24-bit little endian extractions
  const i_raw = buffer[1] | (buffer[2] << 8) | (buffer[3] << 16);
  const v_raw = buffer[4] | (buffer[5] << 8) | (buffer[6] << 16);
  let p_raw = buffer[10] | (buffer[11] << 8) | (buffer[12] << 16);
  if (p_raw & 0x800000) p_raw |= 0xFF000000;
  const e_raw = buffer[13] | (buffer[14] << 8) | (buffer[15] << 16);

  const V_REF_SCALE = 7398.9;
  const I_REF_SCALE = 30597.8;
  const W_REF_SCALE = 353.7;
  const E_PULSE_SCALE = 163.84;

  return {
    voltage_mv: Math.round((v_raw / V_REF_SCALE) * 1000),
    current_ma: Math.round((i_raw / I_REF_SCALE) * 1000),
    power_mw: Math.round((p_raw / W_REF_SCALE) * 1000),
    energy_tot_wh: Math.round((e_raw / E_PULSE_SCALE) * 1000),
    valid: true
  };
}

function buildSyntheticBl0942Frame(vVolts, iAmps, pWatts, eKwh) {
  const buf = Buffer.alloc(23);
  buf[0] = 0x55;

  const V_REF_SCALE = 7398.9;
  const I_REF_SCALE = 30597.8;
  const W_REF_SCALE = 353.7;
  const E_PULSE_SCALE = 163.84;

  const i_raw = Math.round(iAmps * I_REF_SCALE);
  const v_raw = Math.round(vVolts * V_REF_SCALE);
  const p_raw = Math.round(pWatts * W_REF_SCALE);
  const e_raw = Math.round(eKwh * E_PULSE_SCALE);

  buf[1] = i_raw & 0xFF;
  buf[2] = (i_raw >> 8) & 0xFF;
  buf[3] = (i_raw >> 16) & 0xFF;

  buf[4] = v_raw & 0xFF;
  buf[5] = (v_raw >> 8) & 0xFF;
  buf[6] = (v_raw >> 16) & 0xFF;

  buf[10] = p_raw & 0xFF;
  buf[11] = (p_raw >> 8) & 0xFF;
  buf[12] = (p_raw >> 16) & 0xFF;

  buf[13] = e_raw & 0xFF;
  buf[14] = (e_raw >> 8) & 0xFF;
  buf[15] = (e_raw >> 16) & 0xFF;

  // Compute checksum
  let sum = 0;
  for (let i = 0; i < 22; i++) {
    sum = (sum + buf[i]) & 0xFF;
  }
  buf[22] = (~sum) & 0xFF;
  return buf;
}

test('8. BL0942: Frame parsing converts raw 24-bit registers to fixed-point V/I/P/E', () => {
  const frame = buildSyntheticBl0942Frame(230.0, 1.5, 345.0, 12.5);
  const data = parseBl0942Frame(frame);

  assert.notStrictEqual(data, null);
  assert.ok(Math.abs(data.voltage_mv - 230000) <= 5);
  assert.ok(Math.abs(data.current_ma - 1500) <= 5);
  assert.ok(Math.abs(data.power_mw - 345000) <= 5);
  assert.ok(Math.abs(data.energy_tot_wh - 12500) <= 5);
});

test('9. BL0942: Corrupted checksum is strictly rejected', () => {
  const frame = buildSyntheticBl0942Frame(230.0, 1.5, 345.0, 12.5);
  frame[22] = 0x00; // Corrupt checksum byte
  const data = parseBl0942Frame(frame);
  assert.strictEqual(data, null);
});

test('10. BL0942: Corrupted header is strictly rejected', () => {
  const frame = buildSyntheticBl0942Frame(230.0, 1.5, 345.0, 12.5);
  frame[0] = 0xAA; // Corrupt header byte
  const data = parseBl0942Frame(frame);
  assert.strictEqual(data, null);
});

// ---------------------------------------------------------------------------
// 5. OTA Version & Anti-Rollback Verification
// ---------------------------------------------------------------------------
function semverCompare(v1, v2) {
  const p1 = v1.split('.').map(Number);
  const p2 = v2.split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    if (p1[i] > p2[i]) return 1;
    if (p1[i] < p2[i]) return -1;
  }
  return 0;
}

function validateOtaManifest(manifest, currentVersion) {
  if (semverCompare(manifest.version, currentVersion) < 0) return { valid: false, reason: 'ANTI_ROLLBACK' };
  if (manifest.minFirmwareVersion && semverCompare(currentVersion, manifest.minFirmwareVersion) < 0) {
    return { valid: false, reason: 'MIN_VERSION_NOT_MET' };
  }
  if (manifest.binarySizeBytes > 1792 * 1024) return { valid: false, reason: 'BINARY_TOO_LARGE' };
  if (!manifest.sha256 || manifest.sha256.length !== 64) return { valid: false, reason: 'INVALID_SHA256' };
  return { valid: true };
}

test('11. OTA: Upgrade to newer version permitted', () => {
  const res = validateOtaManifest({
    version: '1.1.0',
    minFirmwareVersion: '1.0.0',
    binarySizeBytes: 1200000,
    sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
  }, '1.0.0');
  assert.strictEqual(res.valid, true);
});

test('12. OTA: Downgrade rejected by anti-rollback policy', () => {
  const res = validateOtaManifest({
    version: '0.9.0',
    minFirmwareVersion: '0.8.0',
    binarySizeBytes: 1200000,
    sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
  }, '1.0.0');
  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.reason, 'ANTI_ROLLBACK');
});

test('13. OTA: Intermediate version bridge required by minFirmwareVersion', () => {
  const res = validateOtaManifest({
    version: '2.0.0',
    minFirmwareVersion: '1.5.0', // Requires at least 1.5.0 to jump to 2.0.0
    binarySizeBytes: 1200000,
    sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
  }, '1.2.0');
  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.reason, 'MIN_VERSION_NOT_MET');
});

test('14. OTA: Oversized binary exceeding partition size rejected', () => {
  const res = validateOtaManifest({
    version: '1.1.0',
    minFirmwareVersion: '1.0.0',
    binarySizeBytes: 2000000, // > 1792 KB
    sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
  }, '1.0.0');
  assert.strictEqual(res.valid, false);
  assert.strictEqual(res.reason, 'BINARY_TOO_LARGE');
});

// ---------------------------------------------------------------------------
// 6. GATT 6105 Product Info Long-Read / Offset Handling Simulation
// ---------------------------------------------------------------------------
const BLE_ATT_ERR_INVALID_OFFSET = 0x07;
const BLE_ATT_ERR_INSUFFICIENT_RES = 0x11;

function simulateGattReadSlice(payload, offset) {
  const length = payload.length;
  if (offset > length) {
    return { status: BLE_ATT_ERR_INVALID_OFFSET, data: null };
  }
  if (offset === length) {
    return { status: 0, data: '' }; // EOF
  }
  const slice = payload.slice(offset);
  return { status: 0, data: slice };
}

test('15. GATT 6105: Read at offset 0 returns full payload', () => {
  const payload = JSON.stringify({
    product: 'EH Smart Switch 3X',
    p: 'EH Smart Switch 3X',
    deviceId: 'c0a80101-0000-4000-8000-000000000001',
    serialNumber: 'EH-SW3X-2026W12-00001',
    firmwareVersion: '1.0.0',
    variant: 'eh-smart-switch-3x'
  });
  const res = simulateGattReadSlice(payload, 0);
  assert.strictEqual(res.status, 0);
  assert.strictEqual(res.data, payload);
});

test('16. GATT 6105: Blob read at partial offset returns remaining slice', () => {
  const payload = '{"product":"EH Smart Switch 3X","deviceId":"123"}';
  const res = simulateGattReadSlice(payload, 10);
  assert.strictEqual(res.status, 0);
  assert.strictEqual(res.data, payload.slice(10));
});

test('17. GATT 6105: Read at exact EOF (offset == length) returns empty slice without error', () => {
  const payload = '{"product":"EH Smart Switch 3X"}';
  const res = simulateGattReadSlice(payload, payload.length);
  assert.strictEqual(res.status, 0);
  assert.strictEqual(res.data, '');
});

test('18. GATT 6105: Read beyond EOF (offset > length) returns BLE_ATT_ERR_INVALID_OFFSET', () => {
  const payload = '{"product":"EH Smart Switch 3X"}';
  const res = simulateGattReadSlice(payload, payload.length + 1);
  assert.strictEqual(res.status, BLE_ATT_ERR_INVALID_OFFSET);
});

console.log(`\n────────────────────────────────────────────────────────────`);
console.log(`  ALL ${passCount} FIRMWARE HOST TESTS PASSED ✅`);
console.log(`────────────────────────────────────────────────────────────\n`);
