-- ==========================================================
-- EH Home Seed 003: Development Product Catalog & Capabilities
-- Clearly marked as development baseline seed data.
-- ==========================================================

-- 1. Seed Product Family
INSERT INTO product_families (id, slug, display_name, description)
VALUES (
    'smart_switch',
    'smart-switch',
    'Smart Switches',
    'Smart in-wall capacitive and physical relay switchboard products'
) ON CONFLICT (id) DO NOTHING;

-- 2. Seed Product
INSERT INTO products (id, family_id, display_name, description, schema_version, status)
VALUES (
    'eh-smart-switch',
    'smart_switch',
    'EH Smart Switch Platform',
    'Modular smart wall switch platform with energy monitoring',
    1,
    'PUBLISHED'
) ON CONFLICT (id) DO NOTHING;

-- 3. Seed Product Variant (EH Smart Switch 3X)
INSERT INTO product_variants (
    id, product_id, variant_slug, display_name, channel_count,
    channels, hardware_profile, connectivity_profile, capabilities,
    electrical_specifications, firmware_family, supported_hardware_revisions
) VALUES (
    'eh-smart-switch-3x',
    'eh-smart-switch',
    '3x',
    'EH Smart Switch 3X',
    3,
    '[
        {"channelIndex": 1, "defaultLabel": "Channel 1", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]},
        {"channelIndex": 2, "defaultLabel": "Channel 2", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]},
        {"channelIndex": 3, "defaultLabel": "Channel 3", "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]}
    ]'::jsonb,
    '{
        "schemaVersion": 1,
        "mcuFamily": "esp32-c6",
        "flashSizeBytes": 4194304,
        "psramSizeBytes": null,
        "hasEnergyMetering": true,
        "energyMeterChip": "BL0942",
        "maxRelayAmpsPerChannel": 10.0,
        "maxTotalAmps": 16.0,
        "gpioMap": {"relay_ch1": 18, "relay_ch2": 19, "relay_ch3": 20, "switch_in_ch1": 4, "switch_in_ch2": 5, "switch_in_ch3": 6}
    }'::jsonb,
    '{
        "schemaVersion": 1,
        "supportsWifi": true,
        "wifiStandards": ["802.11b", "802.11g", "802.11n", "802.11ax"],
        "supportsBle": true,
        "bleVersion": "5.0",
        "supportsThread": false,
        "threadVersion": null,
        "supportsMatter": false,
        "matterDeviceType": null
    }'::jsonb,
    '["switch", "relay", "local_switch", "energy", "voltage", "current", "power", "ota", "automation", "scene", "schedule"]'::jsonb,
    '{
        "voltageRange": "90V - 250V AC",
        "frequencyHz": "50/60Hz",
        "maxCurrentPerChannelAmps": 10.0,
        "maxTotalCurrentAmps": 16.0
    }'::jsonb,
    'esp32c6-switch-platform',
    '["HW_1_0", "HW_1_1"]'::jsonb
) ON CONFLICT (id) DO NOTHING;

-- 4. Seed Core Capabilities
INSERT INTO capabilities (capability_id, version, display_name, description, properties, commands, events, telemetry_fields, ui_component_hint, automation_triggers, automation_actions)
VALUES
(
    'switch', 1, 'Switch', 'Binary power control',
    '{"power": {"type": "boolean", "readable": true, "writable": true}}'::jsonb,
    '[{"action": "setPower", "params": {"value": {"type": "boolean"}}}, {"action": "toggle"}]'::jsonb,
    '["switch.on", "switch.off"]'::jsonb,
    '[]'::jsonb,
    'EHSwitchCard',
    '["switch.on", "switch.off"]'::jsonb,
    '["setPower", "toggle"]'::jsonb
),
(
    'relay', 1, 'Relay Actuator', 'Physical electromechanical relay output',
    '{"closed": {"type": "boolean", "readable": true, "writable": true}}'::jsonb,
    '[{"action": "setClosed", "params": {"value": {"type": "boolean"}}}]'::jsonb,
    '["relay.opened", "relay.closed"]'::jsonb,
    '[]'::jsonb,
    'EHRelayIndicator',
    '["relay.opened", "relay.closed"]'::jsonb,
    '["setClosed"]'::jsonb
),
(
    'local_switch', 1, 'Physical Switch Input', 'Physical manual wall switch interrupt',
    '{"lastToggleTimestamp": {"type": "string", "readable": true, "writable": false}}'::jsonb,
    '[]'::jsonb,
    '["local_switch.toggled", "local_switch.held"]'::jsonb,
    '[]'::jsonb,
    'EHManualControlBadge',
    '["local_switch.toggled", "local_switch.held"]'::jsonb,
    '[]'::jsonb
),
(
    'energy', 1, 'Energy Monitoring', 'Deterministic integer fixed-point electrical metering',
    '{"e_tot_wh": {"type": "integer", "readable": true, "writable": false, "unit": "Wh"}, "p_mw": {"type": "integer", "readable": true, "writable": false, "unit": "mW"}}'::jsonb,
    '[]'::jsonb,
    '["energy.threshold_exceeded"]'::jsonb,
    '["v_mv", "i_ma", "p_mw", "e_tot_wh", "e_int_mwh", "freq_mhz", "pf_x1000"]'::jsonb,
    'EHEnergyCard',
    '["energy.threshold_exceeded"]'::jsonb,
    '[]'::jsonb
),
(
    'voltage', 1, 'AC Line Voltage', 'RMS AC voltage monitoring',
    '{"v_mv": {"type": "integer", "readable": true, "writable": false, "unit": "mV"}}'::jsonb,
    '[]'::jsonb,
    '["voltage.surge", "voltage.brownout"]'::jsonb,
    '["v_mv"]'::jsonb,
    'EHVoltageBadge',
    '["voltage.surge", "voltage.brownout"]'::jsonb,
    '[]'::jsonb
),
(
    'current', 1, 'Current Meter', 'RMS load current monitoring',
    '{"i_ma": {"type": "integer", "readable": true, "writable": false, "unit": "mA"}}'::jsonb,
    '[]'::jsonb,
    '["current.overcurrent"]'::jsonb,
    '["i_ma"]'::jsonb,
    'EHCurrentBadge',
    '["current.overcurrent"]'::jsonb,
    '[]'::jsonb
),
(
    'power', 1, 'Active Power', 'Real-time active power draw',
    '{"p_mw": {"type": "integer", "readable": true, "writable": false, "unit": "mW"}}'::jsonb,
    '[]'::jsonb,
    '["power.peak"]'::jsonb,
    '["p_mw"]'::jsonb,
    'EHPowerBadge',
    '["power.peak"]'::jsonb,
    '[]'::jsonb
),
(
    'fan_speed', 1, 'Fan Speed Control', 'Multi-step capacitive fan speed regulator',
    '{"speed": {"type": "integer", "readable": true, "writable": true, "minimum": 0, "maximum": 5}}'::jsonb,
    '[{"action": "setSpeed", "params": {"speed": {"type": "integer", "minimum": 0, "maximum": 5}}}, {"action": "stepUp"}, {"action": "stepDown"}]'::jsonb,
    '["fan.speed_changed"]'::jsonb,
    '[]'::jsonb,
    'EHFanSpeedDial',
    '["fan.speed_changed"]'::jsonb,
    '["setSpeed", "stepUp", "stepDown"]'::jsonb
),
(
    'ota', 1, 'Over-The-Air Firmware Updates', 'Dual-partition signed OTA update support',
    '{"firmwareVersion": {"type": "string", "readable": true, "writable": false}}'::jsonb,
    '[{"action": "startOTA", "params": {"manifestUrl": {"type": "string"}}}]'::jsonb,
    '["ota.progress", "ota.success", "ota.failed"]'::jsonb,
    '[]'::jsonb,
    'EHOTAStatusBadge',
    '["ota.success", "ota.failed"]'::jsonb,
    '[]'::jsonb
),
(
    'automation', 1, 'Local Automation Target', 'Participates in trigger-action rules',
    '{}'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    'EHAutomationBadge',
    '[]'::jsonb,
    '[]'::jsonb
)
ON CONFLICT (capability_id) DO NOTHING;
