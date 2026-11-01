# EH Home — System Architecture

**Status:** APPROVED (Part 00 Baseline)  
**Author:** EH Home Engineering  
**Scope:** Complete Product Lifecycle, Engineering & Manufacturing Platform  

---

## 1. Top-Level Architectural Topology

EH Home operates as an integrated smart-home ecosystem linking internal engineering/manufacturing hardware with cloud intelligence and consumer mobile clients.

```mermaid
graph TB
    subgraph "External Cloud Services"
        S3["S3-Compatible Object Store<br/>(MinIO / Cloudflare R2 / AWS S3)<br/>Product Media, Manuals, Binaries"]
        EMQX["EMQX 5.8.0 MQTT Broker<br/>(TLS 8883 / WS 8084)<br/>Device Telemetry & Remote Control"]
    end

    subgraph "EH Home Central Backend (apps/api - Modular Monolith)"
        Fastify["Fastify TypeScript Core API<br/>Zod Schemas • JWT Engine • RBAC"]
        Drizzle["Drizzle ORM Engine"]
        Postgres[(PostgreSQL 16 Master DB)]
        Redis[(Redis 7 & BullMQ)]
        Workers["Background Job Workers<br/>(Builds, OTA, Stale Detection)"]
        
        Fastify --> Drizzle --> Postgres
        Fastify --> Redis
        Workers --> Redis
        Workers --> Postgres
        Fastify --> S3
    end

    subgraph "Internal Engineering & Manufacturing (apps/desktop)"
        TauriCore["Tauri Rust Runtime (Windows x64)"]
        TauriUI["React 19 + TypeScript + Tailwind UI"]
        RustDrivers["Native Rust Hardware Drivers<br/>• serialport (ESP32 UART)<br/>• USB HID (Barcode/QR Scanner)<br/>• TSPL/ESC-POS (Thermal Label Printer)"]
        PythonFlasher["tools/manufacturing/flash_device.py<br/>(Sidecar Subprocess)"]

        TauriUI <-->|Tauri IPC| TauriCore
        TauriCore --> RustDrivers
        TauriCore --> PythonFlasher
        TauriCore <-->|HTTPS / WSS| Fastify
    end

    subgraph "Production Bench Equipment"
        ESP32Target["ESP32 Physical Target (Switch / Socket)"]
        BarcodeScanner["USB Barcode / QR Scanner"]
        LabelPrinter["Industrial Thermal Label Printer"]

        PythonFlasher <-->|COM Port UART| ESP32Target
        BarcodeScanner -->|USB HID Stream| RustDrivers
        RustDrivers -->|USB / Network TSPL| LabelPrinter
    end

    subgraph "Consumer Ecosystem"
        FlutterApp["EH Home Flutter Mobile App<br/>(smart_home_application_v1)<br/>Dynamic Capability Renderers"]
        DeployedESP32["Field Deployed ESP32 Devices<br/>(ESP-IDF 5.4.1 C/C++)"]

        FlutterApp <-->|HTTPS REST & SSE| Fastify
        FlutterApp <-->|BLE 5.0 GATT| DeployedESP32
        DeployedESP32 <-->|mTLS MQTT| EMQX
        EMQX <-->|Ingestion Webhook| Fastify
        FlutterApp -.->|Fetch Remote Media| S3
    end
```

---

## 2. Source of Truth Matrix

| Domain | Primary Source of Truth | Secondary / Cache |
| :--- | :--- | :--- |
| **Firmware Source Code** | GitHub Repository (`firmware/`) | Local Git Workspace |
| **Business, Device & Batch Data** | PostgreSQL 16 (via Drizzle ORM) | Redis In-Memory Cache |
| **Firmware Binaries & Media Assets**| S3-Compatible Object Store (MinIO/R2) | Local Desktop / App Cache |
| **API & Protocol Contracts** | `packages/contracts/` (Zod + Schemas)| Shared TypeScript Package |
| **Manufacturing Provisioning Rules**| Central Backend Database | Desktop Staging Buffer |
| **Active Field Device State** | PostgreSQL `device_state` + Shadow | MQTT Ingest Engine |

---

## 3. Technology Stack Pinning

- **Desktop App:** Tauri v2, Rust 1.80+, React 19, TypeScript 5.x, Tailwind CSS v3/v4.
- **Central API:** Node.js v24 LTS, Fastify v4/v5, TypeScript 5.x, Drizzle ORM, Zod v3.
- **Database:** PostgreSQL 16 (strict relational integrity, JSONB for capability matrices).
- **Queues & Caching:** Redis 7, BullMQ v5.
- **Object Storage:** MinIO (Local Dev/CI), Cloudflare R2 / AWS S3 (Production).
- **Mobile Client:** Flutter 3.29+ / Dart 3.7+ (`smart_home_application_v1`).
- **Firmware Framework:** ESP-IDF v5.4.1 pinned (C/C++).
- **Package Manager:** `pnpm` workspaces for JavaScript/TypeScript projects.
