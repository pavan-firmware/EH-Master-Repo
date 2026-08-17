# Repository Governance & Monorepo Architecture

This document defines the structural boundaries, ownership, and governance rules for the **EH Home** monorepo.

---

## 1. Directory Ownership & Boundaries

```
SMART_HOME_V1/
├── assets/                  # Non-code brand assets, iconography, and visual guidelines
├── backend/                 # Backend modular monolith (Fastify + PostgreSQL + Redis)
│   ├── migrations/          # Symmetric UP/DOWN SQL migrations
│   ├── src/                 # Repositories, domain models, and catalog services
│   └── tests/               # Database integration, hardening & catalog test suites
├── docs/                    # Architecture specifications, planning, and ADRs
│   ├── adr/                 # Architecture Decision Records
│   ├── architecture/        # Authoritative system architecture specifications
│   ├── contracts/           # Contract documentation & deterministic energy protocol
│   └── planning/            # Historical implementation plans and prompts
├── firmware/                # Device firmware platforms
│   └── legacy-v1/           # Preserved historical reference implementation
├── packages/
│   └── contracts/           # Canonical Draft-07 JSON Schemas, TypeScript types & validators
├── product-definitions/     # Metadata-driven product catalog definitions (SKUs)
│   └── smart-switch/3x/     # EH Smart Switch 3X metadata & hardware profiles
├── smart_home_application_v1/ # Production Flutter mobile & tablet application
│   ├── lib/                 # Core capability engine, theme tokens, feature pages
│   └── test/                # Unit, widget, theme & capability engine test suites
├── tools/
│   └── device-simulator/    # Contract-compliant device hardware simulator
├── .env.example             # Local development environment template
└── docker-compose.yml       # Dev PostgreSQL, Redis, and EMQX containers
```

---

## 2. Canonical Sources of Truth

1. **Semantic Contracts:** [`packages/contracts/`](../../packages/contracts/) is the sole authoritative definition for all network, state, telemetry, and command payloads across all platforms. Backend and Flutter must consume or mirror these contracts without ad-hoc mutations.
2. **Product Catalog Definitions:** [`product-definitions/`](../../product-definitions/) is the canonical source for physical device capabilities, channel structures, electrical specifications, and hardware profiles.
3. **Database Persistence:** [`backend/migrations/`](../../backend/migrations/) is the authoritative schema for relational storage. Migrations must be strictly ordered, symmetric, and non-destructive.
4. **Mobile Client:** [`smart_home_application_v1/`](../../smart_home_application_v1/) is the consumer mobile client. It consumes resolved capabilities and renders them through registered UI primitives.

---

## 3. Architecture Change Governance (ADR Policy)

The EH Home architecture is currently locked at **v3.2**. Any proposal to alter canonical contracts, data schemas, transport boundaries, or core principles requires an **Architecture Decision Record (ADR)** located in `docs/adr/`.

Each ADR must adhere to the template in [`docs/adr/ADR-000-template.md`](../adr/ADR-000-template.md):
- **Title & Status:** (`DRAFT`, `PROPOSED`, `ACCEPTED`, `SUPERSEDED`)
- **Context & Problem Statement**
- **Decision & Rationale**
- **Alternatives Considered**
- **Consequences & Migration Impact**
