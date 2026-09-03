# EH Home — Phase 23: Presence, Context Intelligence + Context-Aware Automation

## 1. Overview & Architectural Goals
Phase 23 introduces software-defined presence signal reconciliation, home occupancy determination, inferred room context, a 4-tier context precedence state machine, and context-aware automation integration into the EH Home Smart Home platform.

No physical hardware modifications were made. The engine runs on top of the existing microservices architecture, integrating with the Phase 10/20 Automation Engine, Phase 15 Notification Service, Realtime Event Bus (SSE), and Phase 19–22 Energy Intelligence systems.

---

## 2. Canonical Contracts & Schemas
- **Schema**: `packages/contracts/context/presence-context.schema.json`
- **TypeScript Types**: `packages/contracts/context/index.ts`
- **Contract Tests**: `packages/contracts/tests/contract-test.js` (Section 11, 81/81 assertions passed).

### Core Data Models
1. **`PresenceSignal`**: Ingested signal snapshot with user ID, source, state, confidence score, evidence, and TTL expiry.
2. **`PresenceSnapshot`**: Reconciled whole-home occupancy state (`HOME`, `AWAY`, `UNKNOWN`, `SLEEP`), active user count, per-user state map, and room occupancy inferences.
3. **`ContextOverride`**: Manual user override (`VACATION`, `SLEEP`, `HOME`, `AWAY`, `GUEST`, `QUIET_HOURS`) with duration and reason.
4. **`HomeContext`**: Current active context mode, precedence tier, override reference, vacation flag, and occupancy status.
5. **`ContextTransition`**: Audit log of context transitions with trigger source and evidence.

---

## 3. Signal Reconciliation & Source Confidence Matrix
Incoming presence signals are weighted based on source reliability:
- **`manual`**: 1.0 (100% confidence)
- **`mobile_app`**: 0.90 (90% confidence)
- **`lan_wifi`**: 0.80 (80% confidence)
- **`ble`**: 0.75 (75% confidence)
- **`sensor`**: 0.70 (70% confidence)
- **`device_activity`**: 0.65 (65% confidence)

### Stale Signal Policy & Expiration
- Signals have a default TTL of 30 minutes.
- Expired signals resolve to `UNKNOWN` with `isStale: true`.
- Insufficient or missing evidence resolves safely to `UNKNOWN` (the system never assumes `AWAY` without confirmed evidence).

---

## 4. Deterministic Whole-Home Aggregation Rules
1. **$\ge 1$ Active Trusted User `HOME`** $\implies$ Whole-home presence is `HOME` (`isOccupied = true`).
2. **All Active Trusted Users `AWAY`** $\implies$ Whole-home presence is `AWAY` (`isOccupied = false`).
3. **Missing / Stale / Mixed Evidence** $\implies$ Whole-home presence is `UNKNOWN` (`isOccupied = false`).

---

## 5. Context Precedence State Machine
The context engine resolves active mode according to a strict deterministic hierarchy:
1. **Tier 1: `MANUAL_OVERRIDE`** (Active manual override such as `VACATION`, `SLEEP`, `GUEST`). Suppresses automatic presence changes.
2. **Tier 2: `SCHEDULED_WINDOW`** (Scheduled quiet hours or sleep windows).
3. **Tier 3: `RECONCILED_PRESENCE`** (Driven by aggregated presence: `HOME` $\to$ `HOME`, `AWAY` $\to$ `AWAY`).
4. **Tier 4: `DEFAULT_FALLBACK`** (Baseline `HOME`).

---

## 6. Context-Aware Automations & Anti-Fighting Guard
- **Context Condition Evaluators**: `home_context`, `presence_state`, `home_occupied`, `home_empty`, `presence_confidence`, `context_transition`.
- **Manual Command Priority**: When a user manually toggles a device, automated commands targeting that device are suppressed for a 5-minute cooldown window to prevent automation fighting.
- **Away Energy Guard**: When home is in `AWAY` or `VACATION` mode, unexpected power draw ($> 500\,\text{W}$) triggers an anomaly event.

---

## 7. Database Migration & Repositories
- Migration: `016_presence_context_intelligence.sql` (UP) & `016_presence_context_intelligence.down.sql` (DOWN).
- Total Tables: 61 database tables verified symmetric across UP and DOWN migrations.
- Repositories:
  - `PresenceSignalRepository`
  - `PresenceStateRepository`
  - `HomeContextRepository`
  - `ContextOverrideRepository`
  - `ContextTransitionRepository`

---

## 8. Flutter Presentation & UI Features
- `PresenceDashboardPage`: Whole-home occupancy card, quick manual presence toggles, member presence list, inferred room occupancy.
- `HomeContextPage`: Context hero card, mode selector chips, precedence hierarchy legend, transition history.
- `PresenceSourcesPage`: Multi-source confidence matrix, TTL policy description, raw signal stream.
- `ContextAutomationPage`: Context rule triggers, manual command priority status, away energy guard.
- `VacationModePage`: Duration selector, security simulation features, activate/end vacation mode controls.
