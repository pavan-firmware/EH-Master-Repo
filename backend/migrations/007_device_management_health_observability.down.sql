-- =============================================================================
-- Migration 007: Device Management, Health Metrics, Activity & Observability
-- Phase 11 Down Migration
-- =============================================================================

DROP TABLE IF EXISTS device_health_metrics CASCADE;
DROP TABLE IF EXISTS device_activity_logs CASCADE;
