'use strict';

/**
 * EH Home — Ephemeral Development Cert Generator for EMQX mTLS & ACL Tests
 *
 * Generates temporary development X.509 certificates in `.local-certs/` (ignored by git).
 * NO PRODUCTION OR MANUFACTURING PRIVATE KEYS ARE COMMITTED.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const LOCAL_CERTS_DIR = path.join(__dirname, '..', '.local-certs');

function generateCerts() {
  if (!fs.existsSync(LOCAL_CERTS_DIR)) {
    fs.mkdirSync(LOCAL_CERTS_DIR, { recursive: true });
  }

  const caKey = path.join(LOCAL_CERTS_DIR, 'ca.key');
  const caCrt = path.join(LOCAL_CERTS_DIR, 'ca.crt');

  const serverKey = path.join(LOCAL_CERTS_DIR, 'server.key');
  const serverCsr = path.join(LOCAL_CERTS_DIR, 'server.csr');
  const serverCrt = path.join(LOCAL_CERTS_DIR, 'server.crt');
  const serverCnf = path.join(LOCAL_CERTS_DIR, 'server.cnf');

  const devAKey = path.join(LOCAL_CERTS_DIR, 'device_a.key');
  const devACsr = path.join(LOCAL_CERTS_DIR, 'device_a.csr');
  const devACrt = path.join(LOCAL_CERTS_DIR, 'device_a.crt');

  const devBKey = path.join(LOCAL_CERTS_DIR, 'device_b.key');
  const devBCsr = path.join(LOCAL_CERTS_DIR, 'device_b.csr');
  const devBCrt = path.join(LOCAL_CERTS_DIR, 'device_b.crt');

  const untrustedCaKey = path.join(LOCAL_CERTS_DIR, 'untrusted_ca.key');
  const untrustedCaCrt = path.join(LOCAL_CERTS_DIR, 'untrusted_ca.crt');
  const untrustedDevKey = path.join(LOCAL_CERTS_DIR, 'untrusted_device.key');
  const untrustedDevCsr = path.join(LOCAL_CERTS_DIR, 'untrusted_device.csr');
  const untrustedDevCrt = path.join(LOCAL_CERTS_DIR, 'untrusted_device.crt');

  const invalidCrt = path.join(LOCAL_CERTS_DIR, 'invalid.crt');

  console.log('[DevCerts] Generating ephemeral test certificates in .local-certs/...');

  // 1. Root CA
  if (!fs.existsSync(caCrt)) {
    execSync(`openssl req -x509 -newkey rsa:2048 -nodes -keyout "${caKey}" -out "${caCrt}" -days 365 -subj "/CN=EH-Dev-Root-CA/O=EH-Home"`, { stdio: 'ignore' });
  }

  // 2. Server Config & Cert (SAN: localhost, 127.0.0.1)
  if (!fs.existsSync(serverCrt)) {
    const cnfContent = `[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = localhost
O = EH-Home
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
IP.1 = 127.0.0.1
`;
    fs.writeFileSync(serverCnf, cnfContent, 'utf8');

    execSync(`openssl req -new -newkey rsa:2048 -nodes -keyout "${serverKey}" -out "${serverCsr}" -config "${serverCnf}"`, { stdio: 'ignore' });
    execSync(`openssl x509 -req -in "${serverCsr}" -CA "${caCrt}" -CAkey "${caKey}" -CAcreateserial -out "${serverCrt}" -days 365 -extfile "${serverCnf}" -extensions v3_req`, { stdio: 'ignore' });
  }

  // 3. Device A Cert (CN = 0194fe23-7a1b-7890-a123-456789abcdef)
  if (!fs.existsSync(devACrt)) {
    execSync(`openssl req -new -newkey rsa:2048 -nodes -keyout "${devAKey}" -out "${devACsr}" -subj "/CN=0194fe23-7a1b-7890-a123-456789abcdef/O=EH-Devices"`, { stdio: 'ignore' });
    execSync(`openssl x509 -req -in "${devACsr}" -CA "${caCrt}" -CAkey "${caKey}" -CAcreateserial -out "${devACrt}" -days 365`, { stdio: 'ignore' });
  }

  // 4. Device B Cert (CN = 0194fe23-7a1b-7890-b456-123456fedcba)
  if (!fs.existsSync(devBCrt)) {
    execSync(`openssl req -new -newkey rsa:2048 -nodes -keyout "${devBKey}" -out "${devBCsr}" -subj "/CN=0194fe23-7a1b-7890-b456-123456fedcba/O=EH-Devices"`, { stdio: 'ignore' });
    execSync(`openssl x509 -req -in "${devBCsr}" -CA "${caCrt}" -CAkey "${caKey}" -CAcreateserial -out "${devBCrt}" -days 365`, { stdio: 'ignore' });
  }

  // 5. Untrusted CA & Device Cert (for rejection testing)
  if (!fs.existsSync(untrustedDevCrt)) {
    execSync(`openssl req -x509 -newkey rsa:2048 -nodes -keyout "${untrustedCaKey}" -out "${untrustedCaCrt}" -days 365 -subj "/CN=Untrusted-Root-CA"`, { stdio: 'ignore' });
    execSync(`openssl req -new -newkey rsa:2048 -nodes -keyout "${untrustedDevKey}" -out "${untrustedDevCsr}" -subj "/CN=0194fe23-7a1b-7890-a123-456789abcdef/O=EH-Untrusted"`, { stdio: 'ignore' });
    execSync(`openssl x509 -req -in "${untrustedDevCsr}" -CA "${untrustedCaCrt}" -CAkey "${untrustedCaKey}" -CAcreateserial -out "${untrustedDevCrt}" -days 365`, { stdio: 'ignore' });
  }

  // 6. Malformed / Invalid Cert
  if (!fs.existsSync(invalidCrt)) {
    fs.writeFileSync(invalidCrt, '-----BEGIN CERTIFICATE-----\nMALFORMED_DATA_INVALID\n-----END CERTIFICATE-----\n', 'utf8');
  }

  console.log('[DevCerts] Ephemeral development certificates generated successfully.');

  return {
    dir: LOCAL_CERTS_DIR,
    caCrt,
    serverCrt, serverKey,
    devACrt, devAKey,
    devBCrt, devBKey,
    untrustedCaCrt,
    untrustedDevCrt, untrustedDevKey,
    invalidCrt
  };
}

if (require.main === module) {
  generateCerts();
}

module.exports = { generateCerts, LOCAL_CERTS_DIR };
