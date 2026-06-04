\set ON_ERROR_STOP on

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS roles (
    id              BIGSERIAL PRIMARY KEY,
    code            VARCHAR(50) NOT NULL UNIQUE,
    name            VARCHAR(100) NOT NULL,
    description     TEXT NOT NULL,
    is_system       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app_users (
    id                      BIGSERIAL PRIMARY KEY,
    full_name               VARCHAR(150) NOT NULL,
    username                VARCHAR(80) NOT NULL UNIQUE,
    password_hash           TEXT NOT NULL,
    email                   VARCHAR(150),
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at           TIMESTAMPTZ,
    password_changed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_roles (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    role_id         BIGINT NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    assigned_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, role_id)
);

CREATE TABLE IF NOT EXISTS role_permissions (
    id              BIGSERIAL PRIMARY KEY,
    role_id         BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    module_code     VARCHAR(80) NOT NULL,
    action_code     VARCHAR(40) NOT NULL,
    allowed         BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (role_id, module_code, action_code)
);

CREATE TABLE IF NOT EXISTS notification_items (
    id                  BIGSERIAL PRIMARY KEY,
    target_type         VARCHAR(20) NOT NULL CHECK (target_type IN ('USER', 'ROLE')),
    target_key          VARCHAR(80) NOT NULL,
    title               VARCHAR(180) NOT NULL,
    body                TEXT NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'UNREAD' CHECK (status IN ('UNREAD', 'READ', 'ARCHIVED')),
    source_module       VARCHAR(80) NOT NULL DEFAULT 'SYSTEM',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at             TIMESTAMPTZ,
    archived_at         TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS audit_log (
    id                  BIGSERIAL PRIMARY KEY,
    actor_user_id       BIGINT REFERENCES app_users(id) ON DELETE SET NULL,
    actor_username      VARCHAR(80),
    event_type          VARCHAR(80) NOT NULL,
    entity_type         VARCHAR(80) NOT NULL,
    entity_id           VARCHAR(80),
    result              VARCHAR(40) NOT NULL,
    detail              JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_users_username ON app_users (username);
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles (user_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id ON role_permissions (role_id);
CREATE INDEX IF NOT EXISTS idx_notification_items_target ON notification_items (target_type, target_key, status);
CREATE INDEX IF NOT EXISTS idx_audit_log_actor_user_id ON audit_log (actor_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_event_type ON audit_log (event_type);

COMMIT;

