-- =============================================================================
-- Migration 025 Rollback: Secure Device Identity, Trust & Credential Lifecycle
-- Phase 32 Database Schema
-- =============================================================================

DROP TABLE IF EXISTS device_provisioning_records;
DROP TABLE IF EXISTS device_revocations;
DROP TABLE IF EXISTS device_credential_lifecycle;
DROP TABLE IF EXISTS device_trust_states;
