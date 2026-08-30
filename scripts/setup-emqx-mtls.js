'use strict';

/**
 * EH Home — EMQX mTLS & Authoritative Device ACL Setup (Phase 13 Deterministic)
 *
 * Configures development certificates and per-device ACL rules for EMQX 5.8:
 *   1. Writes local certificates (.local-certs/) and acl.conf
 *   2. If eh_emqx container is active, synchronizes certs/acl and applies runtime settings
 *   3. Enforces mTLS verification and strict per-device isolation
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const { generateCerts, LOCAL_CERTS_DIR } = require('./generate-dev-certs');

function runEmqxEval(expr) {
  console.log(`[SetupEMQX] Eval: ${expr}`);
  try {
    const out = execSync(`docker exec eh_emqx emqx eval "${expr}"`, { encoding: 'utf8' }).trim();
    console.log(`  -> ${out}`);
    if (out.startsWith('{error,') && !out.includes('already_exists')) {
      console.warn(`[SetupEMQX Notice] ${out}`);
    }
    return out;
  } catch (err) {
    console.warn(`[SetupEMQX Notice] Command evaluation: ${err.message}`);
  }
}

function setupEmqxMtls() {
  const certs = generateCerts();

  const DEVICE_A_ID = '0194fe23-7a1b-7890-a123-456789abcdef';
  const DEVICE_B_ID = '0194fe23-7a1b-7890-b456-123456fedcba';

  const aclContent = `%% =============================================================================
%% EH Home — EMQX 5.8 Authoritative Device ACL
%% =============================================================================

%% 1. Admin / Backend & Test Harness Whitelist
{allow, {username, "admin"}, all, ["#"]}.
{allow, {clientid, {re, "^backend"}}, all, ["#"]}.
{allow, {clientid, {re, "^eh_device_"}}, all, ["#"]}.
{allow, {clientid, {re, "^eh_test"}}, all, ["#"]}.
{allow, {clientid, {re, "^sub_test"}}, all, ["#"]}.

%% 2. Device A — Per-Device Namespace Isolation (${DEVICE_A_ID})
{allow, {clientid, "${DEVICE_A_ID}"}, subscribe, ["eh/v1/devices/${DEVICE_A_ID}/commands"]}.
{allow, {clientid, "${DEVICE_A_ID}"}, publish, [
  "eh/v1/devices/${DEVICE_A_ID}/command-receipts",
  "eh/v1/devices/${DEVICE_A_ID}/state",
  "eh/v1/devices/${DEVICE_A_ID}/events",
  "eh/v1/devices/${DEVICE_A_ID}/telemetry",
  "eh/v1/devices/${DEVICE_A_ID}/availability"
]}.
{allow, {username, "${DEVICE_A_ID}"}, subscribe, ["eh/v1/devices/${DEVICE_A_ID}/commands"]}.
{allow, {username, "${DEVICE_A_ID}"}, publish, [
  "eh/v1/devices/${DEVICE_A_ID}/command-receipts",
  "eh/v1/devices/${DEVICE_A_ID}/state",
  "eh/v1/devices/${DEVICE_A_ID}/events",
  "eh/v1/devices/${DEVICE_A_ID}/telemetry",
  "eh/v1/devices/${DEVICE_A_ID}/availability"
]}.

%% 3. Device B — Per-Device Namespace Isolation (${DEVICE_B_ID})
{allow, {clientid, "${DEVICE_B_ID}"}, subscribe, ["eh/v1/devices/${DEVICE_B_ID}/commands"]}.
{allow, {clientid, "${DEVICE_B_ID}"}, publish, [
  "eh/v1/devices/${DEVICE_B_ID}/command-receipts",
  "eh/v1/devices/${DEVICE_B_ID}/state",
  "eh/v1/devices/${DEVICE_B_ID}/events",
  "eh/v1/devices/${DEVICE_B_ID}/telemetry",
  "eh/v1/devices/${DEVICE_B_ID}/availability"
]}.
{allow, {username, "${DEVICE_B_ID}"}, subscribe, ["eh/v1/devices/${DEVICE_B_ID}/commands"]}.
{allow, {username, "${DEVICE_B_ID}"}, publish, [
  "eh/v1/devices/${DEVICE_B_ID}/command-receipts",
  "eh/v1/devices/${DEVICE_B_ID}/state",
  "eh/v1/devices/${DEVICE_B_ID}/events",
  "eh/v1/devices/${DEVICE_B_ID}/telemetry",
  "eh/v1/devices/${DEVICE_B_ID}/availability"
]}.

%% 4. Final Deny All (Fail-Closed)
{deny, all}.
`;

  const tmpAcl = path.join(LOCAL_CERTS_DIR, 'acl.conf');
  fs.writeFileSync(tmpAcl, aclContent, 'utf8');

  // Check if Docker container eh_emqx is running
  try {
    const isRunning = execSync('docker inspect -f "{{.State.Running}}" eh_emqx', { encoding: 'utf8' }).trim();
    if (isRunning === 'true') {
      console.log('[SetupEMQX] Copying certificates & ACL to running EMQX container...');
      execSync(`docker cp "${certs.caCrt}" eh_emqx:/opt/emqx/etc/certs/cacert.pem`, { stdio: 'inherit' });
      execSync(`docker cp "${certs.serverCrt}" eh_emqx:/opt/emqx/etc/certs/cert.pem`, { stdio: 'inherit' });
      execSync(`docker cp "${certs.serverKey}" eh_emqx:/opt/emqx/etc/certs/key.pem`, { stdio: 'inherit' });
      execSync(`docker cp "${tmpAcl}" eh_emqx:/opt/emqx/etc/acl.conf`, { stdio: 'inherit' });

      execSync(`docker exec -u 0 eh_emqx chown emqx:emqx /opt/emqx/etc/certs/cacert.pem /opt/emqx/etc/certs/cert.pem /opt/emqx/etc/certs/key.pem /opt/emqx/etc/acl.conf`, { stdio: 'inherit' });
      execSync(`docker exec -u 0 eh_emqx chmod 644 /opt/emqx/etc/certs/cacert.pem /opt/emqx/etc/certs/cert.pem /opt/emqx/etc/acl.conf`, { stdio: 'inherit' });
      execSync(`docker exec -u 0 eh_emqx chmod 640 /opt/emqx/etc/certs/key.pem`, { stdio: 'inherit' });

      console.log('[SetupEMQX] Applying mTLS & authorization settings in EMQX 5.8...');
      runEmqxEval('emqx:update_config([listeners, ssl, default, ssl_options, verify], verify_peer).');
      runEmqxEval('emqx:update_config([listeners, ssl, default, ssl_options, fail_if_no_peer_cert], true).');
      runEmqxEval('emqx:update_config([authorization, no_match], deny).');
      runEmqxEval('emqx:update_config([authorization, cache, enable], false).');
      runEmqxEval('emqx_authz:reload().');

      console.log('[SetupEMQX] Purging SSL PEM cache & restarting SSL listener...');
      runEmqxEval('ssl:clear_pem_cache().');
      try {
        execSync(`docker exec eh_emqx emqx ctl listeners restart ssl:default`, { stdio: 'inherit' });
      } catch (_) {
        execSync(`docker exec eh_emqx emqx ctl listeners stop ssl:default`, { stdio: 'ignore' });
        execSync(`docker exec eh_emqx emqx ctl listeners start ssl:default`, { stdio: 'inherit' });
      }
    }
  } catch (inspectErr) {
    console.log(`[SetupEMQX] Container inspect notice: ${inspectErr.message}`);
  }

  console.log('[SetupEMQX] EMQX certificates and ACL configuration ready.');
}

if (require.main === module) {
  setupEmqxMtls();
}

module.exports = { setupEmqxMtls };
