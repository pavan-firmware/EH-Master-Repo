# EH Home — Security & Operational Invariants

**Status:** APPROVED (Part 00 Baseline)  
**Mandate:** Non-negotiable system rules enforced across all 17 phases.  

---

## 1. Database Invariants
* **Immutable Legacy Migrations:** Existing migration files `001_initial_schema.sql` through `029_production_observability_and_incidents.sql` MUST NOT be edited, renamed, or retroactively modified. All schema extensions MUST use forward migrations (`030+`).
* **Soft Deletes Only:** Production records (`devices`, `products`, `product_variants`, `hardware_revisions`, `firmware_releases`, `production_batches`) MUST NOT be hard-deleted. State progression MUST follow: `ACTIVE → DEPRECATED → DISCONTINUED`.
* **Relational Foreign Key Integrity:** Physical devices must strictly reference valid `product_variants` and `hardware_revisions`.

---

## 2. Hardware & Firmware Invariants
* **ESP-IDF Toolchain Pinning:** Embedded firmware MUST compile under ESP-IDF v5.4.1. Toolchain drift is actively guarded by `scripts/check-esp-idf-toolchain.js`.
* **NVS Partition Protection:** Factory calibration, device private key, and hardware identity partitions (e.g. `fact_v2`) reside in protected NVS offsets. OTA firmware updates and user resets MUST NEVER overwrite the factory partition.
* **Boot-Safe Actuators:** All smart switch and socket relays MUST boot physically in the `OFF` state until deliberate command execution or restored state occurs.

---

## 3. Production & Identity Invariants
* **Identity Immutability:** A `Serial Number`, `MAC Address`, `Device ID`, or `Cryptographic QR Token` once allocated to a physical unit CAN NEVER be reused or re-assigned to another physical device.
* **Opaque QR Tokens:** Printed QR codes MUST NEVER contain plain-text Wi-Fi passwords, device private keys, or root credentials. QR payloads MUST use cryptographic opaque tokens:
  ```text
  eh://p/v1?t=<HIGH_ENTROPY_CRYPTOGRAPHIC_TOKEN>
  ```
* **Dual-Scan Packing Interlock:** A unit CANNOT transition to `PACKED` state without a verified dual-scan match between the physical unit's serial number and the packaging box QR token. Mismatches MUST mechanically block box sealing.
* **Audit Trail:** Every production status change (Programming, QC pass, Label print, Packing, Shipping) MUST record: `timestamp`, `operator_user_id`, `station_id`, `entity_id`, and `audit_digest`.
