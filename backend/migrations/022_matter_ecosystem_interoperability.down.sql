-- ============================================================================
-- Rollback Migration 022: Matter Ecosystem Interoperability & Multi-Platform Integration
-- ============================================================================

DROP TABLE IF EXISTS external_platform_links CASCADE;
DROP TABLE IF EXISTS matter_sync_state CASCADE;
DROP TABLE IF EXISTS matter_endpoints CASCADE;
DROP TABLE IF EXISTS matter_fabrics CASCADE;
DROP TABLE IF EXISTS matter_devices CASCADE;
