-- ==========================================================
-- EH Home Migration 027: Expanded Product Catalog Seed Data
-- Phase 39: Smart Fan, Smart Light CCT, Smart Hub, Sensor Node
-- ==========================================================

-- 1. Seed Product Families
INSERT INTO product_families (id, slug, display_name, description)
VALUES
    ('smart_fan', 'smart-fan', 'Smart Ceiling Fans', 'Capacitive multi-step smart ceiling fan controllers'),
    ('smart_lighting', 'smart-lighting', 'Smart Lighting', 'Tunable white and RGBCW intelligent lighting solutions'),
    ('smart_controller', 'smart-hub', 'Smart Hubs & Gateways', 'Multi-protocol smart home gateway and local edge automation controller'),
    ('smart_sensor', 'sensor-node', 'Sensor Nodes', 'Environmental monitoring and telemetry sensor node platform')
ON CONFLICT (id) DO NOTHING;

-- 2. Seed Product Models
INSERT INTO product_models (id, family_id, marketing_name, technical_name, description, generation, brand)
VALUES
    ('eh-fan-gen1', 'smart_fan', 'EH Smart Ceiling Fan', 'EH-FAN-GEN1-ESP32C6', 'Capacitive multi-step smart ceiling fan controller', 1, 'EH'),
    ('eh-light-gen1', 'smart_lighting', 'EH Smart Light CCT', 'EH-LT-GEN1-ESP32C6', 'Tunable white CCT and dimmable smart light', 1, 'EH'),
    ('eh-hub-gen1', 'smart_controller', 'EH Smart Hub Gateway', 'EH-HUB-GEN1-ESP32S3', 'Multi-protocol gateway controller with Matter bridge and Thread border router', 1, 'EH'),
    ('eh-sensor-gen1', 'smart_sensor', 'EH Environmental Sensor Node', 'EH-SN-GEN1-ESP32C6', 'Multi-sensor environmental telemetry node', 1, 'EH')
ON CONFLICT (id) DO NOTHING;

-- 3. Seed Products
INSERT INTO products (id, family_id, display_name, description, schema_version, status)
VALUES
    ('eh-smart-fan', 'smart_fan', 'EH Smart Fan Platform', 'Smart ceiling fan controller platform with speed regulation and energy monitoring', 1, 'PUBLISHED'),
    ('eh-smart-light', 'smart_lighting', 'EH Smart Light Platform', 'Smart lighting platform with brightness and color temperature control', 1, 'PUBLISHED'),
    ('eh-smart-hub', 'smart_controller', 'EH Smart Hub Platform', 'Smart hub and gateway platform for multi-protocol edge coordination', 1, 'PUBLISHED'),
    ('eh-sensor-node', 'smart_sensor', 'EH Sensor Node Platform', 'Environmental sensor node platform for ambient monitoring', 1, 'PUBLISHED')
ON CONFLICT (id) DO NOTHING;

-- 4. Seed Product Variants
INSERT INTO product_variants (
    id, product_id, variant_slug, display_name, channel_count,
    channels, hardware_profile, connectivity_profile, capabilities,
    electrical_specifications, firmware_family, supported_hardware_revisions
) VALUES
(
    'eh-smart-fan-1x', 'eh-smart-fan', '1x', 'EH Smart Fan 1X', 1,
    '[{"channelIndex": 1, "defaultLabel": "Ceiling Fan", "capabilities": ["switch", "relay", "fan_speed", "local_switch", "energy", "ota"]}]'::jsonb,
    '{"schemaVersion": 1, "mcuFamily": "esp32-c6", "flashSizeBytes": 4194304, "psramSizeBytes": null, "hasEnergyMetering": true, "energyMeterChip": "BL0942", "maxRelayAmpsPerChannel": 5.0, "maxTotalAmps": 5.0, "gpioMap": {"relay_ch1": 18, "fan_regulator_ch1": 19, "switch_in_ch1": 4}}'::jsonb,
    '{"schemaVersion": 1, "supportsWifi": true, "wifiStandards": ["802.11b", "802.11g", "802.11n", "802.11ax"], "supportsBle": true, "bleVersion": "5.0", "supportsThread": false, "threadVersion": null, "supportsMatter": false, "matterDeviceType": null}'::jsonb,
    '["switch", "relay", "fan_speed", "local_switch", "energy", "voltage", "current", "power", "ota", "automation", "scene", "schedule"]'::jsonb,
    '{"voltageRange": "90V - 250V AC", "frequencyHz": "50/60Hz", "maxCurrentPerChannelAmps": 5.0, "maxTotalCurrentAmps": 5.0}'::jsonb,
    'esp32c6-fan-platform',
    '["HW_1_0", "HW_1_1"]'::jsonb
),
(
    'eh-smart-light-cct', 'eh-smart-light', 'cct', 'EH Smart Light CCT', 1,
    '[{"channelIndex": 1, "defaultLabel": "Light", "capabilities": ["switch", "brightness", "cct", "energy", "ota"]}]'::jsonb,
    '{"schemaVersion": 1, "mcuFamily": "esp32-c6", "flashSizeBytes": 4194304, "psramSizeBytes": null, "hasEnergyMetering": true, "energyMeterChip": "BL0942", "maxRelayAmpsPerChannel": 2.0, "maxTotalAmps": 2.0, "gpioMap": {"pwm_warm": 18, "pwm_cold": 19, "power_enable": 20}}'::jsonb,
    '{"schemaVersion": 1, "supportsWifi": true, "wifiStandards": ["802.11b", "802.11g", "802.11n", "802.11ax"], "supportsBle": true, "bleVersion": "5.0", "supportsThread": true, "threadVersion": "1.3", "supportsMatter": true, "matterDeviceType": "0x010C"}'::jsonb,
    '["switch", "brightness", "cct", "energy", "voltage", "current", "power", "ota", "automation", "scene", "schedule"]'::jsonb,
    '{"voltageRange": "90V - 250V AC", "frequencyHz": "50/60Hz", "maxCurrentPerChannelAmps": 2.0, "maxTotalCurrentAmps": 2.0}'::jsonb,
    'esp32c6-light-platform',
    '["HW_1_0"]'::jsonb
),
(
    'eh-smart-hub-v1', 'eh-smart-hub', 'v1', 'EH Smart Hub Gateway V1', 1,
    '[{"channelIndex": 1, "defaultLabel": "Gateway Controller", "capabilities": ["switch", "ota", "automation", "schedule"]}]'::jsonb,
    '{"schemaVersion": 1, "mcuFamily": "esp32-s3", "flashSizeBytes": 16777216, "psramSizeBytes": 8388608, "hasEnergyMetering": false, "energyMeterChip": null, "maxRelayAmpsPerChannel": 0.0, "maxTotalAmps": 0.0, "gpioMap": {"status_led": 21, "pairing_btn": 0}}'::jsonb,
    '{"schemaVersion": 1, "supportsWifi": true, "wifiStandards": ["802.11b", "802.11g", "802.11n", "802.11ax"], "supportsBle": true, "bleVersion": "5.0", "supportsThread": true, "threadVersion": "1.3", "supportsMatter": true, "matterDeviceType": "0x0016"}'::jsonb,
    '["switch", "ota", "automation", "schedule"]'::jsonb,
    '{"voltageRange": "5V DC USB-C", "frequencyHz": "DC", "maxCurrentPerChannelAmps": 2.0, "maxTotalCurrentAmps": 2.0}'::jsonb,
    'esp32s3-hub-platform',
    '["HW_1_0"]'::jsonb
),
(
    'eh-sensor-node-v1', 'eh-sensor-node', 'v1', 'EH Environmental Sensor Node V1', 1,
    '[{"channelIndex": 1, "defaultLabel": "Environmental Sensor", "capabilities": ["switch", "ota", "automation"]}]'::jsonb,
    '{"schemaVersion": 1, "mcuFamily": "esp32-c6", "flashSizeBytes": 4194304, "psramSizeBytes": null, "hasEnergyMetering": false, "energyMeterChip": null, "maxRelayAmpsPerChannel": 0.0, "maxTotalAmps": 0.0, "gpioMap": {"i2c_sda": 6, "i2c_scl": 7, "dht_pin": 4}}'::jsonb,
    '{"schemaVersion": 1, "supportsWifi": true, "wifiStandards": ["802.11b", "802.11g", "802.11n", "802.11ax"], "supportsBle": true, "bleVersion": "5.0", "supportsThread": true, "threadVersion": "1.3", "supportsMatter": true, "matterDeviceType": "0x0302"}'::jsonb,
    '["switch", "ota", "automation", "schedule"]'::jsonb,
    '{"voltageRange": "3.3V - 5V DC Battery / USB", "frequencyHz": "DC", "maxCurrentPerChannelAmps": 0.5, "maxTotalCurrentAmps": 0.5}'::jsonb,
    'esp32c6-sensor-platform',
    '["HW_1_0"]'::jsonb
)
ON CONFLICT (id) DO NOTHING;
