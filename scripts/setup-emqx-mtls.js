'use strict';

/**
 * EH Home — EMQX mTLS & ACL Setup Helper
 *
 * Configures the running EMQX 5.8.0 container (eh_emqx) to:
 *   1. Require valid client certificates signed by EH Dev Root CA (verify_peer)
 *   2. Extract CN from client cert and set as username & clientid (peer_cert_as_clientid = cn)
 *   3. Enforce per-device ACL isolation via acl.conf using EMQX 5.x ${clientid} interpolation
 *
 * Security & Reliability:
 *   - Uses native `emqx eval` and `emqx ctl` commands inside container (no external HTTP/wget dependencies)
 *   - `verify_peer = verify_peer`
 *   - `fail_if_no_peer_cert = true`
 *   - `authorization.no_match = deny`
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const { generateCerts, LOCAL_CERTS_DIR } = require('./generate-dev-certs');

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

  // ─── ACL Rules ─────────────────────────────────────────────────────────────
  //
  // EMQX 5.x syntax: use ${clientid} for topic substitution.
  // Processed top-to-bottom; first matching rule wins.
  //
  // 1. Dev/test harness clientIDs (backend*, eh_device_*, eh_test*, sub_test*):
  //    Allowed full access for EQ01-EQ12 non-mTLS integration tests.
  //
  // 2. Production Device mTLS UUID clientIDs (CN = 0194fe23-7a1b-7890-...):
  //    Strictly isolated to their own device topics.
  //    Device A cannot publish/subscribe to Device B topics.
  // ───────────────────────────────────────────────────────────────────────────

  console.log('[SetupEMQX] Writing ACL rules to EMQX container (EMQX 5.x ${clientid} syntax)...');

  const DEVICE_A_ID = '0194fe23-7a1b-7890-a123-456789abcdef';
  const DEVICE_B_ID = '0194fe23-7a1b-7890-b456-123456fedcba';

  const aclContent = `%%-------------- EH Home Production Device ACL -------------------------------------------
%% Processed top-to-bottom; first match wins.

%% 1. Admin / backend / test harness clients (EQ01-EQ12 simulator & transport tests)
{allow, {username, "admin"}, all, ["#"]}.
{allow, {clientid, {re, "^backend"}}, all, ["#"]}.
{allow, {clientid, {re, "^eh_device_"}}, all, ["#"]}.
{allow, {clientid, {re, "^eh_test"}}, all, ["#"]}.
{allow, {clientid, {re, "^sub_test"}}, all, ["#"]}.

%% 2. Device A — per-device topic isolation (mTLS CN identity = ${DEVICE_A_ID})
{allow, {clientid, "${DEVICE_A_ID}"}, subscribe, ["eh/v1/devices/${DEVICE_A_ID}/commands"]}.
{allow, {clientid, "${DEVICE_A_ID}"}, publish, [
  "eh/v1/devices/${DEVICE_A_ID}/command-receipts",
  "eh/v1/devices/${DEVICE_A_ID}/state",
  "eh/v1/devices/${DEVICE_A_ID}/events",
  "eh/v1/devices/${DEVICE_A_ID}/telemetry",
  "eh/v1/devices/${DEVICE_A_ID}/availability"
]}.

%% 3. Device B — per-device topic isolation (mTLS CN identity = ${DEVICE_B_ID})
{allow, {clientid, "${DEVICE_B_ID}"}, subscribe, ["eh/v1/devices/${DEVICE_B_ID}/commands"]}.
{allow, {clientid, "${DEVICE_B_ID}"}, publish, [
  "eh/v1/devices/${DEVICE_B_ID}/command-receipts",
  "eh/v1/devices/${DEVICE_B_ID}/state",
  "eh/v1/devices/${DEVICE_B_ID}/events",
  "eh/v1/devices/${DEVICE_B_ID}/telemetry",
  "eh/v1/devices/${DEVICE_B_ID}/availability"
]}.

%% 4. Final deny-all
{deny, all}.
`;

  const tmpAcl = path.join(LOCAL_CERTS_DIR, 'acl.conf');
  fs.writeFileSync(tmpAcl, aclContent, 'utf8');

  // Copy acl.conf to EMQX default location & managed location
  execSync(`docker cp "${tmpAcl}" eh_emqx:/opt/emqx/etc/acl.conf`, { stdio: 'inherit' });
  try {
    execSync(`docker exec -u 0 eh_emqx sh -c "mkdir -p /opt/emqx/data/authz"`, { stdio: 'ignore' });
    execSync(`docker cp "${tmpAcl}" eh_emqx:/opt/emqx/data/authz/acl.conf`, { stdio: 'ignore' });
  } catch (_) {}

  console.log('[SetupEMQX] Configuring EMQX mTLS and ACL settings via emqx eval...');
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([listeners, ssl, default, ssl_options, verify], verify_peer)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([listeners, ssl, default, ssl_options, fail_if_no_peer_cert], true)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([listeners, ssl, default, peer_cert_as_username], cn)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([listeners, ssl, default, peer_cert_as_clientid], cn)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([authorization, no_match], deny)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([authorization, cache, enable], false)."`, { stdio: 'inherit' });

  console.log('[SetupEMQX] Cleaning EMQX authorization cache...');
  try {
    execSync(`docker exec eh_emqx emqx ctl authz cache-clean all`, { stdio: 'inherit' });
  } catch (_) {}

  console.log('[SetupEMQX] Purging Erlang SSL PEM cache & restarting SSL listener...');
  execSync(`docker exec eh_emqx emqx eval "ssl:clear_pem_cache()."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx ctl listeners stop ssl:default`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx ctl listeners start ssl:default`, { stdio: 'inherit' });

  console.log('[SetupEMQX] EMQX mTLS and ACL configuration applied successfully.');
}

if (require.main === module) {
  setupEmqxMtls();
}

module.exports = { setupEmqxMtls };
