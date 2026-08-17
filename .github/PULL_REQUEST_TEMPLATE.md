## Summary of Changes
<!-- Provide a clear, concise description of what this PR introduces, fixes, or refactors. -->

## Motivation & Context
<!-- Why is this change required? What issue or feature does it relate to? -->

## Impact Area
- [ ] `packages/contracts` (Canonical Contracts / JSON Schemas)
- [ ] `product-definitions` (Product Metadata / Catalog)
- [ ] `backend` (Fastify / Repositories / Migrations)
- [ ] `smart_home_application_v1` (Flutter Mobile Application)
- [ ] `firmware` (Device Firmware / ESP-IDF)
- [ ] `docs` / `tools` / `CI`

## Breaking Changes & ADR
- [ ] This PR contains NO breaking changes.
- [ ] This PR contains a breaking change and includes an accepted ADR in `docs/adr/`.

## Testing & Verification
<!-- Describe the tests executed and attach terminal output / screenshots. -->
- [ ] `node scripts/validate-repo.js` passes 100% locally.
- [ ] `flutter analyze` passes with 0 issues in `smart_home_application_v1`.
- [ ] `flutter test` passes 100% in `smart_home_application_v1`.

## Pre-Merge Checklist
- [ ] Code follows monorepo style & [CONTRIBUTING.md](../CONTRIBUTING.md) rules.
- [ ] No secrets, private keys, `.env` files, or production credentials are committed.
- [ ] No hardcoded local machine paths (`C:\`, `/Users/`, etc.).
- [ ] Migration scripts have verified UP/DOWN symmetric parity (if applicable).
- [ ] Legacy firmware in `firmware/legacy-v1/` remains untouched.
