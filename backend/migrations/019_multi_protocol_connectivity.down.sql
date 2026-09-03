-- Migration 019 DOWN: Drop Multi-Protocol Device Connectivity Tables (Phase 26)
-- Drop in reverse dependency order

DROP TABLE IF EXISTS transport_health_snapshots;
DROP TABLE IF EXISTS commissioning_sessions;
DROP TABLE IF EXISTS device_connection_states;
DROP TABLE IF EXISTS device_transports;
