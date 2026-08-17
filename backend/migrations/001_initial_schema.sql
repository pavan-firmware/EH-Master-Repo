-- ==========================================================
-- EH Home Migration 001: Initial Core Relational Foundation
-- ==========================================================

-- 1. Identity & Access
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS homes (
    id UUID PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    timezone VARCHAR(64) NOT NULL DEFAULT 'UTC',
    address TEXT,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS home_memberships (
    id UUID PRIMARY KEY,
    home_id UUID NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(32) NOT NULL CHECK (role IN ('OWNER', 'ADMIN', 'MEMBER', 'GUEST')),
    invited_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    accepted_at TIMESTAMPTZ,
    UNIQUE (home_id, user_id)
);

CREATE TABLE IF NOT EXISTS floors (
    id UUID PRIMARY KEY,
    home_id UUID NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    name VARCHAR(64) NOT NULL,
    level INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rooms (
    id UUID PRIMARY KEY,
    home_id UUID NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    floor_id UUID REFERENCES floors(id) ON DELETE SET NULL,
    name VARCHAR(64) NOT NULL,
    icon_key VARCHAR(64) NOT NULL DEFAULT 'default',
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Product Catalog Foundation
CREATE TABLE IF NOT EXISTS product_families (
    id VARCHAR(64) PRIMARY KEY,
    slug VARCHAR(64) UNIQUE NOT NULL,
    display_name VARCHAR(128) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS products (
    id VARCHAR(64) PRIMARY KEY,
    family_id VARCHAR(64) NOT NULL REFERENCES product_families(id) ON DELETE RESTRICT,
    display_name VARCHAR(128) NOT NULL,
    description TEXT,
    schema_version INTEGER NOT NULL DEFAULT 1,
    status VARCHAR(32) NOT NULL DEFAULT 'PUBLISHED' CHECK (status IN ('DRAFT', 'STAGED', 'PUBLISHED', 'DEPRECATED', 'RETIRED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS product_variants (
    id VARCHAR(64) PRIMARY KEY,
    product_id VARCHAR(64) NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    variant_slug VARCHAR(64) NOT NULL,
    display_name VARCHAR(128) NOT NULL,
    channel_count INTEGER NOT NULL DEFAULT 1,
    channels JSONB NOT NULL,
    hardware_profile JSONB NOT NULL,
    connectivity_profile JSONB NOT NULL,
    capabilities JSONB NOT NULL,
    electrical_specifications JSONB NOT NULL,
    firmware_family VARCHAR(64) NOT NULL,
    supported_hardware_revisions JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Device Identity & Hardware State
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY,
    serial_number VARCHAR(128) UNIQUE NOT NULL,
    product_variant_id VARCHAR(64) NOT NULL REFERENCES product_variants(id) ON DELETE RESTRICT,
    hardware_revision VARCHAR(32) NOT NULL,
    firmware_version VARCHAR(32) NOT NULL DEFAULT '1.0.0',
    firmware_family VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS device_credentials (
    device_id UUID PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
    mqtt_username VARCHAR(128) UNIQUE NOT NULL,
    mqtt_password_hash VARCHAR(255) NOT NULL,
    tls_client_cert_fingerprint VARCHAR(64),
    local_session_key_hash VARCHAR(255) NOT NULL,
    credential_state VARCHAR(32) NOT NULL CHECK (credential_state IN ('FACTORY', 'PROVISIONED', 'CLAIMED', 'ACTIVE', 'ROTATED', 'REVOKED', 'RESET')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    rotated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS device_authorizations (
    device_id UUID PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
    home_id UUID NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
    custom_name VARCHAR(128) NOT NULL,
    channel_labels JSONB DEFAULT '{}'::jsonb,
    claimed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    claimed_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS device_state (
    device_id UUID PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
    connection_state VARCHAR(32) NOT NULL DEFAULT 'OFFLINE' CHECK (connection_state IN ('ONLINE', 'STALE', 'OFFLINE')),
    last_seen_at TIMESTAMPTZ,
    last_command_id UUID,
    last_event_id UUID,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS channel_state (
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    channel_index INTEGER NOT NULL,
    desired_state JSONB DEFAULT '{}'::jsonb,
    reported_state JSONB DEFAULT '{}'::jsonb,
    confidence VARCHAR(32) NOT NULL DEFAULT 'UNKNOWN' CHECK (confidence IN ('UNKNOWN', 'PENDING', 'CONFIRMED', 'FAILED', 'UNAVAILABLE')),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (device_id, channel_index)
);

CREATE TABLE IF NOT EXISTS device_commands (
    id UUID PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    channel_index INTEGER NOT NULL,
    action VARCHAR(64) NOT NULL,
    params JSONB NOT NULL DEFAULT '{}'::jsonb,
    idempotency_key VARCHAR(128) NOT NULL,
    source VARCHAR(32) NOT NULL CHECK (source IN ('APP', 'PHYSICAL_SWITCH', 'AUTOMATION', 'MATTER', 'VOICE', 'SYSTEM')),
    status VARCHAR(32) NOT NULL DEFAULT 'CREATED' CHECK (status IN ('CREATED', 'QUEUED', 'SENT', 'ACKNOWLEDGED', 'APPLIED', 'FAILED', 'TIMEOUT', 'EXPIRED')),
    failure_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS device_events (
    id UUID PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    channel_index INTEGER NOT NULL,
    event_type VARCHAR(64) NOT NULL,
    source VARCHAR(32) NOT NULL CHECK (source IN ('APP', 'PHYSICAL_SWITCH', 'AUTOMATION', 'MATTER', 'VOICE', 'SYSTEM')),
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    sequence_number BIGINT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index frequently queried relations
CREATE INDEX IF NOT EXISTS idx_home_memberships_user ON home_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_device_auth_home ON device_authorizations(home_id);
CREATE INDEX IF NOT EXISTS idx_device_events_device_ts ON device_events(device_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_device_commands_device_status ON device_commands(device_id, status);
