# EH Home — Phase 6 TLS Test Certificate Fixtures

## DEVELOPMENT USE ONLY

These certificate files are the **built-in self-signed development certificates**
shipped with EMQX 5.8.0 (`emqx/emqx:5.8.0` Docker image).

They are committed here SOLELY for the Phase 6 EQ13 TLS integration test suite.

## Files

| File | Purpose |
|------|---------|
| `emqx-dev-ca.pem` | Development root CA certificate (CN=RootCA, O=EMQ) |
| `emqx-dev-server.pem` | EMQX development server certificate (CN=Server) |
| `emqx-dev-client.pem` | EMQX development client certificate (CN=Client) |
| `emqx-dev-client-key.pem` | EMQX development client private key |

## Security

- These are **NOT production private keys**.
- These are the EMQX Docker image shipped development credentials,
  extracted from `/opt/emqx/etc/certs/` inside the container.
- The CA, server cert, and client cert are all self-signed by
  `CN=RootCA, O=EMQ, ST=hangzhou, C=CN`.
- Do NOT use these certificates for any production deployment.
- These certificates are valid until **May 6 2030 GMT**.

## CA Details

```
Issuer:  CN=RootCA, O=EMQ, ST=hangzhou, C=CN
Subject: CN=RootCA, O=EMQ, ST=hangzhou, C=CN
Valid:   Until May 6 2030 GMT
```

## EMQX mTLS ACL Note

EMQX 5.8.0 (default Docker config) runs port 8883 with:
  - `verify: verify_none` (client cert NOT required)
  - `fail_if_no_peer_cert: false`
  - No TLS-CN→deviceId authentication plugin configured

This means EMQX does not currently enforce mTLS device identity ACL.
See EQ13 in `phase6-emqx-integration.test.js` for the full gap report
and exact configuration steps required to enable mTLS ACL.
