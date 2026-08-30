'use strict';

/**
 * EH Home — EMQX mTLS & ACL Setup Helper (Phase 13 Hardened)
 *
 * Configures the running EMQX 5.8.0 container (eh_emqx) to:
 *   1. Require valid client certificates signed by EH Dev Root CA (verify_peer)
 *   2. Enforce per-device ACL isolation via acl.conf using EMQX 5.x cert_common_name, clientid & username matching
 *   3. Configure authorization settings (no_match = deny, cache.enable = false) via EMQX 5.x REST API from host
 *
 * Security & Reliability:
 *   - Uses host-side Node.js HTTP client to configure EMQX 5.8 REST API on port 18083 (zero wget container dependencies)
 *   - Configures mTLS listener with verify_peer and fail_if_no_peer_cert = true
 *   - Reloads authorization sources deterministically
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const http = require('http');
const { generateCerts, LOCAL_CERTS_DIR } = require('./generate-dev-certs');

function emqxApiRequest(method, apiPath, body = null) {
  return new Promise((resolve) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = http.request({
      hostname: '127.0.0.1',
      port: 18083,
      path: apiPath,
      method: method,
      headers: {
        'Authorization': 'Basic ' + Buffer.from('admin:public').toString('base64'),
        'Content-Type': 'application/json',
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {})
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        resolve({ statusCode: res.statusCode, body: data });
      });
    });

    req.on('error', (err) => {
      resolve({ statusCode: 0, error: err.message });
    });

    if (payload) req.write(payload);
    req.end();
  });
}

async function setupEmqxMtlsAsync() {
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
  // EMQX 5.x syntax: use {cert_common_name, "..."}, {clientid, "..."}, and {username, "..."}.
  // Processed top-to-bottom; first matching rule wins.
  // ───────────────────────────────────────────────────────────────────────────

  console.log('[SetupEMQX] Writing ACL rules to EMQX container (EMQX 5.x syntax)...');

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

%% 2. Device A — per-device topic isolation (CN / ClientId / Username = ${DEVICE_A_ID})
{allow, {cert_common_name, "${DEVICE_A_ID}"}, subscribe, ["eh/v1/devices/${DEVICE_A_ID}/commands"]}.
{allow, {cert_common_name, "${DEVICE_A_ID}"}, publish, [
  "eh/v1/devices/${DEVICE_A_ID}/command-receipts",
  "eh/v1/devices/${DEVICE_A_ID}/state",
  "eh/v1/devices/${DEVICE_A_ID}/events",
  "eh/v1/devices/${DEVICE_A_ID}/telemetry",
  "eh/v1/devices/${DEVICE_A_ID}/availability"
]}.
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

%% 3. Device B — per-device topic isolation (CN / ClientId / Username = ${DEVICE_B_ID})
{allow, {cert_common_name, "${DEVICE_B_ID}"}, subscribe, ["eh/v1/devices/${DEVICE_B_ID}/commands"]}.
{allow, {cert_common_name, "${DEVICE_B_ID}"}, publish, [
  "eh/v1/devices/${DEVICE_B_ID}/command-receipts",
  "eh/v1/devices/${DEVICE_B_ID}/state",
  "eh/v1/devices/${DEVICE_B_ID}/events",
  "eh/v1/devices/${DEVICE_B_ID}/telemetry",
  "eh/v1/devices/${DEVICE_B_ID}/availability"
]}.
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

%% 4. Final deny-all
{deny, all}.
`;

  const tmpAcl = path.join(LOCAL_CERTS_DIR, 'acl.conf');
  fs.writeFileSync(tmpAcl, aclContent, 'utf8');

  // Copy acl.conf to EMQX default location
  execSync(`docker cp "${tmpAcl}" eh_emqx:/opt/emqx/etc/acl.conf`, { stdio: 'inherit' });

  console.log('[SetupEMQX] Configuring EMQX mTLS listener via emqx eval...');
  execSync(`docker exec eh_emqx emqx eval "emqx:update_config([listeners, ssl, default, ssl_options, verify], verify_peer)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx:update_config([listeners, ssl, default, ssl_options, fail_if_no_peer_cert], true)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx:update_config([authorization, no_match], deny)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx:update_config([authorization, cache, enable], false)."`, { stdio: 'inherit' });

  console.log('[SetupEMQX] Configuring EMQX Authorization via REST API from host...');
  // Configure authorization settings: no_match: deny, cache: false
  const settingsRes = await emqxApiRequest('PUT', '/api/v5/authorization/settings', {
    no_match: 'deny',
    deny_action: 'ignore',
    cache: { enable: false }
  });
  console.log(`[SetupEMQX] Authorization settings update: status ${settingsRes.statusCode}`);

  // Configure authorization source: file /opt/emqx/etc/acl.conf
  const sourcesRes = await emqxApiRequest('PUT', '/api/v5/authorization/sources', [
    { type: 'file', enable: true, path: '/opt/emqx/etc/acl.conf' }
  ]);
  console.log(`[SetupEMQX] Authorization sources update: status ${sourcesRes.statusCode}`);

  // Clear authorization cache
  await emqxApiRequest('DELETE', '/api/v5/authorization/cache');

  console.log('[SetupEMQX] Purging Erlang SSL PEM cache & restarting SSL listener...');
  execSync(`docker exec eh_emqx emqx eval "ssl:clear_pem_cache()."`, { stdio: 'inherit' });
  try {
    execSync(`docker exec eh_emqx emqx ctl listeners restart ssl:default`, { stdio: 'inherit' });
  } catch (_) {
    execSync(`docker exec eh_emqx emqx ctl listeners stop ssl:default`, { stdio: 'ignore' });
    execSync(`docker exec eh_emqx emqx ctl listeners start ssl:default`, { stdio: 'inherit' });
  }

  console.log('[SetupEMQX] EMQX mTLS and ACL configuration applied successfully.');
}

function setupEmqxMtls() {
  const isAsync = setupEmqxMtlsAsync();
  if (isAsync && typeof isAsync.then === 'function') {
    // If called synchronously in CJS script
    return isAsync;
  }
}

if (require.main === module) {
  setupEmqxMtlsAsync().catch((err) => {
    console.error('[SetupEMQX] Error:', err);
    process.exit(1);
  });
}

module.exports = { setupEmqxMtls: setupEmqxMtlsAsync, setupEmqxMtlsAsync };
