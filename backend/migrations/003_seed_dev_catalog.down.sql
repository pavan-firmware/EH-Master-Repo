-- ==========================================================
-- EH Home Seed 003 Down: Revert Development Product Catalog Seed
-- ==========================================================

DELETE FROM product_capabilities WHERE product_variant_id LIKE 'eh-%';
DELETE FROM product_variants WHERE product_id LIKE 'eh-%';
DELETE FROM products WHERE id LIKE 'eh-%';
DELETE FROM product_families WHERE id IN ('smart_switch');
