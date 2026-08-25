# EH HOME — Phase 5B Device Manufacturing PKI & Certificate Architecture

**Status:** `DOCUMENTED` — **MANUFACTURING PKI VALIDATION PENDING**
**Date:** 2026-08-25
**Target Stack:** ESP32-C6 / ESP32-S3 (ESP-IDF v5.x mbedTLS), EH Backend NGINX mTLS Gateway

---

## 1. Overview & Trust Hierarchy

Every physical EH Home smart device is provisioned during manufacturing with a unique X.509 client certificate and ECC P-256 keypair. This certificate enables direct device-authenticated registration with the backend over mTLS without relying on app relay or unauthenticated headers.

```
                  ┌──────────────────────────────┐
                  │    EH Home Root CA           │
                  │  (Offline Air-Gapped HSM)    │
                  └──────────────┬───────────────┘
                                 │
                                 ▼
                  ┌──────────────────────────────┐
                  │   EH Device Intermediate CA  │
                  │   (Factory Provisioning HSM) │
                  └──────────────┬───────────────┘
                                 │
           ┌─────────────────────┴─────────────────────┐
           ▼                                           ▼
┌──────────────────────────┐               ┌──────────────────────────┐
│ ESP32 Device Cert #1     │               │ ESP32 Device Cert #2     │
│ CN = <deviceId (UUID)>   │               │ CN = <deviceId (UUID)>   │
│ Key = ECC P-256 (NVS)    │               │ Key = ECC P-256 (NVS)    │
└──────────────────────────┘               └──────────────────────────┘
```

---

## 2. Factory Provisioning Workflow

1. **Key Generation**: During PCB functional testing, the factory programmer commands the ESP32 hardware RNG to generate an ECC P-256 keypair (`local_device_key.pem`).
2. **Key Storage**: The private key is written to the flash-encrypted NVS `factory_v2` partition.
3. **CSR & Issuance**: The factory programmer requests a Certificate Signing Request (CSR) with Subject Common Name `CN = deviceId`. The **EH Device Intermediate CA** signs the request and returns the X.509 client certificate (`device_cert.crt`, valid for 10 years).
4. **Contract Registration**: The SHA-256 fingerprint of `device_cert.crt` is registered in the EH Backend product database under `DeviceCredential.tlsClientCertFingerprint`.

---

## 3. Reverse Proxy & mTLS Verification Boundary

```
Internet (Device Direct) ──► NGINX Reverse Proxy (mTLS Gateway)
                              │  - Validates cert against EH Root CA
                              │  - Strips untrusted client headers
                              │  - Adds X-Client-Cert-Fingerprint
                              ▼
                         Backend API Server (Internal Network)
                              - Validates proxy trust (IP: 172.20.x.x / 127.0.0.1)
                              - Matches fingerprint with DeviceCredential
                              - Marks device PROVISIONED / REGISTERED
```

---

## 4. Hardware Security Requirements

For production release, physical ESP32 targets must enforce:
- **Secure Boot v2**: Ensures unsigned custom firmware cannot be flashed via UART/JTAG to extract NVS keys.
- **Flash Encryption (AES-XTS)**: Encrypts the entire SPI flash including the `factory_v2` NVS partition containing private keys and certificates.

---

## 5. Status Notice

> **MANUFACTURING PKI VALIDATION PENDING**
> Physical HSM hardware certificate signing and flash-encryption programming will be validated on physical ESP32 hardware during the Phase 6 manufacturing bring-up phase. Host-level unit and integration tests mock mTLS client certificate fingerprint headers.
