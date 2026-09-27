-- Migration: 031_firmware_git_binary_management.down.sql
-- Description: Revert Firmware Families, Builds, Artifacts, and Hardware Compatibility
-- Domain: Firmware, Git & Binary Management (Part 07)

DROP TABLE IF EXISTS firmware_hardware_compatibility;
DROP TABLE IF EXISTS firmware_artifacts;
DROP TABLE IF EXISTS firmware_builds;
DROP TABLE IF EXISTS firmware_families;
