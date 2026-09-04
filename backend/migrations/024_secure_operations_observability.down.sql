-- =============================================================================
-- Migration 024 Rollback: Secure Operations, Audit & Platform Observability
-- Phase 31 Database Schema
-- =============================================================================

DROP TABLE IF EXISTS system_health_snapshots;
DROP TABLE IF EXISTS security_audit_records;
DROP TABLE IF EXISTS operational_events;
