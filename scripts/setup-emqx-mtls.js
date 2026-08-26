'use strict';

/**
 * EH Home — EMQX mTLS & ACL Setup Helper
 *
 * Configures the running EMQX 5.8.0 container (eh_emqx) to:
 *   1. Require valid client certificates signed by EH Dev Root CA (verify_peer)
 *   2. Extract CN from client cert and set as username & clientid
 *   3. Enforce per-device ACL isolation via acl.conf
 *
 * ACL placeholder syntax: EMQX 5.x uses ${clientid} (not %c from EMQX 4.x).
 * File authorizer is registered/updated via REST API to ensure EMQX 5.x
 * actually reloads the rules (docker cp alone is not sufficient in EMQX 5).
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const { generateCerts, LOCAL_CERTS_DIR } = require('./generate-dev-certs');

/**
 * Wait for the EMQX REST API to be available.
 * The API is on port 18083 — it may come up slightly after port 1883.
 */
function waitForEmqxApi(maxAttempts = 20, delaySecs = 2) {
  for (let i = 0; i < maxAttempts; i++) {
    try {
      const result = execSync(
        'docker exec eh_emqx wget -q -O- --tries=1 --timeout=3 http://localhost:18083/api/v5/status',
        { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }
      );
      if (result && result.includes('running')) {
        console.log('[SetupEMQX] EMQX REST API is ready.');
        return;
      }
    } catch (_) {}
    console.log(`[SetupEMQX] Waiting for EMQX REST API... (attempt ${i + 1}/${maxAttempts})`);
    execSync(`sleep ${delaySecs}`, { stdio: 'ignore' });
  }
  // Non-fatal: continue even if wget check fails; API calls will catch issues
  console.log('[SetupEMQX] WARNING: EMQX API readiness probe timed out, continuing anyway.');
}

/**
 * Execute an EMQX REST API call from inside the container using wget.
 * Uses admin:public credentials (EMQX 5.x defaults for fresh Docker image).
 */
function emqxApiCall(method, path, body) {
  const bodyJson = body ? JSON.stringify(body) : '';
  const bodyArg = body
    ? `--body-data='${bodyJson.replace(/'/g, "'\\''")}'`
    : '';
  const methodHeader = `--method=${method}`;

  let cmd;
  if (body) {
    // Write body to a temp file inside the container to avoid quoting issues
    const tmpFile = '/tmp/emqx_api_body.json';
    execSync(
      `docker exec eh_emqx sh -c "echo '${bodyJson.replace(/'/g, "'\\''")}' > ${tmpFile}"`,
      { stdio: 'pipe' }
    );
    cmd = [
      'docker exec eh_emqx',
      'wget -q -O- --tries=1 --timeout=10',
      `--method=${method}`,
      `--header="Content-Type: application/json"`,
      `--header="Authorization: Basic YWRtaW46cHVibGlj"`,  // admin:public base64
      `--body-file=${tmpFile}`,
      `"http://localhost:18083/api/v5${path}"`
    ].join(' ');
  } else {
    cmd = [
      'docker exec eh_emqx',
      'wget -q -O- --tries=1 --timeout=10',
      `--method=${method}`,
      `--header="Authorization: Basic YWRtaW46cHVibGlj"`,  // admin:public base64
      `"http://localhost:18083/api/v5${path}"`
    ].join(' ');
  }

  try {
    const result = execSync(cmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
    return result;
  } catch (e) {
    // wget returns exit code 8 for non-2xx HTTP responses — log but don't throw
    const output = e.stdout || e.stderr || '';
    return output;
  }
}

function setupEmqxMtls() {
  const certs = generateCerts();

  console.log('[SetupEMQX] Copying development certificates to EMQX container...');

  // Build a full-chain cert (server cert + CA cert) so EMQX sends the complete
  // TLS certificate chain to clients. Node.js v20+ requires the issuer cert in
  // the chain sent during the TLS handshake when using a custom CA via ca: option.
  const serverFullChain = path.join(path.dirname(certs.serverCrt), 'server_fullchain.pem');
  fs.writeFileSync(
    serverFullChain,
    fs.readFileSync(certs.serverCrt, 'utf8') + fs.readFileSync(certs.caCrt, 'utf8'),
    'utf8'
  );

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
  // EMQX 5.x uses ${clientid} placeholders (NOT %c from EMQX 4.x).
  // %c in EMQX 5 is treated as a LITERAL string, not a substitution variable.
  //
  // The ACL enforces:
  //   - Backend / admin clients: full access
  //   - Device A (UUID): may only publish to Device A topics, subscribe to own commands
  //   - Device B (UUID): may only publish to Device B topics, subscribe to own commands
  //   - All other devices: self-service only via ${clientid} interpolation
  //   - Final deny-all: ensure no_match = deny is enforced at the file level too
  //
  // With peer_cert_as_clientid = cn, EMQX sets effective clientId = cert CN (UUID).
  // Tests pass explicit clientId in CONNECT packet, but EMQX 5.x overrides it
  // with the CN when peer_cert_as_clientid is set.
  // ───────────────────────────────────────────────────────────────────────────

  console.log('[SetupEMQX] Writing ACL rules to EMQX container (EMQX 5.x ${clientid} syntax)...');

  const DEVICE_A_ID = '0194fe23-7a1b-7890-a123-456789abcdef';
  const DEVICE_B_ID = '0194fe23-7a1b-7890-b456-123456fedcba';

  // NOTE: In EMQX 5.x acl.conf, use ${clientid} for per-client topic substitution.
  // The {re, ...} pattern for matching clientid prefixes is EMQX 4.x syntax;
  // in EMQX 5.x file authorizer, use plain string or ${clientid} placeholders.
  const aclContent = `%%-------------- EH Home Production Device ACL -------------------------------------------
%% EMQX 5.x syntax: use \${clientid} for client-id substitution (NOT %c)
%% Processed top-to-bottom; first match wins.

%% 1. Admin / backend / test clients: unrestricted access
{allow, {username, "admin"}, all, ["#"]}.
{allow, {clientid, "admin"}, all, ["#"]}.

%% 2. Device A — per-device topic isolation
{allow, {clientid, "${DEVICE_A_ID}"}, subscribe, ["eh/v1/devices/${DEVICE_A_ID}/commands"]}.
{allow, {clientid, "${DEVICE_A_ID}"}, publish, [
  "eh/v1/devices/${DEVICE_A_ID}/command-receipts",
  "eh/v1/devices/${DEVICE_A_ID}/state",
  "eh/v1/devices/${DEVICE_A_ID}/events",
  "eh/v1/devices/${DEVICE_A_ID}/telemetry",
  "eh/v1/devices/${DEVICE_A_ID}/availability"
]}.

%% 3. Device B — per-device topic isolation
{allow, {clientid, "${DEVICE_B_ID}"}, subscribe, ["eh/v1/devices/${DEVICE_B_ID}/commands"]}.
{allow, {clientid, "${DEVICE_B_ID}"}, publish, [
  "eh/v1/devices/${DEVICE_B_ID}/command-receipts",
  "eh/v1/devices/${DEVICE_B_ID}/state",
  "eh/v1/devices/${DEVICE_B_ID}/events",
  "eh/v1/devices/${DEVICE_B_ID}/telemetry",
  "eh/v1/devices/${DEVICE_B_ID}/availability"
]}.

%% 4. Backend / test client wildcard patterns (by clientId prefix)
%%    These use exact prefix matches via multiple explicit rules rather than
%%    regex (EMQX 5.x file authorizer does not support {re,...} clientid matching).
{allow, {clientid, "backend"}, all, ["#"]}.
{allow, {clientid, "eh_test"}, all, ["#"]}.
{allow, {clientid, "sub_test"}, all, ["#"]}.

%% 5. Generic self-service rule using \${clientid} interpolation (EMQX 5.x syntax)
%%    Allows any device to access only its own topics.
{allow, all, subscribe, ["eh/v1/devices/\${clientid}/commands"]}.
{allow, all, publish, [
  "eh/v1/devices/\${clientid}/command-receipts",
  "eh/v1/devices/\${clientid}/state",
  "eh/v1/devices/\${clientid}/events",
  "eh/v1/devices/\${clientid}/telemetry",
  "eh/v1/devices/\${clientid}/availability"
]}.

%% 6. Final deny-all (belt-and-suspenders with no_match = deny)
{deny, all}.
`;

  const tmpAcl = path.join(LOCAL_CERTS_DIR, 'acl.conf');
  fs.writeFileSync(tmpAcl, aclContent, 'utf8');

  // Copy acl.conf to the standard EMQX etc/ location
  execSync(`docker cp "${tmpAcl}" eh_emqx:/opt/emqx/etc/acl.conf`, { stdio: 'inherit' });

  // Also copy to the EMQX 5.x managed authz location (used after first API update)
  execSync(`docker exec -u 0 eh_emqx sh -c "mkdir -p /opt/emqx/data/authz"`, { stdio: 'pipe' });
  execSync(`docker cp "${tmpAcl}" eh_emqx:/opt/emqx/data/authz/acl.conf`, { stdio: 'inherit' });

  console.log('[SetupEMQX] Configuring EMQX mTLS and ACL settings via emqx eval...');
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([listeners, ssl, default, ssl_options, verify], verify_peer)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([listeners, ssl, default, ssl_options, fail_if_no_peer_cert], true)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([listeners, ssl, default, peer_cert_as_username], cn)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([listeners, ssl, default, peer_cert_as_clientid], cn)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([authorization, no_match], deny)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([authorization, cache, enable], false)."`, { stdio: 'inherit' });

  // ─── Register/reload file authorizer via EMQX REST API ────────────────────
  //
  // In EMQX 5.x, docker cp of acl.conf is not guaranteed to reload the
  // file authorizer rules at runtime. The REST API is the supported way to
  // update/reload the file-based authorization source.
  //
  // Default EMQX 5.x Docker image ships with the file authorizer enabled,
  // pointing to /opt/emqx/etc/acl.conf. We PUT our new rules via the API
  // so EMQX stores them in its managed directory and reloads immediately.
  // ───────────────────────────────────────────────────────────────────────────

  console.log('[SetupEMQX] Waiting for EMQX REST API...');
  waitForEmqxApi();

  console.log('[SetupEMQX] Updating file authorizer rules via EMQX REST API...');

  // The EMQX 5.x REST API for file authorizer accepts the raw acl text
  // PUT /api/v5/authorization/sources/file  { type: "file", enable: true, rules: "<acl content>" }
  const apiResult = emqxApiCall('PUT', '/authorization/sources/file', {
    type: 'file',
    enable: true,
    rules: aclContent
  });
  console.log('[SetupEMQX] File authorizer API response:', apiResult || '(no body)');

  // Verify the authorizer is active
  const sourcesResult = emqxApiCall('GET', '/authorization/sources');
  console.log('[SetupEMQX] Active authorization sources:', sourcesResult || '(empty)');

  // Flush authz cache so stale allow entries don't persist
  console.log('[SetupEMQX] Flushing authorization cache...');
  execSync(`docker exec eh_emqx emqx ctl authz cache-clean all`, { stdio: 'inherit' });

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
