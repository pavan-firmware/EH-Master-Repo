# Contributing to EH Home

Thank you for contributing to the EH Home platform. To maintain our high engineering standards, contract consistency, and system reliability, all contributors must adhere to the following governance policies.

---

## 1. Branch Naming Strategy

Branches should be short, descriptive, and prefixed by intent:

| Prefix | Purpose | Example |
|---|---|---|
| `feature/` | New functionality or capability | `feature/fan-speed-profile` |
| `fix/` | Bug fixes and state reconciliations | `fix/outbox-retry-limit` |
| `refactor/` | Code structure improvements | `refactor/contract-validator` |
| `docs/` | Documentation, guides, or ADRs | `docs/adr-002-timeseries` |
| `test/` | Adding or updating test suites | `test/cct-boundary-cases` |
| `chore/` | Tooling, dependencies, or repo maintenance | `chore/ci-workflow-update` |
| `hotfix/` | Urgent production fixes | `hotfix/migration-fk-constraint` |

---

## 2. Commit Message Convention

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <short summary>

[optional body]

[optional footer(s)]
```

### Allowed Types
- `feat`: A new feature or capability renderer
- `fix`: A bug fix
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `docs`: Documentation changes only
- `test`: Adding or correcting tests
- `chore`: Changes to build process, tooling, or repository governance
- `build`: Changes affecting build systems or external dependencies
- `ci`: Changes to CI configuration files and scripts
- `perf`: A code change that improves performance

### Scopes
- `app`: Mobile Flutter application (`smart_home_application_v1`)
- `backend`: Fastify backend, repositories, or migrations
- `contracts`: Canonical schemas, TypeScript interfaces, or validators
- `products`: Product definitions and catalog metadata
- `firmware`: Device firmware platforms
- `simulator`: Device simulator tool
- `repo`: Monorepo root files, tooling, or scripts

### Examples
- `feat(app): add capability-driven fan speed dial`
- `fix(backend): correct device state confidence mapping`
- `test(contracts): add voltage threshold boundary cases`
- `docs(adr): document ADR-001 for capability registry`

---

## 3. Core Architecture Rules & Constraints

1. **Canonical Contracts are Authoritative:** `packages/contracts/` is the single semantic source of truth. Schemas, interfaces, and validator logic must never be duplicated or bypassed.
2. **Architecture Decision Records (ADR):** Any structural, contract, or architecture change requires an accepted ADR in `docs/adr/`.
3. **Physical Switch Precedence:** The physical switch retains immediate authority over hardware state. Cloud commands must respect `OVERRIDDEN` semantics.
4. **App Protection Rule:** `smart_home_application_v1/` is our production mobile client. Changes must pass `flutter analyze` and `flutter test` without regression.
5. **Firmware Safety:** Legacy reference firmware in `firmware/legacy-v1/` must remain preserved and untouched.

---

## 4. Security & Secret Hygiene

- **NEVER Commit Secrets:** Do not commit `.env`, private keys (`.pem`, `.key`), certificates, keystores, or production credentials.
- **Use Environment Variables:** All environment-specific variables must be templated in `.env.example`.
- **Pre-Push Validation:** Ensure secret-free status before pushing.

---

## 5. Pull Request Expectations

Before opening a PR, ensure that:
1. `node scripts/validate-repo.js` passes 100% locally.
2. `flutter analyze` reports zero issues in `smart_home_application_v1`.
3. `flutter test` passes all tests in `smart_home_application_v1`.
4. The PR template (`.github/PULL_REQUEST_TEMPLATE.md`) is fully completed.
