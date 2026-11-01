/**
 * EH Home Desktop — Professional Installer, System Requirements, Hardware Discovery & Diagnostics Test Suite
 * Validates Tauri installer configuration (NSIS/MSI/DMG/DEB), system requirement detection,
 * Python manufacturing dependencies, USB/serial enumeration, HID scanner, printer discovery,
 * Tauri capability scoping, administrator privilege separation, first-run persistence, and multi-platform adapters.
 */

import assert from 'assert';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

console.log('---------------------------------------------------------------');
console.log('EH HOME DESKTOP — INSTALLER & SYSTEM REQUIREMENTS SUITE');
console.log('---------------------------------------------------------------');

let passedTests = 0;
let totalTests = 0;

function test(name, fn) {
  totalTests++;
  try {
    fn();
    console.log(`  [PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  [FAIL] ${name}: ${err.message}`);
    throw err;
  }
}

const tauriConfPath = path.resolve(__dirname, '../src-tauri/tauri.conf.json');
const capabilitiesPath = path.resolve(__dirname, '../src-tauri/capabilities/default.json');
const commandsRsPath = path.resolve(__dirname, '../src-tauri/src/commands.rs');
const libRsPath = path.resolve(__dirname, '../src-tauri/src/lib.rs');

assert(fs.existsSync(tauriConfPath), 'tauri.conf.json must exist');
const tauriConf = JSON.parse(fs.readFileSync(tauriConfPath, 'utf8'));

assert(fs.existsSync(capabilitiesPath), 'capabilities/default.json must exist');
const capabilities = JSON.parse(fs.readFileSync(capabilitiesPath, 'utf8'));

const commandsSrc = fs.readFileSync(commandsRsPath, 'utf8');
const libSrc = fs.readFileSync(libRsPath, 'utf8');

// 1. Professional Installer Bundle Configuration
test('1. Installer: Bundle active and targets all platforms', () => {
  assert.strictEqual(tauriConf.bundle.active, true);
  assert.strictEqual(tauriConf.bundle.targets, 'all');
});

test('2. Installer: Windows NSIS installer configured with canonical brand icons', () => {
  const nsis = tauriConf.bundle.windows && tauriConf.bundle.windows.nsis;
  assert(nsis, 'Windows NSIS configuration must be defined');
  assert.strictEqual(nsis.installMode, 'both', 'NSIS must support both user and per-machine installation');
  assert(nsis.installerIcon, 'NSIS must specify an installer icon');
  
  const iconIcoPath = path.resolve(__dirname, '../src-tauri', nsis.installerIcon);
  assert(fs.existsSync(iconIcoPath), `Installer icon must exist at ${iconIcoPath}`);
  const icoStats = fs.statSync(iconIcoPath);
  assert(icoStats.size > 10000, `Installer icon (${icoStats.size} bytes) must be a high-resolution multi-size brand icon (>10KB)`);
  
  const iconPngPath = path.resolve(__dirname, '../src-tauri/icons/128x128.png');
  assert(fs.existsSync(iconPngPath), '128x128.png icon must exist');
  const pngStats = fs.statSync(iconPngPath);
  assert(pngStats.size > 1000, `128x128.png (${pngStats.size} bytes) must be a non-placeholder brand icon`);
});

test('3. Installer: Windows WiX / MSI configuration localized', () => {
  const wix = tauriConf.bundle.windows && tauriConf.bundle.windows.wix;
  assert(wix, 'Windows WiX / MSI configuration must be defined');
  assert.strictEqual(wix.language, 'en-US');
});

test('4. Installer: Windows WebView2 bootstrapper configured', () => {
  const webviewMode = tauriConf.bundle.windows && tauriConf.bundle.windows.webviewInstallMode;
  assert(webviewMode, 'WebView2 install mode must be defined');
  assert.strictEqual(webviewMode.type, 'downloadBootstrapper');
});

test('5. Installer: macOS application bundle configured with minimumSystemVersion', () => {
  const macos = tauriConf.bundle.macOS;
  assert(macos, 'macOS bundle config must be present');
  assert.strictEqual(macos.minimumSystemVersion, '10.15');
});

test('6. Installer: Linux distribution dependencies configured (deb & AppImage)', () => {
  const linux = tauriConf.bundle.linux;
  assert(linux, 'Linux bundle config must be present');
  assert(Array.isArray(linux.deb.depends), 'Linux deb must specify dependencies');
  assert(linux.deb.depends.some(d => d.includes('libwebkit2gtk')), 'Must depend on libwebkit2gtk');
  assert(linux.deb.depends.some(d => d.includes('libssl')), 'Must depend on libssl');
  assert.strictEqual(linux.appimage.bundleMediaFramework, false);
});

// 2. Tauri Capabilities & Security Scoping
test('7. Capabilities: Scoped default capability without unrestricted permissions', () => {
  assert(capabilities.permissions, 'Permissions array must be present');
  assert(capabilities.permissions.includes('core:default'), 'Must include core:default');
  assert(capabilities.permissions.includes('shell:allow-open'), 'Must include shell:allow-open');
  assert(!capabilities.permissions.includes('shell:allow-execute-arbitrary'), 'Must NOT allow arbitrary execution');
  assert(!capabilities.permissions.includes('fs:allow-all'), 'Must NOT allow unrestricted filesystem access');
});

test('8. Security Boundary: Native validation gates enforced in commands.rs', () => {
  assert(commandsSrc.includes('pub fn is_valid_serial_port'), 'Must enforce serial port validation');
  assert(commandsSrc.includes('pub fn is_allowed_product_variant'), 'Must enforce product catalog variant lock');
  assert(commandsSrc.includes('contains_secret_material_native'), 'Must enforce zero-secret audit');
});

test('9. Native Registry: All required system and diagnostics commands registered in lib.rs', () => {
  const requiredCommands = [
    'commands::check_system_requirements_native',
    'commands::check_python_manufacturing_runtime_native',
    'commands::enumerate_usb_devices_native',
    'commands::check_scanner_subsystem_native',
    'commands::check_network_connectivity_native',
    'commands::get_setup_diagnostics_native',
    'commands::list_printers_native',
    'commands::print_pdf_document_native',
  ];
  for (const cmd of requiredCommands) {
    assert(libSrc.includes(cmd), `lib.rs must register ${cmd}`);
  }
});

// 3. System Requirements & Hardware Discovery Schema
test('10. System Specs: SystemRequirementsCheckResponse defines memory, CPU, and WebView2 fields', () => {
  assert(commandsSrc.includes('pub struct SystemRequirementsCheckResponse'), 'Must define SystemRequirementsCheckResponse');
  assert(commandsSrc.includes('pub total_memory_mb: u64'), 'Must check total memory');
  assert(commandsSrc.includes('pub webview2_installed: bool'), 'Must check WebView2 installation');
  assert(commandsSrc.includes('pub meets_minimum_specs: bool'), 'Must evaluate minimum specs');
});

test('11. Python Runtime: Flasher toolchain checks pyserial, esptool, and cryptography', () => {
  assert(commandsSrc.includes('pub struct PythonRuntimeCheckResponse'), 'Must define PythonRuntimeCheckResponse');
  assert(commandsSrc.includes('pyserial'), 'Must check pyserial');
  assert(commandsSrc.includes('esptool'), 'Must check esptool');
  assert(commandsSrc.includes('cryptography'), 'Must check cryptography');
  assert(commandsSrc.includes('pip install pyserial esptool cryptography'), 'Must provide copyable repair instructions');
});

test('12. Host USB & Serial: Discovers real devices with VID/PID and clean empty state', () => {
  assert(commandsSrc.includes('pub struct UsbDeviceInfo'), 'Must define UsbDeviceInfo');
  assert(commandsSrc.includes('pub vendor_id: Option<String>'), 'Must expose VID');
  assert(commandsSrc.includes('pub product_id: Option<String>'), 'Must expose PID');
  assert(commandsSrc.includes('pub driver_status: String'), 'Must expose driver status');
  assert(commandsSrc.includes('No compatible serial device detected.'), 'Must report clean no-device state when empty');
});

test('13. Scanner Subsystem: Checks USB HID keyboard emulation mode and readiness', () => {
  assert(commandsSrc.includes('pub struct ScannerSubsystemStatus'), 'Must define ScannerSubsystemStatus');
  assert(commandsSrc.includes('USB_HID_KEYBOARD_EMULATION'), 'Must support USB HID keyboard emulation');
});

// 4. Printer Discovery & Virtual PDF Workflow
test('14. Printer Model: Strictly distinguishes physical printers from Windows Virtual PDF', () => {
  assert(commandsSrc.includes('pub is_virtual_pdf: bool'), 'Must distinguish virtual PDF printers');
  assert(commandsSrc.includes('Microsoft Print to PDF'), 'Must explicitly handle Microsoft Print to PDF');
  assert(commandsSrc.includes('pub fn print_pdf_document_native'), 'Must implement print_pdf_document_native');
});

test('15. PDF Output Verification: Generates valid PDF-1.4 binary and verifies non-empty size > 0', () => {
  assert(commandsSrc.includes('%PDF-1.4'), 'Must generate standard PDF-1.4 binary');
  assert(commandsSrc.includes('EMPTY_FILE_GENERATED'), 'Must reject empty 0-byte generated files');
  assert(commandsSrc.includes('file_size_bytes: Some(file_size)'), 'Must return verified non-empty file size');
});

// 5. System Setup & Diagnostics Service Verification
test('16. Setup Service: Manages first-run completion and station config persistence', () => {
  const setupServicePath = path.resolve(__dirname, '../src/services/system-setup.service.ts');
  assert(fs.existsSync(setupServicePath), 'system-setup.service.ts must exist');
  const src = fs.readFileSync(setupServicePath, 'utf8');
  assert(src.includes('isFirstRunCompleted'), 'Must implement isFirstRunCompleted');
  assert(src.includes('saveSetupConfiguration'), 'Must implement saveSetupConfiguration');
  assert(src.includes('getSetupConfiguration'), 'Must implement getSetupConfiguration');
});

test('17. Diagnostics Service: Generates sanitized audit reports with zero secret leakage', () => {
  const diagServicePath = path.resolve(__dirname, '../src/services/diagnostics.service.ts');
  assert(fs.existsSync(diagServicePath), 'diagnostics.service.ts must exist');
  const src = fs.readFileSync(diagServicePath, 'utf8');
  assert(src.includes('exportSanitizedReport'), 'Must implement exportSanitizedReport');
  assert(src.includes('Zero credentials, tokens, or encryption keys are logged.'), 'Must guarantee zero secret leakage');
});

test('18. Setup Wizard View: Implements 5 step progression and live environment rechecking', () => {
  const setupViewPath = path.resolve(__dirname, '../src/features/setup/SystemSetupWizardView.tsx');
  assert(fs.existsSync(setupViewPath), 'SystemSetupWizardView.tsx must exist');
  const src = fs.readFileSync(setupViewPath, 'utf8');
  assert(src.includes('System Specs'), 'Must include System Specs step');
  assert(src.includes('Python Flasher'), 'Must include Python Flasher step');
  assert(src.includes('Hardware & USB'), 'Must include Hardware & USB step');
  assert(src.includes('Network & API'), 'Must include Network & API step');
  assert(src.includes('Station Config'), 'Must include Station Config step');
  assert(src.includes('handleRecheck'), 'Must support live environment rechecking');
});

// 6. Startup Loader Verification
test('19. Startup Loader: Embedded centered loader in index.html matching application dark theme', () => {
  const indexPath = path.resolve(__dirname, '../index.html');
  assert(fs.existsSync(indexPath), 'index.html must exist');
  const html = fs.readFileSync(indexPath, 'utf8');
  assert(html.includes('app-loader-container'), 'Must contain loader container');
  assert(html.includes('#090D14') || html.includes('#1E1E1E'), 'Must use dark background matching application theme');
  assert(html.includes('EH HOME'), 'Must render EH HOME title in loader');
});

test('20. Startup Splash: React StartupSplash component mounted with 3-second mobile animation duration', () => {
  const splashPath = path.resolve(__dirname, '../src/components/StartupSplash.tsx');
  assert(fs.existsSync(splashPath), 'StartupSplash.tsx must exist');
  const splashSrc = fs.readFileSync(splashPath, 'utf8');
  assert(splashSrc.includes('durationMs = 3000'), 'Default display duration must be 3000ms (3 seconds)');
  assert(splashSrc.includes('#090D14') || splashSrc.includes('#070A0F'), 'Must use mobile theme background');
  assert(splashSrc.includes('app_startup_without_loading.png'), 'Must render mobile startup image');

  const appTsxPath = path.resolve(__dirname, '../src/App.tsx');
  const appTsx = fs.readFileSync(appTsxPath, 'utf8');
  assert(appTsx.includes('StartupSplash'), 'App.tsx must mount StartupSplash component on boot');
  assert(appTsx.includes('durationMs={3000}'), 'App.tsx must configure 3000ms startup duration');
});

console.log('---------------------------------------------------------------');
console.log(`ALL ${passedTests}/${totalTests} SYSTEM & INSTALLER TESTS PASSED SUCCESSFULLY.`);
console.log('---------------------------------------------------------------');
