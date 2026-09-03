-- Migration 018 DOWN: Drop Proactive Device Reliability Tables (Phase 25)
-- Drop in reverse dependency order

DROP TABLE IF EXISTS maintenance_recommendations;
DROP TABLE IF EXISTS reliability_health_snapshots;
DROP TABLE IF EXISTS reliability_recovery_attempts;
DROP TABLE IF EXISTS reliability_diagnostics;
DROP TABLE IF EXISTS reliability_incidents;
