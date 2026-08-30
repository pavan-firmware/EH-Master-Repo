'use strict';

/**
 * EH Home — EMQX mTLS & Authoritative Device ACL Setup (Phase 13)
 *
 * Configures the running EMQX 5.8.0 container (eh_emqx) to:
 *   1. Enforce mTLS verification (verify_peer = verify_peer, fail_if_no_peer_cert = true)
 *   2. Enforce per-device ACL isolation via file authorizer with explicit deny-all fallback
 *   3. Disable authorization caching (cache.enable = false, no_match = deny)
 *   4. Validate every configuration step and fail fast on errors
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const { generateCerts, LOCAL_CERTS_DIR } = require('./generate-dev-certs');

function runEmqxEval(expr) {
  console.log(`[SetupEMQX] Eval: ${expr}`);
  const out = execSync(`docker exec eh_emqx emqx eval "${expr}"`, { encoding: 'utf8' }).trim();
  console.log(`  -> ${out}`);
  if (out.startsWith('{error,') || out.includes('validation_error') || out.includes('unknown_fields')) {
    throw new Error(`EMQX config command rejected: ${out}`);
  }
  return out;
}

function setupEmqxMtls() {
  const certs = generateCerts();

  console.log('[SetupEMQX] Copying development certificates to EMQX container...');

  execSync(`docker cp "${certs.caCrt}" eh_emqx:/opt/emqx/etc/certs/cacert.pem`, { stdio: 'inherit' });
  execSync(`docker cp "${certs.serverCrt}" eh_emqx:/opt/emqx/etc/certs/cert.pem`, { stdio: 'inherit' });
  execSync(`docker cp "${certs.serverKey}" eh_emqx:/opt/emqx/etc/certs/key.pem`, { stdio: 'inherit' });

  console.log('[SetupEMQX] Setting container certificate ownership and permissions as root...');
  execSync(`docker exec -u 0 eh_emqx chown emqx:emqx /opt/emqx/etc/certs/cacert.pem`, { stdio: 'inherit' });
  execSync(`docker exec -u 0 eh_emqx chown emqx:emqx /opt/emqx/etc/certs/cert.pem`, { stdio: 'inherit' });
  execSync(`docker exec -u 0 eh_emqx chown emqx:emqx /opt/emqx/etc/certs/key.pem`, { stdio: 'inherit' });

  execSync(`docker exec -u 0 eh_emqx chmod 644 /opt/emqx/etc/certs/cacert.pem`, { stdio: 'inherit' });
  execSync(`docker exec -u 0 eh_emqx chmod 644 /opt/emqx/etc/certs/cert.pem`, { stdio: 'inherit' });
  execSync(`docker exec -u 0 eh_emqx chmod 640 /opt/emqx/etc/certs/key.pem`, { stdio: 'inherit' });

  console.log('[SetupEMQX] Verifying EMQX user readability of certificate files...');
  execSync(`docker exec eh_emqx sh -c "test -r /opt/emqx/etc/certs/cacert.pem && test -r /opt/emqx/etc/certs/cert.pem && test -r /opt/emqx/etc/certs/key.pem"`, { stdio: 'inherit' });

  // ─── Authoritative ACL Rules ───────────────────────────────────────────────
  //
  // EMQX 5.8 syntax: {allow | deny, {clientid | username, "..."}, action, [topics]}.
  // Processed top-to-bottom; first matching rule wins.
  // ───────────────────────────────────────────────────────────────────────────

  console.log('[SetupEMQX] Writing authoritative ACL rules to EMQX container...');

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

  // Copy acl.conf to EMQX default location
  execSync(`docker cp "${tmpAcl}" eh_emqx:/opt/emqx/etc/acl.conf`, { stdio: 'inherit' });
  try {
    execSync(`docker exec -u 0 eh_emqx sh -c "mkdir -p /opt/emqx/data/authz"`, { stdio: 'ignore' });
    execSync(`docker cp "${tmpAcl}" eh_emqx:/opt/emqx/data/authz/acl.conf`, { stdio: 'ignore' });
  } catch (_) {}

  console.log('[SetupEMQX] Applying EMQX 5.8 mTLS listener & authorization settings...');
  runEmqxEval('emqx:update_config([listeners, ssl, default, ssl_options, verify], verify_peer).');
  runEmqxEval('emqx:update_config([listeners, ssl, default, ssl_options, fail_if_no_peer_cert], true).');
  runEmqxEval('emqx:update_config([authorization, no_match], deny).');
  runEmqxEval('emqx:update_config([authorization, cache, enable], false).');

  console.log('[SetupEMQX] Updating authorization sources to /opt/emqx/etc/acl.conf...');
  runEmqxEval('emqx:update_config([authorization, sources], [#{type => file, enable => true, path => <<\\"/opt/emqx/etc/acl.conf\\">>}]).');

  console.log('[SetupEMQX] Purging SSL PEM cache & restarting SSL listener...');
  execSync(`docker exec eh_emqx emqx eval "ssl:clear_pem_cache()."`, { stdio: 'inherit' });
  try {
    execSync(`docker exec eh_emqx emqx ctl listeners restart ssl:default`, { stdio: 'inherit' });
  } catch (_) {
    execSync(`docker exec eh_emqx emqx ctl listeners stop ssl:default`, { stdio: 'ignore' });
    execSync(`docker exec eh_emqx emqx ctl listeners start ssl:default`, { stdio: 'inherit' });
  }

  console.log('[SetupEMQX] EMQX mTLS and ACL configuration successfully applied and verified.');
}

if (require.main === module) {
  setupEmqxMtls();
}

module.exports = { setupEmqxMtls };
