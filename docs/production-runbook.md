# EH Home — Production Operations Runbook

> **Target Version**: 1.0.0-prod
> **Environment**: Staging & Production Clusters
> **Classification**: Internal Operations

---

## 1. System Architecture & Topology

```
Internet / Flutter App / ESP32 Device
       │
  [Port 443 / HTTPS] & [Port 8883 / mTLS]
       │
┌──────▼─────────────────────────────────────────────────┐
│              Edge Gateway & Reverse Proxy (Nginx)      │
│  - TLS Termination (HTTPS / Port 443)                  │
│  - Security Headers (HSTS, CSP, X-Frame-Options)       │
│  - Rate Limiting (100 req/min per IP)                  │
└──────┬──────────────────────────────────┬──────────────┘
       │                                  │ (mTLS Passthrough)
┌──────▼──────────────────────────┐┌──────▼──────────────┐
│  EH Home Backend Microservices  ││  EMQX 5.8 Cluster   │
│  - Port 3000                    ││  - Port 8883 (mTLS) │
│  - Stateless Node.js 22 Runtime ││  - Per-Device ACL   │
└──────┬──────────────────────────┘└──────┬──────────────┘
       │                                  │
┌──────▼──────────────────────────┐┌──────▼──────────────┐
│  PostgreSQL 16 High-Availability││  Redis 7 Cluster    │
│  - Port 5432                    ││  - Port 6379        │
│  - 28 Managed Relational Tables ││  - Caching & Locks  │
└─────────────────────────────────┘└─────────────────────┘
```

---

## 2. Service Health Probes & Monitoring

| Endpoint | Method | Purpose | SLA / Threshold |
| :--- | :--- | :--- | :--- |
| `/api/v1/health/liveness` | `GET` | Container / Kubernetes process liveness | Status 200 OK |
| `/api/v1/health/readiness` | `GET` | Database & dependency readiness | Status 200 (READY) / 503 (NOT_READY) |
| `/api/v1/health/diagnostics` | `GET` | Deep status for DB, Redis, MQTT, and Workers | Latency < 100ms |

---

## 3. Database Operations & Automated Backups

### A. Backup Procedure
- Backups are triggered automatically every 24 hours (02:00 UTC).
- Backups are compressed, timestamped, and accompanied by a SHA-256 checksum file.
- **Manual Backup Command**:
  ```bash
  node tools/database/backup-database.js
  ```

### B. Recovery & Restore Procedure
- **Manual Restore Command**:
  ```bash
  node tools/database/restore-database.js <backup-file.json>
  ```
- Checksum is verified before applying tables to ensure tamper resistance.

---

## 4. Disaster Recovery (DR) & SLAs

| Metric | Target | Supported Recovery Mechanism |
| :--- | :--- | :--- |
| **RTO (Recovery Time Objective)** | < 15 Minutes | Container automated restart via Kubernetes / Docker Compose restart policies |
| **RPO (Recovery Point Objective)** | < 1 Hour | Continuous WAL archiving & daily verified database snapshots |

---

## 5. Security & Certificate Rotation

### A. MQTT Broker & Device mTLS Certificates
- **CA Expiration**: 5 Years.
- **Server Certificate Expiration**: 1 Year (Renewed at 90 days prior).
- **Device Identity Certificate**: Embedded in hardware during factory provisioning via NVS partition `fact_v2`.

### B. JWT Keypair Rotation
- Asymmetric RS256 keypairs.
- To rotate: Deploy new public key to verification pool, issue new tokens with new private key, retire old private key after max refresh token TTL (30 days).
