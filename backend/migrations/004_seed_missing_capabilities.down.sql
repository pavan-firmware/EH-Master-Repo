-- ==========================================================
-- EH Home Migration 004 Down: Revert 4 Canonical Capabilities
-- ==========================================================

DELETE FROM capabilities WHERE capability_id IN ('brightness', 'cct', 'scene', 'schedule');
