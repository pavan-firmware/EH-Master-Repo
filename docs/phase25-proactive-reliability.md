# EH Home Phase 25: Proactive Device Reliability + Self-Healing Home

## Overview

EH Home Phase 25 introduces a proactive device reliability, diagnostic, and safe self-healing platform. Rather than equating "command acceptance" with device health, Phase 25 establishes a closed-loop reliability model:

$$\text{Reliability Signal} \longrightarrow \text{Incident Detection} \longrightarrow \text{Root Cause Diagnosis} \longrightarrow \text{Safe Recovery Action} \longrightarrow \text{Command Acceptance} \longrightarrow \text{Observation Window} \longrightarrow \text{State + Telemetry Verification} \longrightarrow \text{Final Status}$$

---

## 1. Reliability Signals & Normalization

Reliability degradation is observed across multiple dimensions without creating redundant telemetry:
- **Connectivity Stability**: Heartbeat gaps, offline durations, reconnect bursts, MQTT disconnections.
- **Command Reliability**: Command latency spikes, command timeouts, execution failures.
- **Telemetry Freshness**: Telemetry staleness, reporting gaps, missing sensor measurements.
- **OTA Stability**: Repeated firmware download/apply failures, boot verification rollbacks.

### Signal Deduplication
Identical consecutive signals for the same device and incident type increment the existing incident's `signalCount` and update `lastObservedAt` rather than spawning duplicate open incidents.

---

## 2. Device Health States & Scoring

### Health States
- **`HEALTHY`**: Device is online, commands succeed with low latency, telemetry is fresh, no active high/critical incidents.
- **`DEGRADED`**: Device is functional but experiencing telemetry staleness or non-critical latency.
- **`UNSTABLE`**: Repeated reconnects, intermittent command failures, or medium-severity degradation.
- **`UNAVAILABLE`**: Device is offline, unresponsive to heartbeats, or experiencing critical incident.
- **`UNKNOWN`**: Uninitialized or missing health telemetry.

### Deterministic Health Scoring (0–100)
$$\text{Score} = 0.35 \times S_{\text{connectivity}} + 0.25 \times S_{\text{telemetry}} + 0.25 \times S_{\text{commands}} + 0.15 \times S_{\text{uptime}}$$

---

## 3. Safe Self-Healing Recovery Lifecycle

### Mandatory Closed-Loop Verification Pipeline
1. **Recovery Action Initiated**: Action record created in `PENDING` state.
2. **Action Executed**: Sent to device transport. Status transitions to `EXECUTING`.
3. **Command Accepted**: Transport confirms receipt. Status transitions to `VERIFYING`.
4. **Observation Window**: System waits for device state propagation.
5. **Outcome Verification**: Re-reads device state, connectivity, and telemetry freshness.
6. **Result Classification**:
   - `RECOVERED`: Device returns to `HEALTHY` state. Incident is marked `AUTO_RESOLVED`.
   - `PARTIALLY_RECOVERED`: Device reaches `DEGRADED` state.
   - `FAILED`: Device remains `UNSTABLE` or `UNAVAILABLE`.

### Guardrails & Safety Constraints
- **Zero Destructive Actions**: `FACTORY_RESET` and credential wipes are strictly prohibited in self-healing workflows.
- **Retry Budget**: Maximum of 3 recovery attempts per incident.
- **Cooldown**: 300-second cooldown between recovery attempts.
- **Anti-Fighting Manual Override**: Automatic recovery is skipped if manual user actions occurred within the last 300 seconds.
- **Sensitive Context Guards**: Auto-recovery is deferred when home context is in `SLEEP` or `VACATION` mode.

---

## 4. REST API Specification

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/reliability/homes/:homeId/fleet` | Home fleet health summary |
| `GET` | `/api/v1/reliability/homes/:homeId/incidents` | Active incidents for home |
| `GET` | `/api/v1/reliability/homes/:homeId/maintenance` | Maintenance recommendations |
| `GET` | `/api/v1/reliability/devices/:deviceId/health` | Single device health snapshot |
| `GET` | `/api/v1/reliability/devices/:deviceId/incidents` | Device incident history |
| `GET` | `/api/v1/reliability/devices/:deviceId/recovery-history` | Device recovery attempt audit trail |
| `GET` | `/api/v1/reliability/incidents/:incidentId` | Single incident details |
| `POST` | `/api/v1/reliability/incidents/:incidentId/diagnose` | Run root-cause diagnosis |
| `POST` | `/api/v1/reliability/incidents/:incidentId/recover` | Initiate recovery action |
| `POST` | `/api/v1/reliability/recovery/:attemptId/verify` | Verify recovery outcome |
| `POST` | `/api/v1/reliability/maintenance/:id/approve` | Approve maintenance task |
| `POST` | `/api/v1/reliability/maintenance/:id/reject` | Reject maintenance task |

---

## 5. Flutter Presentation Components

- **`DeviceReliabilityPage`**: Per-device score card, factor bar charts, and non-destructive action chips.
- **`FleetHealthPage`**: Home-level fleet score hero, device state distribution, and active incident list.
- **`DeviceDiagnosticsPage`**: Root-cause diagnostic runner and evidence viewer.
- **`RecoveryHistoryPage`**: Complete lifecycle timeline (Action $\to$ Accepted $\to$ Verified $\to$ Result).
- **`MaintenanceRecommendationsPage`**: Advisory maintenance advice with step-by-step resolution guides.
