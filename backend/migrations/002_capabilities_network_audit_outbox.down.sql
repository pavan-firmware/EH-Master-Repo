-- ==========================================================
-- EH Home Migration 002 Down: Capabilities, Network Identity, Audit & Outbox
-- ==========================================================

DROP TABLE IF EXISTS outbox;
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS network_identity;
DROP TABLE IF EXISTS product_images;
DROP TABLE IF EXISTS product_capabilities;
DROP TABLE IF EXISTS capabilities;
