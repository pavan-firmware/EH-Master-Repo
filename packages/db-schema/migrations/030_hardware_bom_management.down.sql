-- Migration: 030_hardware_bom_management.down.sql
-- Description: Revert Hardware Revisions, Bill of Materials (BOM), and Product Compatibility
-- Domain: Hardware & BOM Management (Part 06)

DROP TABLE IF EXISTS product_variant_hardware_compatibility;
DROP TABLE IF EXISTS component_substitutions;
DROP TABLE IF EXISTS bom_items;
DROP TABLE IF EXISTS bom_specifications;
DROP TABLE IF EXISTS hardware_revisions;
