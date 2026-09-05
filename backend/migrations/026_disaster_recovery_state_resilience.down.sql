-- =============================================================================
-- Migration 026: Disaster Recovery, Backup & State Resilience (Down)
-- Revert Phase 33 Database Schema
-- =============================================================================

DROP TABLE IF EXISTS recovery_integrity_results;
DROP TABLE IF EXISTS recovery_checkpoints;
DROP TABLE IF EXISTS restore_operations;
DROP TABLE IF EXISTS backup_objects;
DROP TABLE IF EXISTS backup_records;
