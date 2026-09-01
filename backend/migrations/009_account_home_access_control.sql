-- ==============================================================================
-- EH Home Migration 009: Account, Home Access Control & Invitations (Phase 16)
-- ==============================================================================

-- 1. User Profiles & Account Metadata
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    full_name VARCHAR(128),
    phone_number VARCHAR(32),
    avatar_url TEXT,
    timezone VARCHAR(64) NOT NULL DEFAULT 'UTC',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_updated_at ON user_profiles(updated_at DESC);

-- 2. Home Invitations
CREATE TABLE IF NOT EXISTS home_invitations (
    id UUID PRIMARY KEY,
    home_id UUID NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    inviter_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitee_email VARCHAR(255) NOT NULL,
    role VARCHAR(32) NOT NULL CHECK (role IN ('ADMIN', 'MEMBER', 'GUEST', 'VIEWER')),
    invite_code VARCHAR(128) NOT NULL UNIQUE,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'REVOKED', 'EXPIRED')),
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_home_invitations_home_status ON home_invitations(home_id, status);
CREATE INDEX IF NOT EXISTS idx_home_invitations_email_status ON home_invitations(invitee_email, status);
CREATE INDEX IF NOT EXISTS idx_home_invitations_code ON home_invitations(invite_code);
