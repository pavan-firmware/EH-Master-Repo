-- ==========================================================
-- EH Home Migration 020 (DOWN): Revert Product Discovery & Catalog
-- Phase 27
-- ==========================================================

DROP TABLE IF EXISTS device_add_sessions CASCADE;
DROP TABLE IF EXISTS product_models CASCADE;
