-- ==========================================================
-- EH Home Migration 004: Seed Missing 4 Canonical Capabilities
-- Brings database seed in sync with canonical capability-registry.json (14 total)
-- Missing from 003: brightness, cct, scene, schedule
-- ==========================================================

INSERT INTO capabilities (capability_id, version, display_name, description, properties, commands, events, telemetry_fields, ui_component_hint, automation_triggers, automation_actions)
VALUES
(
    'brightness', 1, 'Brightness Dimmer', 'Continuous phase-cut or PWM dimming level',
    '{"level": {"type": "integer", "readable": true, "writable": true, "minimum": 0, "maximum": 100}}'::jsonb,
    '[{"action": "setLevel", "params": {"level": {"type": "integer", "minimum": 0, "maximum": 100}}}]'::jsonb,
    '["dimmer.level_changed"]'::jsonb,
    '[]'::jsonb,
    'EHDimmerSlider',
    '["dimmer.level_changed"]'::jsonb,
    '["setLevel"]'::jsonb
),
(
    'cct', 1, 'Correlated Color Temperature', 'Tunable white lighting control',
    '{"tempK": {"type": "integer", "readable": true, "writable": true, "minimum": 2700, "maximum": 6500}}'::jsonb,
    '[{"action": "setColorTemp", "params": {"tempK": {"type": "integer", "minimum": 2700, "maximum": 6500}}}]'::jsonb,
    '["cct.temp_changed"]'::jsonb,
    '[]'::jsonb,
    'EHCCTDial',
    '["cct.temp_changed"]'::jsonb,
    '["setColorTemp"]'::jsonb
),
(
    'scene', 1, 'Scene Preset Target', 'Supports saving and activating channel scenes',
    '{}'::jsonb,
    '[{"action": "applyScene", "params": {"sceneId": {"type": "string"}}}]'::jsonb,
    '["scene.applied"]'::jsonb,
    '[]'::jsonb,
    'EHSceneButton',
    '["scene.applied"]'::jsonb,
    '["applyScene"]'::jsonb
),
(
    'schedule', 1, 'On-Device Scheduler', 'Device RTC-backed local schedule execution',
    '{"scheduleCount": {"type": "integer", "readable": true, "writable": false}}'::jsonb,
    '[{"action": "setSchedule", "params": {"schedule": {"type": "object"}}}]'::jsonb,
    '["schedule.triggered"]'::jsonb,
    '[]'::jsonb,
    'EHScheduleManager',
    '["schedule.triggered"]'::jsonb,
    '["setSchedule"]'::jsonb
)
ON CONFLICT (capability_id) DO NOTHING;
