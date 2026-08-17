-- ==========================================================
-- EH Home Migration 002: Capabilities, Network Identity, Audit & Outbox
-- ==========================================================

-- 1. Canonical Capability Registry Table
CREATE TABLE IF NOT EXISTS capabilities (
    capability_id VARCHAR(64) PRIMARY KEY,
    version INTEGER NOT NULL DEFAULT 1,
    display_name VARCHAR(128) NOT NULL,
    description TEXT,
    properties JSONB NOT NULL DEFAULT '{}'::jsonb,
    commands JSONB NOT NULL DEFAULT '[]'::jsonb,
    events JSONB NOT NULL DEFAULT '[]'::jsonb,
    telemetry_fields JSONB NOT NULL DEFAULT '[]'::jsonb,
    ui_component_hint VARCHAR(64) NOT NULL,
    automation_triggers JSONB NOT NULL DEFAULT '[]'::jsonb,
    automation_actions JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Product Variant to Capabilities Junction (Structured Relational View)
CREATE TABLE IF NOT EXISTS product_capabilities (
    product_variant_id VARCHAR(64) NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
    capability_id VARCHAR(64) NOT NULL REFERENCES capabilities(capability_id) ON DELETE RESTRICT,
    channel_index INTEGER,
    config JSONB DEFAULT '{}'::jsonb,
    PRIMARY KEY (product_variant_id, capability_id, channel_index)
);

-- 3. Product Catalog Images Table
CREATE TABLE IF NOT EXISTS product_images (
    id UUID PRIMARY KEY,
    product_variant_id VARCHAR(64) NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
    kind VARCHAR(32) NOT NULL CHECK (kind IN ('HERO', 'FRONT', 'BACK', 'INSTALL', 'WIRING', 'THUMB')),
    url TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Ephemeral Network Identity (Decoupled from Immutable DeviceIdentity)
CREATE TABLE IF NOT EXISTS network_identity (
    device_id UUID PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
    wifi_mac_address VARCHAR(32),
    thread_extended_address VARCHAR(32),
    current_ipv4_address VARCHAR(45),
    current_ipv6_address VARCHAR(45),
    ble_mac_address VARCHAR(32),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Append-Only Audit Log
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY,
    actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    home_id UUID REFERENCES homes(id) ON DELETE SET NULL,
    action VARCHAR(128) NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    ip_address VARCHAR(45),
    correlation_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Transactional Outbox Foundation
CREATE TABLE IF NOT EXISTS outbox (
    id UUID PRIMARY KEY,
    event_type VARCHAR(128) NOT NULL,
    aggregate_type VARCHAR(64) NOT NULL,
    aggregate_id VARCHAR(128) NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'PUBLISHED', 'FAILED')),
    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

-- Additional Indexes for Query Patterns
CREATE INDEX IF NOT EXISTS idx_channel_state_device ON channel_state(device_id);
CREATE INDEX IF NOT EXISTS idx_device_events_seq ON device_events(device_id, sequence_number ASC);
CREATE INDEX IF NOT EXISTS idx_device_commands_idem ON device_commands(device_id, idempotency_key);
CREATE INDEX IF NOT EXISTS idx_audit_logs_home ON audit_logs(home_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_outbox_pending ON outbox(status, created_at ASC) WHERE status = 'PENDING';
