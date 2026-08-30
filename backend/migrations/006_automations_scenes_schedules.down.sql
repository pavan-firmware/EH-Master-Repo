-- =============================================================================
-- Migration 006 Down: Revert Automations, Scenes, Schedules, Execution Logs
-- =============================================================================

DROP TABLE IF EXISTS automation_execution_logs CASCADE;
DROP TABLE IF EXISTS schedules CASCADE;
DROP TABLE IF EXISTS automations CASCADE;
DROP TABLE IF EXISTS scenes CASCADE;
