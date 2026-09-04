-- ==========================================================
-- EH Home Migration 020: Product Discovery, Catalog & Consumer Device Add
-- Phase 27
-- ==========================================================

-- 1. Product Models Table
CREATE TABLE IF NOT EXISTS product_models (
    id VARCHAR(64) PRIMARY KEY,
    family_id VARCHAR(64) NOT NULL REFERENCES product_families(id) ON DELETE RESTRICT,
    marketing_name VARCHAR(128) NOT NULL,
    technical_name VARCHAR(128) NOT NULL,
    description TEXT,
    generation INTEGER NOT NULL DEFAULT 1,
    brand VARCHAR(64) NOT NULL DEFAULT 'EH',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Device Add Sessions Table
CREATE TABLE IF NOT EXISTS device_add_sessions (
    id UUID PRIMARY KEY,
    home_id UUID NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entry_mode VARCHAR(32) NOT NULL CHECK (entry_mode IN ('QR_SCAN', 'NEARBY_DISCOVERY', 'MANUAL_CATALOG', 'RE_ADD_RESET', 'MATTER_COMMISSIONING')),
    stage VARCHAR(32) NOT NULL CHECK (stage IN ('PRODUCT_SELECTED', 'COMPATIBILITY_CHECKED', 'DISCOVERING_DEVICE', 'COMMISSIONING', 'REGISTERED', 'CLAIMED', 'CONFIGURED', 'VERIFIED', 'COMPLETED', 'FAILED', 'CANCELLED')),
    product_variant_id VARCHAR(64) REFERENCES product_variants(id) ON DELETE SET NULL,
    device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    commissioning_session_id VARCHAR(64),
    selected_room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
    custom_device_name VARCHAR(128),
    channel_labels JSONB DEFAULT '{}'::jsonb,
    compatibility_status VARCHAR(32),
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_device_add_sessions_home ON device_add_sessions(home_id, stage);
CREATE INDEX IF NOT EXISTS idx_device_add_sessions_user ON device_add_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_product_models_family ON product_models(family_id);

-- 4. Seed Product Families (Ensure switches and sockets exist)
INSERT INTO product_families (id, slug, display_name, description)
VALUES 
    ('smart_switch', 'smart-switch', 'Smart Switches', 'Smart in-wall capacitive and physical relay switchboard products'),
    ('smart_socket', 'smart-socket', 'Smart Sockets', 'Smart wall power socket products with energy monitoring and safety shutters')
ON CONFLICT (id) DO NOTHING;

-- 5. Seed Product Models
INSERT INTO product_models (id, family_id, marketing_name, technical_name, description, generation, brand)
VALUES
    ('eh-switch-gen1', 'smart_switch', 'EH In-Wall Smart Switch', 'EH-SW-GEN1-ESP32C6', 'Modular smart switchboard platform with energy monitoring', 1, 'EH'),
    ('eh-socket-gen1', 'smart_socket', 'EH Smart Wall Socket', 'EH-SK-GEN1-ESP32C6', 'Smart high-power socket platform with independent channel control and energy monitoring', 1, 'EH')
ON CONFLICT (id) DO NOTHING;

-- 6. Seed Products
INSERT INTO products (id, family_id, display_name, description, schema_version, status)
VALUES
    ('eh-smart-switch', 'smart_switch', 'EH Smart Switch Platform', 'Modular smart wall switch platform with energy monitoring', 1, 'PUBLISHED'),
    ('eh-smart-socket', 'smart_socket', 'EH Smart Socket Platform', 'Modular smart wall socket platform with energy monitoring', 1, 'PUBLISHED')
ON CONFLICT (id) DO NOTHING;

-- 7. Seed Variants (1X, 2X, 3X, 4X Switches and 1X, 2X, 3X Sockets)
INSERT INTO product_variants (
    id, product_id, variant_slug, display_name, channel_count,
    channels, hardware_profile, connectivity_profile, capabilities,
    electrical_specifications, firmware_family, supported_hardware_revisions
) VALUES 
(
    'eh-smart-switch-1x', 'eh-smart-switch', '1x', 'EH Smart Switch 1X', 1,
    '[{"channelIndex": 1, "defaultLabel": "Channel 1", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]}]'::jsonb,
    '{"schemaVersion": 1, "mcuFamily": "esp32-c6", "flashSizeBytes": 4194304, "psramSizeBytes": null, "hasEnergyMetering": true, "energyMeterChip": "BL0942", "maxRelayAmpsPerChannel": 16.0, "maxTotalAmps": 16.0, "gpioMap": {"relay_ch1": 18, "switch_in_ch1": 4}}'::jsonb,
    '{"schemaVersion": 1, "supportsWifi": true, "wifiStandards": ["802.11b", "802.11g", "802.11n", "802.11ax"], "supportsBle": true, "bleVersion": "5.0", "supportsThread": false, "threadVersion": null, "supportsMatter": false, "matterDeviceType": null}'::jsonb,
    '["switch", "relay", "local_switch", "energy", "voltage", "current", "power", "ota", "automation", "scene", "schedule"]'::jsonb,
    '{"voltageRange": "90V - 250V AC", "frequencyHz": "50/60Hz", "maxCurrentPerChannelAmps": 16.0, "maxTotalCurrentAmps": 16.0}'::jsonb,
    'esp32c6-switch-platform',
    '["HW_1_0", "HW_1_1"]'::jsonb
),
(
    'eh-smart-switch-2x', 'eh-smart-switch', '2x', 'EH Smart Switch 2X', 2,
    '[{"channelIndex": 1, "defaultLabel": "Channel 1", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]}, {"channelIndex": 2, "defaultLabel": "Channel 2", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]}]'::jsonb,
    '{"schemaVersion": 1, "mcuFamily": "esp32-c6", "flashSizeBytes": 4194304, "psramSizeBytes": null, "hasEnergyMetering": true, "energyMeterChip": "BL0942", "maxRelayAmpsPerChannel": 10.0, "maxTotalAmps": 16.0, "gpioMap": {"relay_ch1": 18, "relay_ch2": 19, "switch_in_ch1": 4, "switch_in_ch2": 5}}'::jsonb,
    '{"schemaVersion": 1, "supportsWifi": true, "wifiStandards": ["802.11b", "802.11g", "802.11n", "802.11ax"], "supportsBle": true, "bleVersion": "5.0", "supportsThread": false, "threadVersion": null, "supportsMatter": false, "matterDeviceType": null}'::jsonb,
    '["switch", "relay", "local_switch", "energy", "voltage", "current", "power", "ota", "automation", "scene", "schedule"]'::jsonb,
    '{"voltageRange": "90V - 250V AC", "frequencyHz": "50/60Hz", "maxCurrentPerChannelAmps": 10.0, "maxTotalCurrentAmps": 16.0}'::jsonb,
    'esp32c6-switch-platform',
    '["HW_1_0", "HW_1_1"]'::jsonb
),
(
    'eh-smart-switch-4x', 'eh-smart-switch', '4x', 'EH Smart Switch 4X', 4,
    '[{"channelIndex": 1, "defaultLabel": "Channel 1", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]}, {"channelIndex": 2, "defaultLabel": "Channel 2", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]}, {"channelIndex": 3, "defaultLabel": "Channel 3", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]}, {"channelIndex": 4, "defaultLabel": "Channel 4", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]}]'::jsonb,
    '{"schemaVersion": 1, "mcuFamily": "esp32-c6", "flashSizeBytes": 4194304, "psramSizeBytes": null, "hasEnergyMetering": true, "energyMeterChip": "BL0942", "maxRelayAmpsPerChannel": 10.0, "maxTotalAmps": 16.0, "gpioMap": {"relay_ch1": 18, "relay_ch2": 19, "relay_ch3": 20, "relay_ch4": 21, "switch_in_ch1": 4, "switch_in_ch2": 5, "switch_in_ch3": 6, "switch_in_ch4": 7}}'::jsonb,
    '{"schemaVersion": 1, "supportsWifi": true, "wifiStandards": ["802.11b", "802.11g", "802.11n", "802.11ax"], "supportsBle": true, "bleVersion": "5.0", "supportsThread": false, "threadVersion": null, "supportsMatter": false, "matterDeviceType": null}'::jsonb,
    '["switch", "relay", "local_switch", "energy", "voltage", "current", "power", "ota", "automation", "scene", "schedule"]'::jsonb,
    '{"voltageRange": "90V - 250V AC", "frequencyHz": "50/60Hz", "maxCurrentPerChannelAmps": 10.0, "maxTotalCurrentAmps": 16.0}'::jsonb,
    'esp32c6-switch-platform',
    '["HW_1_0", "HW_1_1"]'::jsonb
),
(
    'eh-smart-socket-1x', 'eh-smart-socket', '1x', 'EH Smart Socket 1X', 1,
    '[{"channelIndex": 1, "defaultLabel": "Socket 1", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]}]'::jsonb,
    '{"schemaVersion": 1, "mcuFamily": "esp32-c6", "flashSizeBytes": 4194304, "psramSizeBytes": null, "hasEnergyMetering": true, "energyMeterChip": "BL0942", "maxRelayAmpsPerChannel": 16.0, "maxTotalAmps": 16.0, "gpioMap": {"relay_ch1": 18, "switch_in_ch1": 4}}'::jsonb,
    '{"schemaVersion": 1, "supportsWifi": true, "wifiStandards": ["802.11b", "802.11g", "802.11n", "802.11ax"], "supportsBle": true, "bleVersion": "5.0", "supportsThread": false, "threadVersion": null, "supportsMatter": false, "matterDeviceType": null}'::jsonb,
    '["switch", "relay", "local_switch", "energy", "voltage", "current", "power", "ota", "automation", "scene", "schedule"]'::jsonb,
    '{"voltageRange": "90V - 250V AC", "frequencyHz": "50/60Hz", "maxCurrentPerChannelAmps": 16.0, "maxTotalCurrentAmps": 16.0}'::jsonb,
    'esp32c6-socket-platform',
    '["HW_1_0", "HW_1_1"]'::jsonb
),
(
    'eh-smart-socket-2x', 'eh-smart-socket', '2x', 'EH Smart Socket 2X', 2,
    '[{"channelIndex": 1, "defaultLabel": "Socket 1", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]}, {"channelIndex": 2, "defaultLabel": "Socket 2", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]}]'::jsonb,
    '{"schemaVersion": 1, "mcuFamily": "esp32-c6", "flashSizeBytes": 4194304, "psramSizeBytes": null, "hasEnergyMetering": true, "energyMeterChip": "BL0942", "maxRelayAmpsPerChannel": 16.0, "maxTotalAmps": 16.0, "gpioMap": {"relay_ch1": 18, "relay_ch2": 19, "switch_in_ch1": 4, "switch_in_ch2": 5}}'::jsonb,
    '{"schemaVersion": 1, "supportsWifi": true, "wifiStandards": ["802.11b", "802.11g", "802.11n", "802.11ax"], "supportsBle": true, "bleVersion": "5.0", "supportsThread": false, "threadVersion": null, "supportsMatter": false, "matterDeviceType": null}'::jsonb,
    '["switch", "relay", "local_switch", "energy", "voltage", "current", "power", "ota", "automation", "scene", "schedule"]'::jsonb,
    '{"voltageRange": "90V - 250V AC", "frequencyHz": "50/60Hz", "maxCurrentPerChannelAmps": 16.0, "maxTotalCurrentAmps": 16.0}'::jsonb,
    'esp32c6-socket-platform',
    '["HW_1_0", "HW_1_1"]'::jsonb
),
(
    'eh-smart-socket-3x', 'eh-smart-socket', '3x', 'EH Smart Socket 3X', 3,
    '[{"channelIndex": 1, "defaultLabel": "Socket 1", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]}, {"channelIndex": 2, "defaultLabel": "Socket 2", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]}, {"channelIndex": 3, "defaultLabel": "Socket 3", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]}]'::jsonb,
    '{"schemaVersion": 1, "mcuFamily": "esp32-c6", "flashSizeBytes": 4194304, "psramSizeBytes": null, "hasEnergyMetering": true, "energyMeterChip": "BL0942", "maxRelayAmpsPerChannel": 16.0, "maxTotalAmps": 16.0, "gpioMap": {"relay_ch1": 18, "relay_ch2": 19, "relay_ch3": 20, "switch_in_ch1": 4, "switch_in_ch2": 5, "switch_in_ch3": 6}}'::jsonb,
    '{"schemaVersion": 1, "supportsWifi": true, "wifiStandards": ["802.11b", "802.11g", "802.11n", "802.11ax"], "supportsBle": true, "bleVersion": "5.0", "supportsThread": false, "threadVersion": null, "supportsMatter": false, "matterDeviceType": null}'::jsonb,
    '["switch", "relay", "local_switch", "energy", "voltage", "current", "power", "ota", "automation", "scene", "schedule"]'::jsonb,
    '{"voltageRange": "90V - 250V AC", "frequencyHz": "50/60Hz", "maxCurrentPerChannelAmps": 16.0, "maxTotalCurrentAmps": 16.0}'::jsonb,
    'esp32c6-socket-platform',
    '["HW_1_0", "HW_1_1"]'::jsonb
)
ON CONFLICT (id) DO NOTHING;
