\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE IF NOT EXISTS app_sessions (
    id              BIGSERIAL PRIMARY KEY,
    token_hash      TEXT NOT NULL UNIQUE,
    user_id         BIGINT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_app_sessions_active
    ON app_sessions (token_hash, expires_at)
    WHERE revoked_at IS NULL;

COMMIT;
