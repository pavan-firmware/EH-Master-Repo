# EH Home — Data Flow & Lifecycle Invariants

**Status:** APPROVED (Part 00 Baseline)  

---

## 1. End-to-End Product Creation to Manufacturing Flow

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Hardware Engineer / Admin
    participant Desktop as EH Home Desktop App
    participant API as Central Backend (apps/api)
    participant DB as PostgreSQL 16
    participant S3 as Object Storage (MinIO / S3)
    participant Jig as Physical Test Jig & Flasher

    Admin->>Desktop: Create Product & Variant (e.g., EH 3X Smart Switch)
    Desktop->>API: POST /api/v1/products & variants
    API->>DB: Persist product definition
    
    Admin->>Desktop: Upload PCB Revision, Schematic & BOM
    Desktop->>S3: Upload gerber, schematics & renders
    Desktop->>API: Link S3 asset URLs to Hardware Revision
    
    Admin->>Desktop: Trigger Firmware Build on Git Tag
    Desktop->>API: POST /api/v1/firmware/build
    API->>API: Compiler Worker builds .bin & checks ELF partition size
    API->>S3: Store signed firmware binary (.bin) with SHA-256
    
    Admin->>Desktop: Create Production Batch (e.g., 500 Units)
    Desktop->>API: POST /api/v1/production/batches
    API->>DB: Pre-allocate sequential Serial Numbers & Cryptographic QR Tokens
    
    Desktop->>Jig: Connect ESP32 Target to USB/UART
    Jig->>Desktop: Read Hardware MAC Address
    Desktop->>API: Bind MAC Address to Pre-allocated Serial Number
    Desktop->>Jig: Flash Factory Bootloader, Firmware & NVS Partition
    
    Jig->>Desktop: Stream Automated Electrical & Relay Test Results
    Desktop->>API: Record QC Test Pass Log
    
    Desktop->>Desktop: Render Vector Label (Serial + Opaque QR)
    Desktop->>Desktop: Thermal Printer prints device label
    
    Admin->>Desktop: Scan Device Barcode & Outer Box QR
    Desktop->>API: Validate Serial ↔ Box Token Association
    API-->>Desktop: MATCH CONFIRMED (Pack Approved)
    API->>DB: Transition state to PACKED & Increment Warehouse Inventory
```

---

## 2. Customer Pairing & In-App Dynamic Rendering Flow

```mermaid
sequenceDiagram
    autonumber
    actor User as Homeowner
    participant App as Flutter Mobile App
    participant API as Central Backend
    participant ESP as Physical ESP32 Device

    User->>App: Scan Packaging / Device QR code
    Note over App: QR reads: eh://p/v1?t=OPAQUE_TOKEN
    App->>API: POST /api/v1/devices/claim { token }
    API->>API: Validate token, associate device with user's home
    API-->>App: Return Product Variant ID & Capabilities Descriptor
    
    App->>API: GET /api/v1/catalog/products/:id
    API-->>App: Dynamic product metadata, CDN image URLs, setup guides
    
    App->>ESP: Connect via BLE 5.0 GATT
    App->>ESP: Send Wi-Fi Credentials & Claim Handshake
    ESP->>ESP: Connects to Wi-Fi & EMQX MQTT Broker (mTLS)
    ESP-->>App: Emit Provisioning Complete
    
    App->>App: Dynamically render capability controls (Switches, Power Meter)
```
