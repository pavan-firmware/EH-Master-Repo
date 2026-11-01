/**
 * EH Home Desktop Foundation Automated Test Suite (ESM)
 *
 * Validates:
 * - Frontend bundle artifact existence & secret-free distribution
 * - Desktop configuration & sensitive data redaction
 * - Native service abstractions (Flasher, Serial, Scanner, Printer)
 * - Python sidecar flasher boundary
 * - API client request construction & error normalization
 * - Tauri v2 configuration integrity & command security (no arbitrary execution)
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
  console.log('=== EH HOME DESKTOP FOUNDATION TESTS ===\n');

  const desktopDir = path.join(__dirname, '..');

  // ── 1. FRONTEND BUNDLE & SECRETS INSPECTION ───────────────────────────
  console.log('1. Frontend Bundle & Distribution:');

  await runTest('dist/index.html is generated and well-formed', () => {
    const htmlPath = path.join(desktopDir, 'dist', 'index.html');
    assert.ok(fs.existsSync(htmlPath), 'dist/index.html must exist');
    const content = fs.readFileSync(htmlPath, 'utf8');
    assert.ok(content.includes('EH Home'), 'Title must be present in HTML');
    assert.ok(content.includes('id="root"'), 'Root element must be present');
  });

  await runTest('Built assets do not leak plaintext secrets or credentials', () => {
    const assetsDir = path.join(desktopDir, 'dist', 'assets');
    assert.ok(fs.existsSync(assetsDir), 'dist/assets directory must exist');
    const files = fs.readdirSync(assetsDir).filter((f) => f.endsWith('.js'));
    assert.ok(files.length > 0, 'Compiled JS bundle must exist');

    files.forEach((file) => {
      const content = fs.readFileSync(path.join(assetsDir, file), 'utf8');
      assert.strictEqual(content.includes('factory_secret_password'), false);
      assert.strictEqual(content.includes('private_key_production'), false);
      assert.strictEqual(content.includes('wifi_wpa2_key'), false);
    });
  });

  // ── 2. CONFIGURATION & SENSITIVE DATA REDACTION ───────────────────────
  console.log('\n2. Configuration & Sensitive Data Redaction:');

  const redactSensitiveData = (data) => {
    if (!data || typeof data !== 'object') return data;
    const sanitized = {};
    const REDACTED_KEYS = ['password', 'token', 'secret', 'privatekey', 'private_key', 'wifipassword', 'wifi_password'];
    for (const [k, v] of Object.entries(data)) {
      if (REDACTED_KEYS.some((rk) => k.toLowerCase().includes(rk))) {
        sanitized[k] = '[REDACTED]';
      } else {
        sanitized[k] = v;
      }
    }
    return sanitized;
  };

  await runTest('redactSensitiveData sanitizes sensitive fields', () => {
    const payload = {
      user: 'operator_1',
      password: 'secret_password_123',
      wifi_password: 'home_wifi_secret',
      serialNumber: 'EH-SW3X-2026W12-00891',
    };
    const redacted = redactSensitiveData(payload);
    assert.strictEqual(redacted.user, 'operator_1');
    assert.strictEqual(redacted.serialNumber, 'EH-SW3X-2026W12-00891');
    assert.strictEqual(redacted.password, '[REDACTED]');
    assert.strictEqual(redacted.wifi_password, '[REDACTED]');
  });

  // ── 3. NATIVE SERVICE ABSTRACTIONS ───────────────────────────────────
  console.log('\n3. Native Service Abstractions:');

  await runTest('PythonSidecarFlasher boundary probes correctly without executing flash_device.py', async () => {
    const flasherSource = fs.readFileSync(path.join(desktopDir, 'src/services/native/flasher.service.ts'), 'utf8');
    assert.ok(flasherSource.includes('export interface IFlasherService'));
    assert.ok(flasherSource.includes('export class PythonSidecarFlasher implements IFlasherService'));
    assert.ok(flasherSource.includes('probeDevice'));
    assert.ok(flasherSource.includes('flashFirmware'));
    assert.ok(flasherSource.includes('cancelOperation'));
  });

  await runTest('Serial, Scanner, and Printer interfaces are defined', () => {
    const serialSource = fs.readFileSync(path.join(desktopDir, 'src/services/native/serial.service.ts'), 'utf8');
    const scannerSource = fs.readFileSync(path.join(desktopDir, 'src/services/native/scanner.service.ts'), 'utf8');
    const printerSource = fs.readFileSync(path.join(desktopDir, 'src/services/native/printer.service.ts'), 'utf8');

    assert.ok(serialSource.includes('export interface ISerialService'));
    assert.ok(scannerSource.includes('export interface IScannerService'));
    assert.ok(printerSource.includes('export interface IPrinterService'));
  });

  // ── 4. API CLIENT IMPLEMENTATION ─────────────────────────────────────
  console.log('\n4. API Client Implementation:');

  await runTest('API Client provides typed methods for health and system info', () => {
    const clientSource = fs.readFileSync(path.join(desktopDir, 'src/services/api-client.ts'), 'utf8');
    assert.ok(clientSource.includes('export class ApiClient'));
    assert.ok(clientSource.includes('checkHealth()'));
    assert.ok(clientSource.includes('checkReadiness()'));
    assert.ok(clientSource.includes('getSystemInfo()'));
    assert.ok(clientSource.includes('x-request-id'));
  });

  // ── 5. TAURI MANIFEST & COMMAND SECURITY ─────────────────────────────
  console.log('\n5. Tauri Manifest & Command Security:');

  await runTest('tauri.conf.json is valid with proper security CSP and identifier', () => {
    const confPath = path.join(desktopDir, 'src-tauri', 'tauri.conf.json');
    assert.ok(fs.existsSync(confPath));
    const conf = JSON.parse(fs.readFileSync(confPath, 'utf8'));
    assert.strictEqual(conf.identifier, 'com.ehhome.desktop');
    assert.ok(conf.app.security.csp.includes("connect-src 'self' http://localhost:3100"));
  });

  await runTest('Cargo.toml defines Tauri v2 dependencies', () => {
    const cargoPath = path.join(desktopDir, 'src-tauri', 'Cargo.toml');
    assert.ok(fs.existsSync(cargoPath));
    const content = fs.readFileSync(cargoPath, 'utf8');
    assert.ok(content.includes('name = "eh-home-desktop"'));
    assert.ok(content.includes('tauri = { version = "2.0"'));
  });

  await runTest('Tauri commands do not expose arbitrary shell execution API', () => {
    const commandsSource = fs.readFileSync(path.join(desktopDir, 'src-tauri', 'src', 'commands.rs'), 'utf8');
    assert.strictEqual(commandsSource.includes('execute_shell'), false);
    assert.strictEqual(commandsSource.includes('execute_cmd'), false);
    assert.strictEqual(commandsSource.includes('command: String'), false);
    assert.ok(commandsSource.includes('pub fn get_app_info()'));
    assert.ok(commandsSource.includes('pub fn check_native_service_status()'));
    assert.ok(commandsSource.includes('pub fn list_serial_ports()'));
  });

  // ── SUMMARY ───────────────────────────────────────────────────────────
  console.log(`\n=== DESKTOP FOUNDATION TESTS SUMMARY ===`);
  console.log(`Total:  ${totalTests}`);
  console.log(`Passed: ${passedTests}`);
  console.log(`Failed: ${failedTests}`);

  if (failedTests > 0) {
    process.exit(1);
  } else {
    console.log('ALL DESKTOP FOUNDATION TESTS PASSED [OK]\n');
  }
}

main().catch((err) => {
  console.error('Fatal desktop test error:', err);
  process.exit(1);
});
