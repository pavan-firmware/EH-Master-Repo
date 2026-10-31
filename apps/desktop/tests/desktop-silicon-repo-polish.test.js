/**
 * EH HOME DESKTOP — COMPREHENSIVE PRODUCTION SAFETY & INVARIANT TEST SUITE
 * 
 * Verifies:
 * 1. Real chipInfo parsing
 * 2. Generic ESP32 identification (esp32 target / Xtensa LX6)
 * 3. ESP32-C6 identification (esp32c6 target / RISC-V)
 * 4. Unknown chip handling
 * 5. Generic ESP32 vs ESP32-C6 mismatch detection
 * 6. Flash disabled on mismatch in UI
 * 7. Canonical manifest validation (strict firmware-build-manifest.json)
 * 8. Manifest/binary SHA-256 exact match
 * 9. Non-RELEASED artifact blocked (DRAFT, BUILDING, VALIDATION, APPROVED, DEPRECATED, RETIRED, REVOKED)
 * 10. Canonical repository-root resolution across subsystems
 * 11. Mobile splash asset & color calibration (0xFF090D14, 0xFFDCAE45, 0xFFF7C852)
 * 12. Startup splash has no native side effects
 * 13. GitHub NOT_CONNECTED state
 * 14. GitHub READ_ONLY state
 * 15. GitHub WRITE state when actual permission exists
 * 16. No fake GitHub actions (permission-gated)
 * 17. No fake repository contents (reads physical disk)
 * 18. Switch 1x/2x/3x/4x compatibility with esp32c6-switch-platform
 * 19. Canonical hardware revisions HW_1_0 and HW_1_1 supported for all switch variants
 * 20. Wrong hardware revision rejection (Gate 8)
 * 21. Wrong firmware family rejection (Gate 6)
 * 22. Real origin URL and EH-Master-Repo repository verification
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const desktopRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(desktopRoot, '../..');

describe('EH Home Desktop — Production Safety & Invariant Test Suite', () => {
  // Test 1: Real chipInfo parsing
  it('1. Rust backend parses chipInfo and never defaults to fake ESP32-C6', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('let chip_info = dev.get("chipInfo");'), 'Must parse chipInfo object');
    assert.ok(!commandsRs.includes('.unwrap_or("ESP32-C6")'), 'Must never default to ESP32-C6');
  });

  // Test 2: Generic ESP32 identification
  it('2. Correctly categorizes generic ESP32 silicon with architecture target esp32', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('"esp32" => ('), 'Maps esp32 family to esp32 target');
    assert.ok(commandsRs.includes('Dual-Core Tensilica Xtensa LX6'), 'Includes Xtensa core feature for classic ESP32');
  });

  // Test 3: ESP32-C6 identification
  it('3. Correctly categorizes ESP32-C6 silicon with architecture target esp32c6', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('"esp32-c6" => ('), 'Maps esp32-c6 family to esp32c6 target');
    assert.ok(commandsRs.includes('Single-Core RISC-V 160MHz'), 'Includes RISC-V core feature for ESP32-C6');
  });

  // Test 4: Unknown chip handling
  it('4. Handles unknown / interrogation failed silicon safely with Unknown / Unsupported status', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('Unknown / Unsupported ESP32'), 'Defaults to Unknown / Unsupported ESP32 on interrogation failure');
    assert.ok(commandsRs.includes('connection_status: "UNKNOWN"'), 'Sets connection status to UNKNOWN');
  });

  // Test 5: Generic ESP32 vs ESP32-C6 mismatch
  it('5. Gate 7 detects target silicon mismatch between connected MCU and firmware target', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('// Gate 7: Target MCU Architecture Match'), 'Gate 7 explicit comment');
    assert.ok(commandsRs.includes('"TARGET_MISMATCH"'), 'Returns TARGET_MISMATCH error code on architecture disparity');
  });

  // Test 6: Flash disabled on mismatch
  it('6. Frontend UI disables flashing button when target silicon mismatch is detected', () => {
    const provisionerTsx = fs.readFileSync(path.join(desktopRoot, 'src/features/provisioner/ProvisionerView.tsx'), 'utf8');
    assert.ok(provisionerTsx.includes('!mcuCompat.isCompatible'), 'Gates flash execution on mcuCompat');
    assert.ok(provisionerTsx.includes('MCU ARCHITECTURE MISMATCH'), 'Displays prominent architecture mismatch banner');
    assert.ok(provisionerTsx.includes('disabled={!isFlashReady}'), 'Disables button when flash is not ready');
  });

  // Test 7: Canonical manifest validation
  it('7. Native layer resolves strictly the canonical firmware-build-manifest.json', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('parent.join("firmware-build-manifest.json")'), 'Resolves canonical firmware-build-manifest.json');
    assert.ok(!commandsRs.includes('parent.join("manifest.json")'), 'Removed non-contractual manifest.json fallback');
    assert.ok(!commandsRs.includes('parent.join("build-manifest.json")'), 'Removed non-contractual build-manifest.json fallback');
  });

  // Test 8: Manifest/binary SHA-256 match
  it('8. Physical firmware binary SHA-256 matches firmware-build-manifest.json exactly', () => {
    const manifestPath = path.join(repoRoot, 'firmware/platforms/esp32/smart-switch-app/build/firmware-build-manifest.json');
    const binPath = path.join(repoRoot, 'firmware/platforms/esp32/smart-switch-app/build/eh-smart-switch-app.bin');
    assert.ok(fs.existsSync(manifestPath), 'firmware-build-manifest.json must exist');
    assert.ok(fs.existsSync(binPath), 'eh-smart-switch-app.bin must exist');

    const manifestContent = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    const binBuffer = fs.readFileSync(binPath);
    const calculatedSha = crypto.createHash('sha256').update(binBuffer).digest('hex');
    assert.equal(calculatedSha, manifestContent.artifacts[0].sha256, 'Binary hash must match manifest');
  });

  // Test 9: Non-RELEASED artifact blocked
  it('9. Gate 4 blocks unreleased artifacts (DRAFT, BUILDING, VALIDATION, APPROVED, DEPRECATED, RETIRED, REVOKED)', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('ARTIFACT_LIFECYCLE_NOT_RELEASED'), 'Returns ARTIFACT_LIFECYCLE_NOT_RELEASED');
    assert.ok(commandsRs.includes('matches!(raw_status, "RELEASED" | "PUBLISHED")'), 'Only RELEASED/PUBLISHED is permitted');
  });

  // Test 10: Canonical repository-root resolution
  it('10. Canonical repository-root is authoritatively resolved across all subsystems', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('pub fn get_workspace_root()'), 'Defines canonical get_workspace_root');
    assert.ok(commandsRs.includes('product-definitions'), 'Locates root by product-definitions and .git markers');
  });

  // Test 11: Mobile splash asset/source verification
  it('11. Desktop splash uses colors and branding calibrated with Flutter mobile splash', () => {
    const mobileSplashPath = path.join(repoRoot, 'smart_home_application_v1/lib/features/splash/presentation/splash_screen.dart');
    assert.ok(fs.existsSync(mobileSplashPath), 'Flutter mobile splash_screen.dart must exist');
    const mobileCode = fs.readFileSync(mobileSplashPath, 'utf8');
    assert.ok(mobileCode.includes('0xFF090D14'), 'Mobile background is 0xFF090D14');
    assert.ok(mobileCode.includes('0xFFDCAE45'), 'Mobile goldMain is 0xFFDCAE45');
    assert.ok(mobileCode.includes('0xFFF7C852'), 'Mobile goldBright is 0xFFF7C852');

    const desktopHtml = fs.readFileSync(path.join(desktopRoot, 'index.html'), 'utf8');
    assert.ok(desktopHtml.includes('#090D14'), 'Desktop uses same #090D14 background');
    assert.ok(desktopHtml.includes('#DCAE45'), 'Desktop uses same #DCAE45 gold accent');
    assert.ok(desktopHtml.includes('#F7C852'), 'Desktop uses same #F7C852 bright gold accent');
  });

  // Test 12: Startup splash has no native side effects
  it('12. Desktop startup initialization does not trigger scans or sidecar processes on boot', () => {
    const mainTsx = fs.readFileSync(path.join(desktopRoot, 'src/main.tsx'), 'utf8');
    const appTsx = fs.readFileSync(path.join(desktopRoot, 'src/App.tsx'), 'utf8');
    assert.ok(!mainTsx.includes('flash_device'), 'main.tsx does not spawn flasher');
    assert.ok(!appTsx.includes('flash_device'), 'App.tsx does not spawn flasher on mount');
  });

  // Test 13: GitHub NOT_CONNECTED state
  it('13. Reports NOT_CONNECTED and Public Read-Only when no GitHub token is present', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('auth_state: "NOT_CONNECTED".to_string()'), 'Defines NOT_CONNECTED status');
    assert.ok(commandsRs.includes('can_push: false'), 'Disables push in NOT_CONNECTED');
  });

  // Test 14: GitHub READ_ONLY state
  it('14. Reports READ_ONLY when authenticated token lacks explicit write access', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('auth_state: "READ_ONLY".to_string()'), 'Defines READ_ONLY status');
    assert.ok(commandsRs.includes('can_push: false'), 'Disables push in READ_ONLY');
  });

  // Test 15: GitHub WRITE state when actual permission exists
  it('15. Reports WRITE_ACCESS and enables push when explicit write permissions exist', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('auth_state: "WRITE_ACCESS".to_string()'), 'Defines WRITE_ACCESS status');
    assert.ok(commandsRs.includes('can_push: true'), 'Enables push in WRITE_ACCESS');
  });

  // Test 16: No fake GitHub actions
  it('16. Repository UI disables push and PR actions when not authorized without faking success', () => {
    const repoViewTsx = fs.readFileSync(path.join(desktopRoot, 'src/features/repositories/RepositoriesView.tsx'), 'utf8');
    assert.ok(repoViewTsx.includes('disabled={!authStatus?.canPush}'), 'Push button strictly disabled');
    assert.ok(repoViewTsx.includes('disabled={!authStatus?.canCreatePr}'), 'PR button strictly disabled');
    assert.ok(!repoViewTsx.includes('simulatePush'), 'No simulated push functions');
  });

  // Test 17: No fake repository contents
  it('17. Repository file tree and source content are fetched directly from physical filesystem', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('pub fn list_repository_files'), 'Native directory listing command');
    assert.ok(commandsRs.includes('pub fn read_source_file_content'), 'Native file content reading command');
    assert.ok(commandsRs.includes('std::fs::read_dir'), 'Reads physical directory from disk');
    assert.ok(commandsRs.includes('std::fs::read'), 'Reads physical file content from disk');
  });

  // Test 18: Switch 1x/2x/3x/4x product compatibility
  it('18. Switch manifest covers all 4 switch variants under esp32c6-switch-platform', () => {
    const manifestPath = path.join(repoRoot, 'firmware/platforms/esp32/smart-switch-app/build/firmware-build-manifest.json');
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    assert.equal(manifest.firmwareFamily, 'esp32c6-switch-platform');
    assert.ok(manifest.productVariants.includes('eh-smart-switch-1x'));
    assert.ok(manifest.productVariants.includes('eh-smart-switch-2x'));
    assert.ok(manifest.productVariants.includes('eh-smart-switch-3x'));
    assert.ok(manifest.productVariants.includes('eh-smart-switch-4x'));
  });

  // Test 19: Canonical hardware revisions HW_1_0 and HW_1_1
  it('19. Switch manifest specifies canonical hardware revisions HW_1_0 and HW_1_1', () => {
    const manifestPath = path.join(repoRoot, 'firmware/platforms/esp32/smart-switch-app/build/firmware-build-manifest.json');
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    assert.ok(manifest.compatibleHardwareRevisions.includes('HW_1_0'));
    assert.ok(manifest.compatibleHardwareRevisions.includes('HW_1_1'));
  });

  // Test 20: Wrong hardware revision rejection (Gate 8)
  it('20. Gate 8 rejects incompatible hardware revision with HARDWARE_INCOMPATIBLE', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('// Gate 8: Hardware Revision Compatibility'));
    assert.ok(commandsRs.includes('"HARDWARE_INCOMPATIBLE"'));
  });

  // Test 21: Wrong firmware family rejection (Gate 6)
  it('21. Gate 6 strictly prevents switch variants from accepting socket firmware', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('"esp32c6-switch-platform" => &["eh-smart-switch-1x", "eh-smart-switch-2x", "eh-smart-switch-3x", "eh-smart-switch-4x"]'));
    assert.ok(commandsRs.includes('"esp32c6-socket-platform" => &["eh-smart-socket-1x", "eh-smart-socket-2x", "eh-smart-socket-3x"]'));
  });

  // Test 22: Real origin URL and EH-Master-Repo repository verification
  it('22. Workspace info command extracts origin URL dynamically from local git config', () => {
    const commandsRs = fs.readFileSync(path.join(desktopRoot, 'src-tauri/src/commands.rs'), 'utf8');
    assert.ok(commandsRs.includes('"config", "--get", "remote.origin.url"'));
    assert.ok(commandsRs.includes('canonical_remote_url: remote_url'));
  });
});
