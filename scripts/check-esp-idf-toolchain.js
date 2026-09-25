/**
 * EH Home — ESP-IDF Toolchain Drift & Environment Guard
 *
 * Verifies:
 * 1. Pinned ESP-IDF Framework version (5.4.1)
 * 2. VS Code IDE configuration consistency
 * 3. Firmware component manifest invariants (IDF 5.4.x built-in MQTT, no unvetted managed overrides)
 * 4. Absense of accidental ESP-IDF 6.x migration artifacts
 * 5. Deterministic activation & build script integrity
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('================================================================');
console.log('   EH HOME — ESP-IDF TOOLCHAIN DRIFT & REPRODUCIBILITY GUARD    ');
console.log('================================================================\n');

let failedChecks = 0;

function check(name, fn) {
  try {
    fn();
    console.log(`  [PASS] ${name}`);
  } catch (err) {
    console.error(`  [FAIL] ${name}: ${err.message}`);
    failedChecks++;
  }
}

const rootDir = path.resolve(__dirname, '..');
const appDir = path.join(rootDir, 'firmware', 'platforms', 'esp32', 'smart-switch-app');
const vscodeSettingsPath = path.join(rootDir, '.vscode', 'settings.json');
const manifestPath = path.join(appDir, 'main', 'idf_component.yml');
const managedComponentsDir = path.join(appDir, 'managed_components');

// 1. Check VS Code Settings Pinning
check('TC01: VS Code ESP-IDF Extension Settings Pinning', () => {
  if (!fs.existsSync(vscodeSettingsPath)) {
    throw new Error('.vscode/settings.json not found');
  }
  const settings = JSON.parse(fs.readFileSync(vscodeSettingsPath, 'utf8'));
  
  if (!settings['idf.espIdfPath'] || !settings['idf.espIdfPath'].includes('v5.4.1')) {
    throw new Error(`idf.espIdfPath must point to ESP-IDF v5.4.1. Found: ${settings['idf.espIdfPath']}`);
  }
  if (!settings['idf.pythonBinPath'] || !settings['idf.pythonBinPath'].includes('idf5.4')) {
    throw new Error(`idf.pythonBinPath must point to idf5.4 virtual environment. Found: ${settings['idf.pythonBinPath']}`);
  }
});

// 2. Check Firmware Component Manifest Invariants
check('TC02: Component Manifest Invariants & Version Bounds', () => {
  if (!fs.existsSync(manifestPath)) {
    throw new Error('main/idf_component.yml not found');
  }
  const manifest = fs.readFileSync(manifestPath, 'utf8');
  if (manifest.includes('espressif/mqtt')) {
    throw new Error('Forbidden managed dependency "espressif/mqtt" detected in manifest! ESP-IDF 5.4.1 uses native built-in MQTT.');
  }
  if (!manifest.includes('^5.4') && !manifest.includes('5.4.')) {
    throw new Error('Manifest must explicitly restrict IDF version to 5.4.x (e.g. "^5.4.0")');
  }
});

// 3. Check for Accidental IDF 6.x Artifacts
check('TC03: Absence of Accidental IDF 6 Managed Overrides', () => {
  if (fs.existsSync(path.join(managedComponentsDir, 'espressif__mqtt'))) {
    throw new Error('Found managed_components/espressif__mqtt directory. IDF 5.4.1 projects must use built-in MQTT component.');
  }
});

// 4. Check Environment Activation & Build Scripts
check('TC04: Activation & Build Scripts Integrity', () => {
  const activateScript = path.join(rootDir, 'scripts', 'activate_idf5.4.ps1');
  const buildScript = path.join(rootDir, 'scripts', 'build_firmware.ps1');

  if (!fs.existsSync(activateScript)) throw new Error('scripts/activate_idf5.4.ps1 missing');
  if (!fs.existsSync(buildScript)) throw new Error('scripts/build_firmware.ps1 missing');

  const actContent = fs.readFileSync(activateScript, 'utf8');
  if (!actContent.includes('C:\\esp\\v5.4.1\\esp-idf')) throw new Error('activate_idf5.4.ps1 does not target C:\\esp\\v5.4.1\\esp-idf');
});

// 5. Check Installed ESP-IDF Framework Version if on host
check('TC05: Host ESP-IDF Framework Version Validation (v5.4.1)', () => {
  const idfPath = 'C:\\esp\\v5.4.1\\esp-idf';
  const pythonExe = 'C:\\Users\\pavan\\.espressif\\python_env\\idf5.4_py3.14_env\\Scripts\\python.exe';
  
  if (fs.existsSync(idfPath) && fs.existsSync(pythonExe)) {
    const idfPy = path.join(idfPath, 'tools', 'idf.py');
    const output = execSync(`"${pythonExe}" "${idfPy}" --version`, {
      env: { ...process.env, IDF_PATH: idfPath, IDF_PYTHON_ENV_PATH: path.dirname(path.dirname(pythonExe)) }
    }).toString().trim();

    if (!output.includes('v5.4.1')) {
      throw new Error(`\nEXPECTED ESP-IDF = 5.4.1\nCURRENT ESP-IDF  = ${output}\n\nERROR: Wrong firmware toolchain. Use the pinned EH Home ESP-IDF environment.\n`);
    }
  } else {
    console.log('    (Host paths not present in current test environment, skipped live check)');
  }
});

console.log('\n================================================================');
if (failedChecks === 0) {
  console.log('  ALL TOOLCHAIN GUARDS PASSED (ESP-IDF 5.4.1 PINNED) ✅');
  console.log('================================================================\n');
  process.exit(0);
} else {
  console.error(`  TOOLCHAIN DRIFT DETECTED: ${failedChecks} check(s) failed! ❌`);
  console.log('================================================================\n');
  process.exit(1);
}
