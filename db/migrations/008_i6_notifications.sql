\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE notification_items
    ADD COLUMN IF NOT EXISTS severity VARCHAR(20) NOT NULL DEFAULT 'INFO',
    ADD COLUMN IF NOT EXISTS source_type VARCHAR(80) NOT NULL DEFAULT 'SYSTEM',
    ADD COLUMN IF NOT EXISTS source_id VARCHAR(120),
    ADD COLUMN IF NOT EXISTS dedupe_key VARCHAR(240),
    ADD COLUMN IF NOT EXISTS action_url VARCHAR(240),
    ADD COLUMN IF NOT EXISTS managed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS managed_by VARCHAR(80);

ALTER TABLE notification_items
    DROP CONSTRAINT IF EXISTS notification_items_status_check,
    DROP CONSTRAINT IF EXISTS ck_notification_items_target_type,
    DROP CONSTRAINT IF EXISTS ck_notification_items_status,
    DROP CONSTRAINT IF EXISTS ck_notification_items_severity,
    DROP CONSTRAINT IF EXISTS ck_notification_items_source_module;

ALTER TABLE notification_items
    ADD CONSTRAINT ck_notification_items_target_type
        CHECK (target_type IN ('USER', 'ROLE')),
    ADD CONSTRAINT ck_notification_items_status
        CHECK (status IN ('UNREAD', 'READ', 'ARCHIVED', 'DISMISSED')),
    ADD CONSTRAINT ck_notification_items_severity
        CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL')),
    ADD CONSTRAINT ck_notification_items_source_module
        CHECK (source_module IN ('IMPORTS', 'CERTIFICATES', 'TRAINING', 'SYSTEM'));

CREATE TABLE IF NOT EXISTS notification_events (
    id                  BIGSERIAL PRIMARY KEY,
    notification_id     BIGINT NOT NULL REFERENCES notification_items(id) ON DELETE CASCADE,
    actor_username      VARCHAR(80) NOT NULL,
    event_type          VARCHAR(40) NOT NULL CHECK (
        event_type IN (
            'CREATED',
            'READ',
            'ARCHIVED',
            'DISMISSED',
            'EXPORTED',
            'EMAIL_ATTEMPTED',
            'EMAIL_SENT',
            'EMAIL_FAILED'
        )
    ),
    detail              JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_notification_items_active_dedupe
    ON notification_items (dedupe_key)
    WHERE dedupe_key IS NOT NULL
      AND status IN ('UNREAD', 'READ');

CREATE INDEX IF NOT EXISTS idx_notification_items_target_status
    ON notification_items (target_type, target_key, status);

CREATE INDEX IF NOT EXISTS idx_notification_items_source
    ON notification_items (source_module, source_type, source_id);

CREATE INDEX IF NOT EXISTS idx_notification_items_severity
    ON notification_items (severity, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notification_events_notification
    ON notification_events (notification_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notification_events_type
    ON notification_events (event_type, created_at DESC);

COMMIT;
