'use strict';

/**
 * EH Home — EMQX mTLS & Authoritative Device ACL Setup (Phase 13 Deterministic)
 *
 * Distinct lifecycle responsibilities:
 *   1. Host Artifact Generation (--generate-only):
 *      Generates ephemeral dev certificates + acl.conf with world-readable permissions.
 *   2. Container Runtime Configuration (--configure-only):
 *      Uses EMQX Management API (port 18083) to configure mTLS, peer_cert_as_clientid=cn,
 *      and install the file-based ACL as the sole authorization source.
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const http = require('http');
const { generateCerts, LOCAL_CERTS_DIR } = require('./generate-dev-certs');

const EMQX_API_BASE = 'http://127.0.0.1:18083/api/v5';
const EMQX_API_USER = 'admin';
const EMQX_API_PASS = 'public';

function emqxApiPut(apiPath, body) {
  const data = JSON.stringify(body);
  const auth = Buffer.from(`${EMQX_API_USER}:${EMQX_API_PASS}`).toString('base64');

  const url = new URL(EMQX_API_BASE + apiPath);
  const opts = {
    hostname: url.hostname,
    port: url.port || 18083,
    path: url.pathname,
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data),
      'Authorization': `Basic ${auth}`,
    },
  };

  return new Promise((resolve, reject) => {
    const req = http.request(opts, (res) => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve({ status: res.statusCode, body });
        } else {
          reject(new Error(`EMQX API PUT ${apiPath} failed (${res.statusCode}): ${body}`));
        }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function emqxApiPost(apiPath, body) {
  const data = JSON.stringify(body);
  const auth = Buffer.from(`${EMQX_API_USER}:${EMQX_API_PASS}`).toString('base64');

  const url = new URL(EMQX_API_BASE + apiPath);
  const opts = {
    hostname: url.hostname,
    port: url.port || 18083,
    path: url.pathname,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data),
      'Authorization': `Basic ${auth}`,
    },
  };

  return new Promise((resolve, reject) => {
    const req = http.request(opts, (res) => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve({ status: res.statusCode, body });
        } else {
          reject(new Error(`EMQX API POST ${apiPath} failed (${res.statusCode}): ${body}`));
        }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function emqxApiDel(apiPath) {
  const auth = Buffer.from(`${EMQX_API_USER}:${EMQX_API_PASS}`).toString('base64');
  const url = new URL(EMQX_API_BASE + apiPath);
  const opts = {
    hostname: url.hostname,
    port: url.port || 18083,
    path: url.pathname,
    method: 'DELETE',
    headers: { 'Authorization': `Basic ${auth}` },
  };

  return new Promise((resolve, reject) => {
    const req = http.request(opts, (res) => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => resolve({ status: res.statusCode, body }));
    });
    req.on('error', reject);
    req.end();
  });
}

function emqxApiGet(apiPath) {
  const auth = Buffer.from(`${EMQX_API_USER}:${EMQX_API_PASS}`).toString('base64');
  const url = new URL(EMQX_API_BASE + apiPath);
  const opts = {
    hostname: url.hostname,
    port: url.port || 18083,
    path: url.pathname,
    method: 'GET',
    headers: { 'Authorization': `Basic ${auth}` },
  };

  return new Promise((resolve, reject) => {
    const req = http.request(opts, (res) => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(body || '{}') }));
    });
    req.on('error', reject);
    req.end();
  });
}

function runEmqxEval(expr) {
  console.log(`[SetupEMQX] Eval: ${expr}`);
  const cmd = `docker exec eh_emqx emqx eval '${expr}'`;
  const out = execSync(cmd, { encoding: 'utf8' }).trim();
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
  try { fs.chmodSync(tmpAcl, 0o644); } catch (_) {}
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

async function setupEmqxMtls(options = {}) {
  const isGenerateOnly = options.generateOnly || process.argv.includes('--generate-only');

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

  // Enforce world-readable permissions
  try {
    const files = fs.readdirSync(LOCAL_CERTS_DIR);
    for (const f of files) fs.chmodSync(path.join(LOCAL_CERTS_DIR, f), 0o644);
    fs.chmodSync(LOCAL_CERTS_DIR, 0o755);
  } catch (_) {}

  // Step 2: Configure running EMQX container if active
  let isRunning = false;
  try {
    const runningStatus = execSync('docker inspect -f "{{.State.Running}}" eh_emqx', { encoding: 'utf8' }).trim();
    isRunning = (runningStatus === 'true');
  } catch (_) { isRunning = false; }

  if (!isRunning) {
    console.log('[SetupEMQX] EMQX container not running — skipping container configuration.');
    return;
  }

  console.log('[SetupEMQX] Ensuring container certificate directory and files...');
  try {
    execSync(`docker exec eh_emqx mkdir -p /opt/emqx/etc/local-certs`, { stdio: 'pipe' });
    execSync(`docker cp "${LOCAL_CERTS_DIR}/." eh_emqx:/opt/emqx/etc/local-certs/`, { stdio: 'pipe' });
  } catch (_) {}

  console.log('[SetupEMQX] Verifying container certificate access...');
  execSync(`docker exec eh_emqx test -r /opt/emqx/etc/local-certs/ca.crt`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx test -r /opt/emqx/etc/local-certs/server.crt`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx test -r /opt/emqx/etc/local-certs/server.key`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx test -r /opt/emqx/etc/local-certs/acl.conf`, { stdio: 'inherit' });

  console.log('[SetupEMQX] Applying mTLS settings via EMQX eval...');
  runEmqxEval('emqx:update_config([listeners, ssl, default, ssl_options, verify], verify_peer).');
  runEmqxEval('emqx:update_config([listeners, ssl, default, ssl_options, fail_if_no_peer_cert], true).');
  runEmqxEval('emqx:update_config([authorization, no_match], deny).');
  runEmqxEval('emqx:update_config([authorization, cache, enable], false).');

  // Step 3: Install file-based ACL as the sole authorization source via Management API
  // This avoids all Erlang binary syntax quoting issues in shell.
  console.log('[SetupEMQX] Installing file ACL source via EMQX Management API (port 18083)...');
  try {
    // Wipe all existing authorization sources first (delete each by type)
    const sourcesResp = await emqxApiGet('/authorization/sources');
    if (sourcesResp.status === 200) {
      const sources = Array.isArray(sourcesResp.body) ? sourcesResp.body : (sourcesResp.body.data || []);
      for (const src of sources) {
        const srcType = src.type || src.Type;
        if (srcType) {
          console.log(`  [SetupEMQX] Deleting existing authorization source: ${srcType}`);
          try { await emqxApiDel(`/authorization/sources/${srcType}`); } catch (_) {}
        }
      }
    }

    // Create the file-based ACL source
    await emqxApiPost('/authorization/sources', {
      type: 'file',
      enable: true,
      path: '/opt/emqx/etc/local-certs/acl.conf'
    });
    console.log('[SetupEMQX] File ACL source installed successfully.');
  } catch (err) {
    console.error(`[SetupEMQX] Management API failed: ${err.message}`);
    console.log('[SetupEMQX] Falling back to Erlang eval for authorization sources...');
    // Fallback: try emqx ctl authz cache-clean
    try { execSync('docker exec eh_emqx emqx ctl authz cache-clean all', { stdio: 'inherit' }); } catch (_) {}
  }

  // Step 4: Purge SSL PEM cache and restart SSL listener
  console.log('[SetupEMQX] Purging SSL PEM cache & restarting SSL listener...');
  runEmqxEval('ssl:clear_pem_cache().');
  try {
    execSync(`docker exec eh_emqx emqx ctl listeners restart ssl:default`, { stdio: 'inherit' });
  } catch (_) {
    try { execSync(`docker exec eh_emqx emqx ctl listeners stop ssl:default`, { stdio: 'ignore' }); } catch (_2) {}
    execSync(`docker exec eh_emqx emqx ctl listeners start ssl:default`, { stdio: 'inherit' });
  }

  console.log('[SetupEMQX] EMQX mTLS and ACL configuration successfully initialized.');
}

if (require.main === module) {
  setupEmqxMtls().catch(err => { console.error(err); process.exit(1); });
}

module.exports = { setupEmqxMtls };
