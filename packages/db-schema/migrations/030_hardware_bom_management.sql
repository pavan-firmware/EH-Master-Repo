-- Migration: 030_hardware_bom_management.sql
-- Description: EH Home Hardware Revisions, Bill of Materials (BOM), and Product Compatibility
-- Domain: Hardware & BOM Management (Part 06)

CREATE TABLE IF NOT EXISTS hardware_revisions (
    id VARCHAR(64) PRIMARY KEY,
    revision_code VARCHAR(32) NOT NULL,
    product_variant_id VARCHAR(128) NOT NULL REFERENCES product_variants(id) ON DELETE RESTRICT,
    pcb_name VARCHAR(128) NOT NULL,
    pcb_revision VARCHAR(32) NOT NULL DEFAULT 'v1.0',
    display_name VARCHAR(128) NOT NULL,
    lifecycle_status VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    layer_count INTEGER NOT NULL DEFAULT 2,
    mcu_family VARCHAR(32) NOT NULL DEFAULT 'esp32-c6',
    dimensions_mm JSONB,
    pin_map JSONB NOT NULL DEFAULT '{}'::jsonb,
    schematic_asset_url TEXT,
    gerber_asset_url TEXT,
    render_asset_url TEXT,
    design_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    effective_at TIMESTAMPTZ,
    deprecated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_hardware_revisions_variant_code UNIQUE (product_variant_id, revision_code),
    CONSTRAINT chk_hardware_revisions_status CHECK (
        lifecycle_status IN ('DRAFT', 'VALIDATION', 'APPROVED', 'ACTIVE', 'DEPRECATED', 'RETIRED')
    )
);

CREATE INDEX IF NOT EXISTS idx_hardware_revisions_variant ON hardware_revisions(product_variant_id);
CREATE INDEX IF NOT EXISTS idx_hardware_revisions_status ON hardware_revisions(lifecycle_status);
CREATE INDEX IF NOT EXISTS idx_hardware_revisions_code ON hardware_revisions(revision_code);

CREATE TABLE IF NOT EXISTS bom_specifications (
    id VARCHAR(64) PRIMARY KEY,
    hardware_revision_id VARCHAR(64) NOT NULL REFERENCES hardware_revisions(id) ON DELETE RESTRICT,
    version VARCHAR(32) NOT NULL DEFAULT '1.0.0',
    lifecycle_status VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    total_unique_components INTEGER NOT NULL DEFAULT 0,
    notes TEXT,
    effective_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_bom_specifications_rev_version UNIQUE (hardware_revision_id, version),
    CONSTRAINT chk_bom_specifications_status CHECK (
        lifecycle_status IN ('DRAFT', 'ACTIVE', 'DEPRECATED', 'SUPERSEDED')
    )
);

CREATE INDEX IF NOT EXISTS idx_bom_specifications_hardware ON bom_specifications(hardware_revision_id);
CREATE INDEX IF NOT EXISTS idx_bom_specifications_status ON bom_specifications(lifecycle_status);

CREATE TABLE IF NOT EXISTS bom_items (
    id VARCHAR(64) PRIMARY KEY,
    bom_id VARCHAR(64) NOT NULL REFERENCES bom_specifications(id) ON DELETE CASCADE,
    item_index INTEGER NOT NULL,
    reference_designator VARCHAR(64) NOT NULL,
    mpn VARCHAR(128) NOT NULL,
    internal_part_number VARCHAR(64),
    manufacturer VARCHAR(128),
    description TEXT NOT NULL,
    component_category VARCHAR(64) NOT NULL DEFAULT 'OTHER',
    footprint VARCHAR(128) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit VARCHAR(16) NOT NULL DEFAULT 'pcs',
    is_dnf BOOLEAN NOT NULL DEFAULT FALSE,
    vendor_part_number VARCHAR(128),
    unit_cost_inr NUMERIC(10, 4),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_bom_items_bom_index UNIQUE (bom_id, item_index),
    CONSTRAINT uq_bom_items_bom_ref UNIQUE (bom_id, reference_designator)
);

CREATE INDEX IF NOT EXISTS idx_bom_items_bom ON bom_items(bom_id);
CREATE INDEX IF NOT EXISTS idx_bom_items_mpn ON bom_items(mpn);

CREATE TABLE IF NOT EXISTS component_substitutions (
    id VARCHAR(64) PRIMARY KEY,
    bom_item_id VARCHAR(64) NOT NULL REFERENCES bom_items(id) ON DELETE CASCADE,
    substitute_mpn VARCHAR(128) NOT NULL,
    substitute_manufacturer VARCHAR(128),
    approval_status VARCHAR(32) NOT NULL DEFAULT 'APPROVED',
    qualification_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_component_substitutions_status CHECK (
        approval_status IN ('PENDING', 'APPROVED', 'REJECTED')
    )
);

CREATE INDEX IF NOT EXISTS idx_component_substitutions_item ON component_substitutions(bom_item_id);

CREATE TABLE IF NOT EXISTS product_variant_hardware_compatibility (
    id VARCHAR(64) PRIMARY KEY,
    product_variant_id VARCHAR(128) NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
    hardware_revision_id VARCHAR(64) NOT NULL REFERENCES hardware_revisions(id) ON DELETE CASCADE,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    compatibility_notes TEXT,
    verified_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_variant_hardware_compat UNIQUE (product_variant_id, hardware_revision_id)
);

CREATE INDEX IF NOT EXISTS idx_variant_hw_compat_variant ON product_variant_hardware_compatibility(product_variant_id);
CREATE INDEX IF NOT EXISTS idx_variant_hw_compat_hardware ON product_variant_hardware_compatibility(hardware_revision_id);
