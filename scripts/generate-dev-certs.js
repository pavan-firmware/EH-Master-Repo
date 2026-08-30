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

function generateCerts(options = {}) {
  const force = options.force === true;
  const caKey = path.join(LOCAL_CERTS_DIR, 'ca.key');
  const caCrt = path.join(LOCAL_CERTS_DIR, 'ca.crt');
  const caCnf = path.join(LOCAL_CERTS_DIR, 'ca.cnf');

  const serverKey = path.join(LOCAL_CERTS_DIR, 'server.key');
  const serverCsr = path.join(LOCAL_CERTS_DIR, 'server.csr');
  const serverCrt = path.join(LOCAL_CERTS_DIR, 'server.crt');
  const serverCnf = path.join(LOCAL_CERTS_DIR, 'server.cnf');

  const devAKey = path.join(LOCAL_CERTS_DIR, 'device_a.key');
  const devACsr = path.join(LOCAL_CERTS_DIR, 'device_a.csr');
  const devACrt = path.join(LOCAL_CERTS_DIR, 'device_a.crt');
  const devACnf = path.join(LOCAL_CERTS_DIR, 'device_a.cnf');

  const devBKey = path.join(LOCAL_CERTS_DIR, 'device_b.key');
  const devBCsr = path.join(LOCAL_CERTS_DIR, 'device_b.csr');
  const devBCrt = path.join(LOCAL_CERTS_DIR, 'device_b.crt');
  const devBCnf = path.join(LOCAL_CERTS_DIR, 'device_b.cnf');

  if (!force && fs.existsSync(caCrt) && fs.existsSync(serverCrt) && fs.existsSync(serverKey) && fs.existsSync(devACrt) && fs.existsSync(devBCrt)) {
    console.log('[DevCerts] Using existing development certificates in .local-certs/...');
    return {
      caCrt,
      serverCrt,
      serverKey,
      devACrt,
      devAKey,
      devBCrt,
      devBKey
    };
  }

  // Clean and recreate .local-certs when generating afresh
  if (fs.existsSync(LOCAL_CERTS_DIR)) {
    fs.rmSync(LOCAL_CERTS_DIR, { recursive: true, force: true });
  }
  fs.mkdirSync(LOCAL_CERTS_DIR, { recursive: true });

  const untrustedCaKey = path.join(LOCAL_CERTS_DIR, 'untrusted_ca.key');
  const untrustedCaCrt = path.join(LOCAL_CERTS_DIR, 'untrusted_ca.crt');
  const untrustedCaCnf = path.join(LOCAL_CERTS_DIR, 'untrusted_ca.cnf');

  const untrustedDevKey = path.join(LOCAL_CERTS_DIR, 'untrusted_device.key');
  const untrustedDevCsr = path.join(LOCAL_CERTS_DIR, 'untrusted_device.csr');
  const untrustedDevCrt = path.join(LOCAL_CERTS_DIR, 'untrusted_device.crt');
  const untrustedDevCnf = path.join(LOCAL_CERTS_DIR, 'untrusted_device.cnf');

  const invalidCrt = path.join(LOCAL_CERTS_DIR, 'invalid.crt');

  console.log('[DevCerts] Generating ephemeral test certificates with proper extensions in .local-certs/...');

  // 1. Root CA (basicConstraints = critical, CA:true; keyUsage = critical, keyCertSign, cRLSign)
  const caCnfContent = `[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
CN = EH-Dev-Root-CA
O = EH-Home

[v3_ca]
basicConstraints = critical, CA:true
keyUsage = critical, keyCertSign, cRLSign
`;
  fs.writeFileSync(caCnf, caCnfContent, 'utf8');
  execSync(`openssl req -x509 -newkey rsa:2048 -nodes -keyout "${caKey}" -out "${caCrt}" -days 365 -config "${caCnf}"`, { stdio: 'ignore' });

  // 2. EMQX Server Config & Cert (SAN: localhost, 127.0.0.1; extendedKeyUsage = serverAuth)
  const serverCnfContent = `[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = localhost
O = EH-Home

[v3_req]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
IP.1 = 127.0.0.1
`;
  fs.writeFileSync(serverCnf, serverCnfContent, 'utf8');
  execSync(`openssl req -new -newkey rsa:2048 -nodes -keyout "${serverKey}" -out "${serverCsr}" -config "${serverCnf}"`, { stdio: 'ignore' });
  execSync(`openssl x509 -req -in "${serverCsr}" -CA "${caCrt}" -CAkey "${caKey}" -CAcreateserial -out "${serverCrt}" -days 365 -extfile "${serverCnf}" -extensions v3_req`, { stdio: 'ignore' });

  // 3. Device A Cert (CN = 0194fe23-7a1b-7890-a123-456789abcdef, extendedKeyUsage = clientAuth)
  const devACnfContent = `[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = 0194fe23-7a1b-7890-a123-456789abcdef
O = EH-Devices

[v3_req]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
`;
  fs.writeFileSync(devACnf, devACnfContent, 'utf8');
  execSync(`openssl req -new -newkey rsa:2048 -nodes -keyout "${devAKey}" -out "${devACsr}" -config "${devACnf}"`, { stdio: 'ignore' });
  execSync(`openssl x509 -req -in "${devACsr}" -CA "${caCrt}" -CAkey "${caKey}" -CAcreateserial -out "${devACrt}" -days 365 -extfile "${devACnf}" -extensions v3_req`, { stdio: 'ignore' });

  // 4. Device B Cert (CN = 0194fe23-7a1b-7890-b456-123456fedcba, extendedKeyUsage = clientAuth)
  const devBCnfContent = `[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = 0194fe23-7a1b-7890-b456-123456fedcba
O = EH-Devices

[v3_req]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
`;
  fs.writeFileSync(devBCnf, devBCnfContent, 'utf8');
  execSync(`openssl req -new -newkey rsa:2048 -nodes -keyout "${devBKey}" -out "${devBCsr}" -config "${devBCnf}"`, { stdio: 'ignore' });
  execSync(`openssl x509 -req -in "${devBCsr}" -CA "${caCrt}" -CAkey "${caKey}" -CAcreateserial -out "${devBCrt}" -days 365 -extfile "${devBCnf}" -extensions v3_req`, { stdio: 'ignore' });

  // 5. Untrusted CA & Device Cert (for rejection testing)
  const untrustedCaCnfContent = `[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
CN = Untrusted-Root-CA

[v3_ca]
basicConstraints = critical, CA:true
keyUsage = critical, keyCertSign, cRLSign
`;
  fs.writeFileSync(untrustedCaCnf, untrustedCaCnfContent, 'utf8');
  execSync(`openssl req -x509 -newkey rsa:2048 -nodes -keyout "${untrustedCaKey}" -out "${untrustedCaCrt}" -days 365 -config "${untrustedCaCnf}"`, { stdio: 'ignore' });

  const untrustedDevCnfContent = `[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = 0194fe23-7a1b-7890-a123-456789abcdef
O = EH-Untrusted

[v3_req]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
`;
  fs.writeFileSync(untrustedDevCnf, untrustedDevCnfContent, 'utf8');
  execSync(`openssl req -new -newkey rsa:2048 -nodes -keyout "${untrustedDevKey}" -out "${untrustedDevCsr}" -config "${untrustedDevCnf}"`, { stdio: 'ignore' });
  execSync(`openssl x509 -req -in "${untrustedDevCsr}" -CA "${untrustedCaCrt}" -CAkey "${untrustedCaKey}" -CAcreateserial -out "${untrustedDevCrt}" -days 365 -extfile "${untrustedDevCnf}" -extensions v3_req`, { stdio: 'ignore' });

  // 6. Malformed / Invalid Cert
  fs.writeFileSync(invalidCrt, '-----BEGIN CERTIFICATE-----\nMALFORMED_DATA_INVALID\n-----END CERTIFICATE-----\n', 'utf8');

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

