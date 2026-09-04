-- ============================================================================
-- EH Home Migration 022: Matter Ecosystem Interoperability & Multi-Platform Integration
-- ============================================================================

CREATE TABLE IF NOT EXISTS matter_devices (
    id VARCHAR(64) PRIMARY KEY,
    device_id VARCHAR(36) NOT NULL UNIQUE REFERENCES devices(id) ON DELETE CASCADE,
    home_id VARCHAR(64) NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    node_id VARCHAR(32) NOT NULL,
    vendor_id INTEGER NOT NULL DEFAULT 65521,
    product_id INTEGER NOT NULL,
    matter_device_type VARCHAR(64) NOT NULL,
    commissioning_state VARCHAR(32) NOT NULL DEFAULT 'NOT_COMMISSIONED',
    subscription_state VARCHAR(32) NOT NULL DEFAULT 'NONE',
    software_version INTEGER NOT NULL DEFAULT 1,
    software_version_string VARCHAR(32) NOT NULL DEFAULT '1.0.0',
    hardware_version INTEGER NOT NULL DEFAULT 1,
    hardware_version_string VARCHAR(32) NOT NULL DEFAULT 'revA',
    discriminator INTEGER NOT NULL DEFAULT 3840,
    setup_passcode INTEGER NOT NULL,
    last_synchronized_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS matter_fabrics (
    id VARCHAR(64) PRIMARY KEY,
    fabric_id VARCHAR(32) NOT NULL,
    matter_device_id VARCHAR(64) NOT NULL REFERENCES matter_devices(id) ON DELETE CASCADE,
    fabric_index INTEGER NOT NULL,
    fabric_name VARCHAR(64) NOT NULL,
    vendor_id INTEGER NOT NULL,
    controller_node_id VARCHAR(32),
    commissioning_state VARCHAR(32) NOT NULL DEFAULT 'CONNECTED',
    label VARCHAR(128),
    paired_at TIMESTAMPTZ DEFAULT NOW(),
    last_synchronized_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_matter_fabrics_dev_idx UNIQUE (matter_device_id, fabric_index),
    CONSTRAINT uq_matter_fabrics_dev_fab UNIQUE (matter_device_id, fabric_id)
);

CREATE TABLE IF NOT EXISTS matter_endpoints (
    id VARCHAR(64) PRIMARY KEY,
    matter_device_id VARCHAR(64) NOT NULL REFERENCES matter_devices(id) ON DELETE CASCADE,
    endpoint_number INTEGER NOT NULL,
    device_type VARCHAR(64) NOT NULL,
    channel_index INTEGER NOT NULL DEFAULT 1,
    server_clusters JSONB NOT NULL DEFAULT '[]'::jsonb,
    client_clusters JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_matter_endpoint_dev_num UNIQUE (matter_device_id, endpoint_number)
);

CREATE TABLE IF NOT EXISTS matter_sync_state (
    id VARCHAR(64) PRIMARY KEY,
    device_id VARCHAR(36) NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    home_id VARCHAR(64) NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    last_event_id VARCHAR(64),
    last_state_version INTEGER NOT NULL DEFAULT 1,
    last_synced_attributes JSONB NOT NULL DEFAULT '{}'::jsonb,
    sync_status VARCHAR(32) NOT NULL DEFAULT 'SYNCHRONIZED',
    last_error_message TEXT,
    last_synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_matter_sync_state_device UNIQUE (device_id)
);

CREATE TABLE IF NOT EXISTS external_platform_links (
    id VARCHAR(64) PRIMARY KEY,
    home_id VARCHAR(64) NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    device_id VARCHAR(36) NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    platform VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'NOT_CONNECTED',
    external_identifier VARCHAR(128),
    display_name VARCHAR(128) NOT NULL,
    sync_status VARCHAR(32) NOT NULL DEFAULT 'IDLE',
    last_error_message TEXT,
    linked_at TIMESTAMPTZ,
    last_synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_ext_platform_link UNIQUE (device_id, platform)
);

CREATE INDEX IF NOT EXISTS idx_matter_devices_home ON matter_devices(home_id);
CREATE INDEX IF NOT EXISTS idx_matter_fabrics_dev ON matter_fabrics(matter_device_id);
CREATE INDEX IF NOT EXISTS idx_matter_endpoints_dev ON matter_endpoints(matter_device_id);
CREATE INDEX IF NOT EXISTS idx_external_platform_links_home ON external_platform_links(home_id);
CREATE INDEX IF NOT EXISTS idx_external_platform_links_dev ON external_platform_links(device_id);
