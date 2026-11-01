# EH Home — Desktop Foundation Architecture

## 1. Overview & System Boundary

The EH Home Desktop Application (`apps/desktop`) is an **internal engineering, provisioning, and manufacturing operations platform**. It is designed specifically for factory floor technicians, firmware engineers, and hardware testing personnel. 

It is completely distinct from the customer-facing Flutter mobile application (`smart_home_application_v1`), which is focused on home automation, device control, and end-user onboarding.

```text
┌────────────────────────────────────────────────────────┐
│             EH Home Internal Desktop                   │
│                                                        │
│  ┌───────────────────────────┐                         │
│  │   React + TypeScript UI   │                         │
│  └─────────────┬─────────────┘                         │
│                │                                       │
│   Tauri IPC    │ Typed HTTP                            │
│   (Commands)   │ Client                                │
│        │       │                                       │
│        ▼       │                                       │
│  ┌───────────┐ │                                       │
│  │ Rust Core │ │                                       │
│  │ (Tauri v2)│ │                                       │
│  └─────┬─────┘ │                                       │
└────────┼───────┼───────────────────────────────────────┘
         │       │
         │       ▼
         │   ┌───────────────────────────┐
         │   │         apps/api          │
         │   │   (Fastify + TypeScript)  │
         │   └─────────────┬─────────────┘
         │                 │
         │                 ▼
         │            PostgreSQL
         ▼
┌────────────────────────────────┐
│      Native Peripherals        │
│ (Serial, USB, Printer, Scanner)│
└────────────────────────────────┘
```

### Architectural Invariants
1. **No Direct Database Access:** The desktop UI and native layer do NOT connect directly to PostgreSQL. All application persistence passes through `apps/api`.
2. **No Duplicated Business Logic:** Validation schemas and domain contracts are imported from `@eh-home/contracts`.
3. **No Arbitrary Shell Execution:** The desktop does not expose generic shell or command execution APIs to the webview.
4. **Controlled Sidecar Flashing:** Hardware flashing will utilize a structured sidecar pattern calling the existing Python manufacturing script without modifying it.

---

## 2. Desktop Stack & Technology Choices

| Component | Technology | Version / Specification | Role |
| :--- | :--- | :--- | :--- |
| **Desktop Framework** | Tauri | v2.x | Native desktop container, secure OS IPC, windowing |
| **Native Core** | Rust | 2021 Edition | Systems-level peripheral access, sidecar process execution |
| **Frontend Framework** | React | 18.x | Modular UI component tree, engineering dashboards |
| **Language** | TypeScript | 5.x | Strict type-safety across components and service boundaries |
| **Styling** | Tailwind CSS | 3.x | Consistent dark engineering design system |
| **Shared Contracts** | `@eh-home/contracts` | Internal Workspace | Authoritative API and payload contract types |
| **Bundler & Dev Server**| Vite | 5.x | Fast ESM HMR and production bundle generation |

---

## 3. Frontend Architecture & Boundaries

### 3.1 Directory Structure
```text
apps/desktop/
├── index.html
├── package.json
├── tsconfig.json
├── vite.config.ts
├── tailwind.config.js
├── postcss.config.js
├── .env.example
├── src/
│   ├── main.tsx                    # Entry point & ErrorBoundary wrapper
│   ├── App.tsx                     # Top-level shell layout & state provider
│   ├── components/                 # Reusable layout & presentation primitives
│   │   ├── Header.tsx              # App title, environment tag, API connectivity indicator
│   │   ├── Sidebar.tsx             # 9 domain navigation entries (placeholders)
│   │   ├── StatusFooter.tsx        # Port status, flasher state, latency, active user
│   │   ├── ErrorBoundary.tsx       # Top-level runtime crash containment
│   │   └── LoadingState.tsx        # Standard spinner & progress indicator
│   ├── features/                   # Domain views
│   │   ├── DashboardView.tsx       # System health, API probe, native status cards
│   │   └── PlaceholderView.tsx     # Explicit placeholder for future parts (Parts 05–12)
│   ├── lib/                        # Core utilities
│   │   ├── config.ts               # Typed environment configuration
│   │   └── logger.ts               # Structured logger with secret redaction
│   ├── services/                   # Service layer
│   │   ├── api-client.ts           # Typed HTTP client to apps/api
│   │   └── native/                 # Native peripheral abstraction interfaces
│   │       ├── flasher.service.ts  # IFlasherService & PythonSidecarFlasher
│   │       ├── serial.service.ts   # ISerialService & NativeSerialService
│   │       ├── scanner.service.ts  # IScannerService & NativeScannerService
│   │       └── printer.service.ts  # IPrinterService & NativePrinterService
│   ├── state/                      # Application state context
│   │   └── app-state.tsx           # UI navigation, API status, and peripheral state
│   └── styles/
│       └── index.css               # Tailwind directives & engineering dark theme
├── src-tauri/                      # Tauri v2 native Rust container
│   ├── Cargo.toml                  # Tauri v2, serde, tauri-plugin-shell dependencies
│   ├── tauri.conf.json             # Windowing, bundle ID, and strict CSP configuration
│   └── src/
│       ├── main.rs                 # Native binary entrypoint
│       ├── lib.rs                  # Plugin registration & command setup
│       └── commands.rs             # Constrained, validated Tauri IPC handlers
└── tests/
    └── desktop.test.js             # Automated unit & integration verification
```

### 3.2 State Architecture
The desktop application cleanly isolates three distinct types of state:
1. **UI State:** Active navigation tab, modal visibility, collapsed sidebar state.
2. **Server / API State:** API health status, roundtrip latency, server correlation tokens, fetched catalog data.
3. **Native Desktop Peripheral State:** Selected serial COM port, connection status, flasher readiness, barcode scanner buffer.

---

## 4. API Client Boundary

The desktop application connects to `apps/api` via `DesktopApiClient` (`src/services/api-client.ts`).

### Characteristics:
- **Base URL Config:** Read from `VITE_API_BASE_URL` (defaults to `http://localhost:3100`).
- **Correlation ID:** Automatically propagates `x-request-id` headers for end-to-end tracing across desktop logs and Fastify logs.
- **Contract Driven:** Reuses standard envelopes and models from `@eh-home/contracts`.
- **Uniform Error Handling:** Rejects with structured `ApiError` instances containing HTTP status codes, correlation IDs, and server error messages.

---

## 5. Native Peripheral Abstraction Layer

To ensure future manufacturing capabilities remain testable and decoupled from React UI components, strict TypeScript interfaces govern all hardware interactions:

### 5.1 `IFlasherService` & `PythonSidecarFlasher`
- **Interface:** Defines `probeEnvironment()`, `flashDevice(options)`, and `cancel()`.
- **Status in Part 04:** Abstraction established. Probing verifies existence of tools without invoking `flash_device.py`.

### 5.2 `ISerialService`
- **Interface:** Defines `listPorts()`, `openPort(path, baudRate)`, `closePort()`, and `write(data)`.
- **Status in Part 04:** Abstraction established. Delegated to Tauri `list_serial_ports` command.

### 5.3 `IScannerService`
- **Interface:** Defines `startListening(onScan)` and `stopListening()`.
- **Status in Part 04:** Abstraction established. Ready for future 2D barcode / QR camera/HID scanners.

### 5.4 `IPrinterService`
- **Interface:** Defines `listPrinters()` and `printLabel(job)`.
- **Status in Part 04:** Abstraction established. Ready for future thermal label printers (ZPL/ESC-POS).

---

## 6. Future Flasher Sidecar Architecture

The approved migration decision reuses the existing, battle-tested Python manufacturing flasher (`tools/manufacturing/flash_device.py`) as a desktop-side controlled sidecar.

```text
┌──────────────────────────────────────────────┐
│             Desktop React UI                 │
│         (Trigger Provisioning)               │
└──────────────────────┬───────────────────────┘
                       │ invoke('flash_device', payload)
                       ▼
┌──────────────────────────────────────────────┐
│           Tauri v2 Rust Core                 │
│   - Validate payload parameters              │
│   - Spawn sidecar process under supervisor   │
│   - Enforce execution timeout (e.g. 120s)    │
│   - Stream sanitized stdout/stderr events    │
│   - Manage process termination / cancel      │
└──────────────────────┬───────────────────────┘
                       │ stdin / stdout / stderr pipes
                       ▼
┌──────────────────────────────────────────────┐
│        Python Manufacturing Flasher          │
│     (tools/manufacturing/flash_device.py)    │
│   - Serial baud rate negotiation             │
│   - ESP32 bootloader handshake               │
│   - Flashing partition table, bootloader, app │
│   - NVS manufacturing keys injection         │
└──────────────────────────────────────────────┘
```

### Sidecar Contract Requirements:
1. **Zero Script Modification:** The existing `flash_device.py` will not be altered.
2. **Explicit Parameter Validation:** Rust will strictly validate the target COM port, chip family, and firmware file path before spawning the process.
3. **Lifecycle Control:** The desktop will monitor PID, track progress via stdout regex, enforce timeouts, and cleanly kill child processes if canceled.
4. **Sanitized Diagnostics:** Sensitive credentials (factory private keys, Wi-Fi PSKs) will be masked before emitting diagnostic log events to the UI.

---

## 7. Security Baseline & Tauri Command Architecture

1. **Content Security Policy (CSP):** Configured in `tauri.conf.json` to disallow remote script injection (`default-src 'self'; script-src 'self'; connect-src 'self' http://localhost:3100 http://127.0.0.1:3100;`).
2. **No Arbitrary Shell Command:** Only specific, strongly typed Tauri commands exist:
   - `get_app_info`
   - `check_native_service_status`
   - `list_serial_ports`
3. **Zero Secret Storage:** Factory secrets, private keys, and passwords must never be bundled into the frontend or committed to source control.
4. **Log Sanitization:** The frontend logging layer automatically scrubs tokens, Wi-Fi keys, passwords, and private key references.

---

## 8. Error Handling & Observability

- **React Error Boundary:** Catches and isolates unexpected UI rendering faults, presenting an engineering diagnostic screen with recovery buttons instead of a blank screen.
- **API Error Normalization:** Network timeouts, 4xx/5xx responses, and unparseable responses are normalized into `ApiError` with correlation IDs.
- **Native Fault Isolation:** Tauri command rejections are serialized as structured error payloads without leaking raw operating system panic dumps.

---

## 9. Relationship to Customer Flutter App

| Attribute | Internal Desktop Application (`apps/desktop`) | Customer Mobile App (`smart_home_application_v1`) |
| :--- | :--- | :--- |
| **Primary Audience** | Manufacturing engineers, factory line operators, QA | End-user home owners, family members |
| **Platform** | Windows / macOS / Linux (Tauri v2 + Rust) | Android / iOS (Flutter) |
| **Permissions** | Serial COM ports, thermal printers, barcode scanners | Camera (QR code onboarding), Bluetooth / Wi-Fi |
| **Data Access** | Production APIs, device provisioning, diagnostics | Customer REST APIs, MQTT broker, local edge |
| **Security Posture** | Factory operator credentials, hardware physical security | Customer OAuth/JWT tokens, home-level RBAC |
