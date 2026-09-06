-- ==========================================================
-- EH Home Migration 027 (DOWN): Revert Expanded Product Catalog Seed
-- Phase 39: Smart Fan, Smart Light CCT, Smart Hub, Sensor Node
-- ==========================================================

DELETE FROM product_variants WHERE id IN ('eh-smart-fan-1x', 'eh-smart-light-cct', 'eh-smart-hub-v1', 'eh-sensor-node-v1');
DELETE FROM products WHERE id IN ('eh-smart-fan', 'eh-smart-light', 'eh-smart-hub', 'eh-sensor-node');
DELETE FROM product_models WHERE id IN ('eh-fan-gen1', 'eh-light-gen1', 'eh-hub-gen1', 'eh-sensor-gen1');
DELETE FROM product_families WHERE id IN ('smart_fan', 'smart_lighting', 'smart_controller', 'smart_sensor');
