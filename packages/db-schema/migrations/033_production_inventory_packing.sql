-- =============================================================================
-- Migration: 033_production_inventory_packing.sql
-- Description: Production floor inventory, dual-scan verification & packing audit
-- Explicit Non-Destructive Delete Policy (ON DELETE RESTRICT) for Audit History
-- =============================================================================

-- 1. Packaging Cartons
CREATE TABLE IF NOT EXISTS packaging_cartons (
    id VARCHAR(128) PRIMARY KEY,
    carton_code VARCHAR(128) NOT NULL UNIQUE,
    product_variant_id VARCHAR(128) NOT NULL REFERENCES product_variants(id) ON DELETE RESTRICT,
    hardware_revision VARCHAR(32) NOT NULL,
    target_capacity INTEGER NOT NULL DEFAULT 1,
    packed_count INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(32) NOT NULL DEFAULT 'OPEN',
    sealed_at TIMESTAMP WITH TIME ZONE,
    operator_user_id VARCHAR(128),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cartons_variant_status ON packaging_cartons(product_variant_id, status);
CREATE INDEX IF NOT EXISTS idx_cartons_code ON packaging_cartons(carton_code);

-- 2. Manufacturing Inventory Items
CREATE TABLE IF NOT EXISTS inventory_items (
    id VARCHAR(128) PRIMARY KEY,
    device_id VARCHAR(128) NOT NULL UNIQUE REFERENCES devices(id) ON DELETE RESTRICT,
    serial_number VARCHAR(128) NOT NULL UNIQUE REFERENCES devices(serial_number) ON DELETE RESTRICT,
    product_variant_id VARCHAR(128) NOT NULL REFERENCES product_variants(id) ON DELETE RESTRICT,
    hardware_revision VARCHAR(32) NOT NULL,
    firmware_family VARCHAR(64) NOT NULL,
    firmware_version VARCHAR(32) NOT NULL,
    trace_id VARCHAR(128) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'PROVISIONED',
    carton_id VARCHAR(128) REFERENCES packaging_cartons(id) ON DELETE SET NULL,
    qr_token VARCHAR(64),
    qr_uri VARCHAR(255),
    qc_status VARCHAR(32) NOT NULL DEFAULT 'PASS',
    registered_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    verified_at TIMESTAMP WITH TIME ZONE,
    packed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventory_status ON inventory_items(status);
CREATE INDEX IF NOT EXISTS idx_inventory_serial ON inventory_items(serial_number);
CREATE INDEX IF NOT EXISTS idx_inventory_carton ON inventory_items(carton_id);
CREATE INDEX IF NOT EXISTS idx_inventory_qr_token ON inventory_items(qr_token);

-- 3. Dual-Scan Verification Audit Records
CREATE TABLE IF NOT EXISTS dual_scan_verifications (
    id VARCHAR(128) PRIMARY KEY,
    device_id VARCHAR(128) NOT NULL REFERENCES devices(id) ON DELETE RESTRICT,
    serial_number VARCHAR(128) NOT NULL,
    scanned_qr_token VARCHAR(64) NOT NULL,
    scanned_qr_uri VARCHAR(255) NOT NULL,
    carton_id VARCHAR(128) REFERENCES packaging_cartons(id) ON DELETE RESTRICT,
    is_match BOOLEAN NOT NULL,
    verification_status VARCHAR(32) NOT NULL,
    rejection_reason TEXT,
    station_id VARCHAR(64) NOT NULL,
    operator_user_id VARCHAR(128),
    verified_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dual_scan_device ON dual_scan_verifications(device_id);
CREATE INDEX IF NOT EXISTS idx_dual_scan_serial ON dual_scan_verifications(serial_number);
CREATE INDEX IF NOT EXISTS idx_dual_scan_verified_at ON dual_scan_verifications(verified_at);

-- 4. Packaging Audit Records (Strict Immutable Audit Trail)
CREATE TABLE IF NOT EXISTS packaging_records (
    id VARCHAR(128) PRIMARY KEY,
    trace_id VARCHAR(128) NOT NULL,
    device_id VARCHAR(128) NOT NULL REFERENCES devices(id) ON DELETE RESTRICT,
    serial_number VARCHAR(128) NOT NULL,
    product_variant_id VARCHAR(128) NOT NULL REFERENCES product_variants(id) ON DELETE RESTRICT,
    hardware_revision VARCHAR(32) NOT NULL,
    firmware_family VARCHAR(64) NOT NULL,
    firmware_version VARCHAR(32) NOT NULL,
    carton_id VARCHAR(128) NOT NULL REFERENCES packaging_cartons(id) ON DELETE RESTRICT,
    verification_id VARCHAR(128) NOT NULL REFERENCES dual_scan_verifications(id) ON DELETE RESTRICT,
    station_id VARCHAR(64) NOT NULL,
    operator_user_id VARCHAR(128),
    packed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_packaging_records_carton ON packaging_records(carton_id);
CREATE INDEX IF NOT EXISTS idx_packaging_records_device ON packaging_records(device_id);
CREATE INDEX IF NOT EXISTS idx_packaging_records_serial ON packaging_records(serial_number);
CREATE INDEX IF NOT EXISTS idx_packaging_records_trace ON packaging_records(trace_id);
