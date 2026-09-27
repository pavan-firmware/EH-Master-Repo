-- =============================================================================
-- Rollback Migration: 033_production_inventory_packing.down.sql
-- Reverse-dependency drop order
-- =============================================================================


DROP TABLE IF EXISTS packaging_records;
DROP TABLE IF EXISTS dual_scan_verifications;
DROP TABLE IF EXISTS inventory_items;
DROP TABLE IF EXISTS packaging_cartons;
