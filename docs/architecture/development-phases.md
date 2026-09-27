# EH Home — Development Phases & Execution Roadmap

**Status:** APPROVED (Part 00 Baseline)  
**Execution Model:** Sequential Execution with Mandatory Automated Verification Gates  

---

## 1. Roadmap Overview

```text
PART 00: Master Architecture, Invariants & Monorepo Foundation (CURRENT)
   ↓
PART 01: System Architecture & Shared TypeScript/Zod Contracts
   ↓
PART 02: Database / ER Model & Drizzle ORM Schema (030+ Migrations)
   ↓
PART 03: Central Backend API Core (Fastify + TypeScript + Auth)
   ↓
PART 04: Desktop Application Foundation (Tauri v2 + Rust + React + Tailwind)
   ↓
PART 05: Product & Design Management Module
   ↓
PART 06: Hardware Revisions & BOM Management Module
   ↓
PART 07: Firmware & Source Code Management Module
   ↓
PART 08: Automated Firmware Build, Host Testing & Release Candidate Pipeline
   ↓
PART 09: Device Identity, Serial Allocation & ESP32 Bench Flasher
   ↓
PART 10: QR Code Batch Generator & TSPL Thermal Label Printing System
   ↓
PART 11: Production Workflows, Dual-Scan Packing Verification & Inventory
   ↓
PART 12: Flutter Mobile App Dynamic Catalog & APK Size Optimization
   ↓
PART 13: Cloud EMQX MQTT Integration, Shadow Telemetry & Signed OTA
   ↓
PART 14: Enterprise RBAC, Security Boundaries & Immutable Audit Ledger
   ↓
PART 15: Monorepo End-to-End Testing Suites & GitHub Actions CI/CD
   ↓
PART 16: Docker Containerization, MinIO S3 Setup & Automated Backups
   ↓
PART 17: End-to-End System Validation & Physical Device Acceptance
```

---

## 2. Mandatory Verification Gate Standard

At the end of every part, the following gate criteria must pass before proceeding to the next part:
1. **Compilation & Static Analysis:** Zero TypeScript, Rust, C/C++, or Dart analyzer errors.
2. **Automated Test Suites:** All new and pre-existing regression test suites must pass (100% pass rate).
3. **Database Integrity:** Migrations must apply cleanly and be bidirectional where applicable.
4. **Documentation Sync:** Architecture specifications and state logs updated to reflect exact changes.
5. **No Regression:** Pre-existing Flutter app, firmware, and backend test suites must remain green.
