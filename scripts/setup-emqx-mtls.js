'use strict';

/**
 * EH Home — EMQX mTLS & Authoritative Device ACL Setup (Phase 13 Deterministic)
 *
 * Distinct lifecycle responsibilities:
 *   1. Host Artifact Generation (--generate-only):
 *      Generates ephemeral development certificates in .local-certs/ and writes acl.conf.
 *   2. Container Runtime Configuration (--configure-only):
 *      Inspects running EMQX broker, verifies mounted certificates, and activates mTLS + ACL.
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const { generateCerts, LOCAL_CERTS_DIR } = require('./generate-dev-certs');

function runEmqxEval(expr) {
  console.log(`[SetupEMQX] Eval: ${expr}`);
  const out = execSync(`docker exec eh_emqx emqx eval "${expr}"`, { encoding: 'utf8' }).trim();
  console.log(`  -> ${out}`);
  if (out.startsWith('{error,') && !out.includes('already_exists')) {
    throw new Error(`EMQX config command rejected: ${out}`);
  }
  return out;
}

function writeAclFile() {
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
  return tmpAcl;
}

function verifyHostFilesExist() {
  const required = [
    'ca.crt', 'server.crt', 'server.key',
    'device_a.crt', 'device_a.key',
    'device_b.crt', 'device_b.key',
    'acl.conf'
  ];

  for (const file of required) {
    const filePath = path.join(LOCAL_CERTS_DIR, file);
    if (!fs.existsSync(filePath)) {
      throw new Error(`Required local cert fixture missing: ${filePath}`);
    }
  }
}

function setupEmqxMtls(options = {}) {
  const isGenerateOnly = options.generateOnly || process.argv.includes('--generate-only');
  const isConfigureOnly = options.configureOnly || process.argv.includes('--configure-only');

  // Step 1: Ensure certificates and ACL exist on host
  if (isGenerateOnly || !fs.existsSync(path.join(LOCAL_CERTS_DIR, 'ca.crt'))) {
    generateCerts({ force: isGenerateOnly });
    writeAclFile();
    verifyHostFilesExist();
    console.log('[SetupEMQX] Host development certificates & ACL generated successfully.');
    if (isGenerateOnly) return;
  } else {
    writeAclFile();
    verifyHostFilesExist();
  }

  // Step 2: Configure running EMQX container if active
  let isRunning = false;
  try {
    const runningStatus = execSync('docker inspect -f "{{.State.Running}}" eh_emqx', { encoding: 'utf8' }).trim();
    isRunning = (runningStatus === 'true');
  } catch (_) {
    isRunning = false;
  }

  if (isRunning) {
    console.log('[SetupEMQX] Verifying container certificate access at /opt/emqx/etc/local-certs/ca.crt...');
    let hasMountedCerts = false;
    try {
      execSync(`docker exec eh_emqx test -r /opt/emqx/etc/local-certs/ca.crt`, { stdio: 'ignore' });
      hasMountedCerts = true;
    } catch (_) {
      hasMountedCerts = false;
    }

    if (!hasMountedCerts) {
      console.log('[SetupEMQX] Fallback copy into unmounted container directory...');
      execSync(`docker exec -u 0 eh_emqx mkdir -p /opt/emqx/etc/local-certs`, { stdio: 'inherit' });
      execSync(`docker cp "${path.join(LOCAL_CERTS_DIR, 'ca.crt')}" eh_emqx:/opt/emqx/etc/local-certs/ca.crt`, { stdio: 'inherit' });
      execSync(`docker cp "${path.join(LOCAL_CERTS_DIR, 'server.crt')}" eh_emqx:/opt/emqx/etc/local-certs/server.crt`, { stdio: 'inherit' });
      execSync(`docker cp "${path.join(LOCAL_CERTS_DIR, 'server.key')}" eh_emqx:/opt/emqx/etc/local-certs/server.key`, { stdio: 'inherit' });
      execSync(`docker cp "${path.join(LOCAL_CERTS_DIR, 'acl.conf')}" eh_emqx:/opt/emqx/etc/local-certs/acl.conf`, { stdio: 'inherit' });
      execSync(`docker exec -u 0 eh_emqx chown -R emqx:emqx /opt/emqx/etc/local-certs`, { stdio: 'inherit' });
      execSync(`docker exec -u 0 eh_emqx chmod 644 /opt/emqx/etc/local-certs/ca.crt /opt/emqx/etc/local-certs/server.crt /opt/emqx/etc/local-certs/acl.conf`, { stdio: 'inherit' });
      execSync(`docker exec -u 0 eh_emqx chmod 640 /opt/emqx/etc/local-certs/server.key`, { stdio: 'inherit' });
    }

    // Verify container user can read required files
    execSync(`docker exec eh_emqx test -r /opt/emqx/etc/local-certs/ca.crt`, { stdio: 'inherit' });
    execSync(`docker exec eh_emqx test -r /opt/emqx/etc/local-certs/server.crt`, { stdio: 'inherit' });
    execSync(`docker exec eh_emqx test -r /opt/emqx/etc/local-certs/server.key`, { stdio: 'inherit' });

    console.log('[SetupEMQX] Applying mTLS & authorization settings in EMQX 5.8...');
    runEmqxEval('emqx:update_config([listeners, ssl, default, ssl_options, cacertfile], <<"/opt/emqx/etc/local-certs/ca.crt">>).');
    runEmqxEval('emqx:update_config([listeners, ssl, default, ssl_options, certfile], <<"/opt/emqx/etc/local-certs/server.crt">>).');
    runEmqxEval('emqx:update_config([listeners, ssl, default, ssl_options, keyfile], <<"/opt/emqx/etc/local-certs/server.key">>).');
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

  console.log('[SetupEMQX] EMQX certificates and ACL configuration successfully initialized.');
}

if (require.main === module) {
  setupEmqxMtls();
}

module.exports = { setupEmqxMtls };
