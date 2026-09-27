-- ==============================================================================
-- EH Home Migration 035 Down: Rollback Canonical RBAC & Audit Schema
-- ==============================================================================

DROP TABLE IF EXISTS security_audit_events CASCADE;
DROP TABLE IF EXISTS user_security_principals CASCADE;
