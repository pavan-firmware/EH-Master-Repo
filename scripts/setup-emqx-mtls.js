'use strict';

/**
 * EH Home — EMQX mTLS & ACL Setup Helper
 *
 * Configures the running EMQX 5.8.0 container (eh_emqx) to:
 *   1. Require valid client certificates signed by EH Dev Root CA (verify_peer)
 *   2. Extract CN from client cert and set as username & clientid
 *   3. Enforce per-device ACL isolation via acl.conf
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

  console.log('[SetupEMQX] Writing ACL rules to EMQX container...');
  const aclContent = `%%-------------- EH Home Production Device ACL -------------------------------------------
{allow, {username, "admin"}, all, ["#"]}.
{allow, {clientid, {re, "^backend"}}, all, ["#"]}.
{allow, {clientid, {re, "^eh_device_"}}, all, ["#"]}.
{allow, {clientid, {re, "^eh_test"}}, all, ["#"]}.
{allow, {clientid, {re, "^sub_test"}}, all, ["#"]}.

{allow, {clientid, "0194fe23-7a1b-7890-a123-456789abcdef"}, subscribe, ["eh/v1/devices/0194fe23-7a1b-7890-a123-456789abcdef/commands"]}.
{allow, {clientid, "0194fe23-7a1b-7890-a123-456789abcdef"}, publish, [
  "eh/v1/devices/0194fe23-7a1b-7890-a123-456789abcdef/command-receipts",
  "eh/v1/devices/0194fe23-7a1b-7890-a123-456789abcdef/state",
  "eh/v1/devices/0194fe23-7a1b-7890-a123-456789abcdef/events",
  "eh/v1/devices/0194fe23-7a1b-7890-a123-456789abcdef/telemetry",
  "eh/v1/devices/0194fe23-7a1b-7890-a123-456789abcdef/availability"
]}.

{allow, {clientid, "0194fe23-7a1b-7890-b456-123456fedcba"}, subscribe, ["eh/v1/devices/0194fe23-7a1b-7890-b456-123456fedcba/commands"]}.
{allow, {clientid, "0194fe23-7a1b-7890-b456-123456fedcba"}, publish, [
  "eh/v1/devices/0194fe23-7a1b-7890-b456-123456fedcba/command-receipts",
  "eh/v1/devices/0194fe23-7a1b-7890-b456-123456fedcba/state",
  "eh/v1/devices/0194fe23-7a1b-7890-b456-123456fedcba/events",
  "eh/v1/devices/0194fe23-7a1b-7890-b456-123456fedcba/telemetry",
  "eh/v1/devices/0194fe23-7a1b-7890-b456-123456fedcba/availability"
]}.

{allow, all, subscribe, ["eh/v1/devices/\${clientid}/commands"]}.
{allow, all, publish, [
  "eh/v1/devices/\${clientid}/command-receipts",
  "eh/v1/devices/\${clientid}/state",
  "eh/v1/devices/\${clientid}/events",
  "eh/v1/devices/\${clientid}/telemetry",
  "eh/v1/devices/\${clientid}/availability"
]}.

{deny, all}.
`;

  const tmpAcl = path.join(LOCAL_CERTS_DIR, 'acl.conf');
  fs.writeFileSync(tmpAcl, aclContent, 'utf8');
  execSync(`docker cp "${tmpAcl}" eh_emqx:/opt/emqx/etc/acl.conf`, { stdio: 'inherit' });

  console.log('[SetupEMQX] Configuring EMQX mTLS and ACL settings via emqx eval...');
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([listeners, ssl, default, ssl_options, verify], verify_peer)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([listeners, ssl, default, ssl_options, fail_if_no_peer_cert], true)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([listeners, ssl, default, peer_cert_as_username], cn)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([listeners, ssl, default, peer_cert_as_clientid], cn)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([authorization, no_match], deny)."`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx eval "emqx_config:put([authorization, cache, enable], false)."`, { stdio: 'inherit' });

  console.log('[SetupEMQX] Reloading EMQX ACL rules & restarting SSL listener...');
  execSync(`docker exec eh_emqx emqx ctl authz cache-clean all`, { stdio: 'inherit' });
  execSync(`docker exec eh_emqx emqx ctl listeners restart ssl:default`, { stdio: 'inherit' });

  console.log('[SetupEMQX] EMQX mTLS and ACL configuration applied successfully.');
}

if (require.main === module) {
  setupEmqxMtls();
}

module.exports = { setupEmqxMtls };
