-- Migration: 031_firmware_git_binary_management.sql
-- Description: EH Home Firmware Families, Builds, Artifacts, and Hardware Compatibility
-- Domain: Firmware, Git & Binary Management (Part 07)

CREATE TABLE IF NOT EXISTS firmware_families (
    id VARCHAR(64) PRIMARY KEY,
    display_name VARCHAR(128) NOT NULL,
    target_mcu VARCHAR(32) NOT NULL DEFAULT 'esp32-c6',
    default_idf_version VARCHAR(32) NOT NULL DEFAULT 'v5.4.1',
    repository_url TEXT,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_firmware_family_mcu CHECK (
        target_mcu IN ('esp32-c6', 'esp32-s3', 'esp32', 'esp32-c3')
    )
);

CREATE INDEX IF NOT EXISTS idx_firmware_families_mcu ON firmware_families(target_mcu);

CREATE TABLE IF NOT EXISTS firmware_builds (
    id VARCHAR(64) PRIMARY KEY,
    firmware_release_id TEXT REFERENCES firmware_releases(id) ON DELETE SET NULL,
    firmware_family_id VARCHAR(64) NOT NULL REFERENCES firmware_families(id) ON DELETE RESTRICT,
    git_commit_sha VARCHAR(40) NOT NULL,
    git_branch VARCHAR(128) NOT NULL DEFAULT 'main',
    git_tag VARCHAR(128),
    idf_version VARCHAR(32) NOT NULL DEFAULT 'v5.4.1',
    build_profile VARCHAR(32) NOT NULL DEFAULT 'release',
    toolchain_info JSONB NOT NULL DEFAULT '{}'::jsonb,
    built_by VARCHAR(128),
    built_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_git_commit_sha CHECK (git_commit_sha ~ '^[0-9a-fA-F]{40}$'),
    CONSTRAINT chk_build_profile CHECK (build_profile IN ('release', 'debug', 'profiling'))
);

CREATE INDEX IF NOT EXISTS idx_firmware_builds_release ON firmware_builds(firmware_release_id);
CREATE INDEX IF NOT EXISTS idx_firmware_builds_family ON firmware_builds(firmware_family_id);
CREATE INDEX IF NOT EXISTS idx_firmware_builds_commit ON firmware_builds(git_commit_sha);

CREATE TABLE IF NOT EXISTS firmware_artifacts (
    id VARCHAR(64) PRIMARY KEY,
    build_id VARCHAR(64) NOT NULL REFERENCES firmware_builds(id) ON DELETE CASCADE,
    artifact_type VARCHAR(32) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_size_bytes INTEGER NOT NULL CHECK (file_size_bytes > 0),
    sha256 VARCHAR(64) NOT NULL,
    storage_path TEXT NOT NULL,
    download_url TEXT,
    signature TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_firmware_artifacts_build_type UNIQUE (build_id, artifact_type),
    CONSTRAINT chk_firmware_artifacts_sha256 CHECK (sha256 ~ '^[0-9a-fA-F]{64}$'),
    CONSTRAINT chk_artifact_type CHECK (
        artifact_type IN ('APP_BIN', 'BOOTLOADER', 'PARTITION_TABLE', 'ELF', 'MAP', 'FACTORY_NVS')
    )
);

CREATE INDEX IF NOT EXISTS idx_firmware_artifacts_build ON firmware_artifacts(build_id);
CREATE INDEX IF NOT EXISTS idx_firmware_artifacts_sha256 ON firmware_artifacts(sha256);

CREATE TABLE IF NOT EXISTS firmware_hardware_compatibility (
    id VARCHAR(64) PRIMARY KEY,
    firmware_release_id TEXT NOT NULL REFERENCES firmware_releases(id) ON DELETE CASCADE,
    hardware_revision_id VARCHAR(64) NOT NULL REFERENCES hardware_revisions(id) ON DELETE RESTRICT,
    min_hardware_revision VARCHAR(32),
    max_hardware_revision VARCHAR(32),
    is_verified BOOLEAN NOT NULL DEFAULT TRUE,
    verification_notes TEXT,
    verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_firmware_hw_compat UNIQUE (firmware_release_id, hardware_revision_id)
);

CREATE INDEX IF NOT EXISTS idx_firmware_hw_compat_release ON firmware_hardware_compatibility(firmware_release_id);
CREATE INDEX IF NOT EXISTS idx_firmware_hw_compat_hw_rev ON firmware_hardware_compatibility(hardware_revision_id);
