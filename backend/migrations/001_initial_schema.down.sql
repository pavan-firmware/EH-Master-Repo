-- ==========================================================
-- EH Home Migration 001 Down: Rollback Core Schema
-- ==========================================================

DROP TABLE IF EXISTS device_events;
DROP TABLE IF EXISTS device_commands;
DROP TABLE IF EXISTS channel_state;
DROP TABLE IF EXISTS device_state;
DROP TABLE IF EXISTS device_authorizations;
DROP TABLE IF EXISTS device_credentials;
DROP TABLE IF EXISTS devices;
DROP TABLE IF EXISTS product_variants;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS product_families;
DROP TABLE IF EXISTS rooms;
DROP TABLE IF EXISTS floors;
DROP TABLE IF EXISTS home_memberships;
DROP TABLE IF EXISTS homes;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS users;
