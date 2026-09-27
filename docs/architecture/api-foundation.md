# EH Home — Fastify API Foundation Architecture

## 1. Overview & Strategy

The `apps/api` application establishes the new Fastify + TypeScript + Drizzle ORM service layer for the EH Home platform.

### Core Strategy: Side-by-Side Coexistence
- **Legacy Backend (`backend/`)**: Remains fully active, functional, and untouched. Continues serving existing production endpoints and mobile app traffic.
- **New Modular API (`apps/api/`)**: Developed side-by-side to gradually achieve domain parity before any decommissioning is considered.
- **Zero Premature Cutover**: No traffic or routes are redirected from the legacy backend during Part 03.

---

## 2. Application Structure & Bootstrap Separation

The application enforces a strict separation between application composition and network listening:

```text
apps/api/
├── package.json
├── tsconfig.json
├── .env.example
├── src/
│   ├── app.ts                  # Application construction, plugin registration, route mounting
│   ├── server.ts               # Process entrypoint, signal handling, and network listening
│   ├── config/
│   │   └── index.ts            # Environment validation with Zod
│   ├── plugins/
│   │   ├── correlation.ts      # x-request-id handling and generation
│   │   ├── database.ts         # @eh-home/db-schema client integration and lifecycle
│   │   ├── error-handler.ts    # Centralized error mapping and information-leakage prevention
│   │   └── health.ts           # /health and /ready endpoints
│   ├── modules/
│   │   ├── index.ts            # Domain module registry
│   │   └── system/             # Operational diagnostics & system module
│   │       ├── system.schema.ts
│   │       ├── system.service.ts
│   │       └── system.routes.ts
│   └── routes/
│       └── index.ts            # Root operational endpoints and /api/v1 prefix
└── tests/
    └── api.test.js             # Automated API test suite via Fastify inject()
```

### Why Bootstrap Separation Matters:
- `buildApp()` in `app.ts` builds the Fastify application instance with all plugins, middleware, and route handlers without binding to a network port.
- Tests instantiate the app directly using `app.inject()` for fast, deterministic, port-conflict-free execution.
- `server.ts` solely manages the process lifecycle, binding to `HOST` and `PORT`, and orchestrating graceful termination on `SIGINT` and `SIGTERM`.

---

## 3. Configuration & Security Baseline

- **Zod-Powered Environment Validation**: At startup, `loadConfig()` strictly parses all environment variables against `EnvSchema`.
- **Fail-Fast Policy**: If mandatory environment variables are malformed or missing, the process terminates immediately with descriptive validation errors rather than silently using unsafe defaults.
- **No Hardcoded Secrets**: All database credentials, secrets, and connection URIs are loaded exclusively from the environment.
- **Bounded Request Limits**: Request bodies are restricted to `1MB` by default (`BODY_LIMIT_BYTES`) to mitigate memory-exhaustion attacks.

---

## 4. Plugins & Cross-Cutting Concerns

1. **Request Correlation (`correlation.ts`)**:
   - Inspects inbound `x-request-id` or `x-correlation-id` headers.
   - If present and matching safe format constraints (`^[a-zA-Z0-9_-]{8,64}$`), the ID is propagated.
   - If missing or malformed, generates a cryptographically random UUID v4.
   - Decorates the request with `req.correlationId` and injects `x-request-id` into all response headers.

2. **Database Integration (`database.ts`)**:
   - Bridges directly to `@eh-home/db-schema`.
   - Uses `createDrizzleClient` and `createDatabasePool`.
   - Exposes `fastify.db`, `fastify.dbPool`, and `fastify.pingDb()`.
   - Automatically terminates the database pool via an `onClose` application hook.

3. **Centralized Error Handling (`error-handler.ts`)**:
   - Implements structured responses conforming to `@eh-home/contracts`' `ApiEnvelope`:
     ```json
     {
       "schemaVersion": 1,
       "success": false,
       "error": {
         "code": "VALIDATION_ERROR | ROUTE_NOT_FOUND | INTERNAL_SERVER_ERROR",
         "message": "Human readable summary",
         "details": {}
       },
       "meta": {
         "requestId": "UUID",
         "timestamp": "ISO-8601"
       }
     }
     ```
   - **Information Leakage Prevention**: Stack traces, SQL queries, internal directory paths, and database connection details are never returned in HTTP responses.

---

## 5. Health & Readiness Semantics

- **Liveness (`GET /health`)**:
  - Confirms the Node.js/Fastify process is running, responding to event loop ticks, and accepting HTTP requests.
  - Does NOT check database connectivity, preventing cascading restarts if downstream infrastructure experiences transient latency.
- **Readiness (`GET /ready`)**:
  - Verifies that all dependencies required to serve API traffic (specifically PostgreSQL connectivity via `SELECT 1`) are healthy.
  - Returns `200 OK` with `{ status: "READY", dependencies: { database: "HEALTHY" } }` when connected.
  - Returns `503 Service Unavailable` with `{ status: "DOWN", dependencies: { database: "UNAVAILABLE" } }` if connectivity fails.

---

## 6. API Versioning & Domain Modular Monolith

- **Operational Endpoints**: Unversioned root paths:
  - `GET /health`
  - `GET /ready`
- **Application Endpoints**: Strict `/api/v1/` prefix:
  - `GET /api/v1/system/info`: Returns runtime environment, service identity, and uptime.
  - `POST /api/v1/system/echo`: Validates request body with Zod and demonstrates the schema -> service -> response pipeline.
- **Domain Module Growth**: Subsequent phases will mount their domain routers under `/api/v1/`:
  - `/api/v1/auth`
  - `/api/v1/homes`
  - `/api/v1/products`
  - `/api/v1/devices`
  - `/api/v1/firmware`
  - `/api/v1/production`
  - `/api/v1/packing`
