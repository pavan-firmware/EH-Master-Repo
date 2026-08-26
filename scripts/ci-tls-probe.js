'use strict';

/**
 * EH Home — Phase 6 CI Standalone Raw Node TLS & MQTT Probe
 * Diagnostic probe to isolate Node tls.connect vs mqtt.js under Node 20 / 24.
 */

const tls = require('tls');
const fs = require('fs');
const path = require('path');
const mqtt = require('mqtt');

console.log('==========================================================');
console.log('         EH HOME — PHASE 6 RAW NODE TLS PROBE             ');
console.log('==========================================================');

console.log('Node version:', process.version);
console.log('OpenSSL version:', process.versions.openssl);

console.log('\n--- Environment Variables Check ---');
console.log('NODE_EXTRA_CA_CERTS set:', process.env.NODE_EXTRA_CA_CERTS !== undefined);
console.log('HTTPS_PROXY set:', process.env.HTTPS_PROXY !== undefined || process.env.https_proxy !== undefined);
console.log('HTTP_PROXY set:', process.env.HTTP_PROXY !== undefined || process.env.http_proxy !== undefined);
console.log('ALL_PROXY set:', process.env.ALL_PROXY !== undefined || process.env.all_proxy !== undefined);
console.log('NO_PROXY set:', process.env.NO_PROXY !== undefined || process.env.no_proxy !== undefined);
console.log('NODE_OPTIONS set:', process.env.NODE_OPTIONS !== undefined);

const LOCAL_CERTS = path.join(__dirname, '..', '.local-certs');
const caCrtPath = path.join(LOCAL_CERTS, 'ca.crt');
const devACrtPath = path.join(LOCAL_CERTS, 'device_a.crt');
const devAKeyPath = path.join(LOCAL_CERTS, 'device_a.key');

if (!fs.existsSync(caCrtPath)) {
  console.error('ERROR: Certificates not found in .local-certs. Run generate-dev-certs.js first.');
  process.exit(1);
}

const CA_CRT = fs.readFileSync(caCrtPath);
const DEV_A_CRT = fs.readFileSync(devACrtPath);
const DEV_A_KEY = fs.readFileSync(devAKeyPath);

function runRawTlsProbe() {
  return new Promise((resolve) => {
    console.log('\n--- Probe 1: Raw Node tls.connect ---');
    const socket = tls.connect({
      host: '127.0.0.1',
      port: 8883,
      ca: [CA_CRT],
      cert: DEV_A_CRT,
      key: DEV_A_KEY,
      rejectUnauthorized: true,
      servername: 'localhost'
    });

    let settled = false;

    socket.on('secureConnect', () => {
      if (!settled) {
        settled = true;
        console.log('  [PASS] Raw tls.connect secureConnect fired!');
        console.log('  authorized:', socket.authorized);
        console.log('  authorizationError:', socket.authorizationError);
        console.log('  TLS Protocol:', socket.getProtocol());
        const peerCert = socket.getPeerCertificate();
        if (peerCert) {
          console.log('  Peer Cert Subject:', peerCert.subject ? peerCert.subject.CN : 'N/A');
          console.log('  Peer Cert Issuer:', peerCert.issuer ? peerCert.issuer.CN : 'N/A');
        }
        socket.destroy();
        resolve(true);
      }
    });

    socket.on('error', (err) => {
      if (!settled) {
        settled = true;
        console.log('  [FAIL] Raw tls.connect error fired!');
        console.log('  error.code:', err.code);
        console.log('  error.message:', err.message);
        socket.destroy();
        resolve(false);
      }
    });

    setTimeout(() => {
      if (!settled) {
        settled = true;
        console.log('  [FAIL] Raw tls.connect timed out (8s)');
        socket.destroy();
        resolve(false);
      }
    }, 8000);
  });
}

function runMqttProbe() {
  return new Promise((resolve) => {
    console.log('\n--- Probe 2: Standalone mqtt.connect ---');
    const client = mqtt.connect('mqtts://127.0.0.1:8883', {
      ca: [CA_CRT],
      cert: DEV_A_CRT,
      key: DEV_A_KEY,
      rejectUnauthorized: true,
      clientId: '0194fe23-7a1b-7890-a123-456789abcdef',
      servername: 'localhost',
      reconnectPeriod: 0,
      connectTimeout: 8000,
      agent: false
    });

    let settled = false;

    client.on('connect', () => {
      if (!settled) {
        settled = true;
        console.log('  [PASS] Standalone mqtt.connect connected!');
        client.end(true);
        resolve(true);
      }
    });

    client.on('error', (err) => {
      if (!settled) {
        settled = true;
        console.log('  [FAIL] Standalone mqtt.connect error:', err.message);
        if (err.code) console.log('  error.code:', err.code);
        client.end(true);
        resolve(false);
      }
    });

    setTimeout(() => {
      if (!settled) {
        settled = true;
        console.log('  [FAIL] Standalone mqtt.connect timed out (8s)');
        client.end(true);
        resolve(false);
      }
    }, 8000);
  });
}

(async () => {
  const rawPass = await runRawTlsProbe();
  const mqttPass = await runMqttProbe();
  console.log('\n==========================================================');
  console.log(`Probe Results: Raw TLS = ${rawPass ? 'PASS' : 'FAIL'}, Standalone MQTT = ${mqttPass ? 'PASS' : 'FAIL'}`);
  console.log('==========================================================\n');
})();
