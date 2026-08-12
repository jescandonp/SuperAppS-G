\set ON_ERROR_STOP on
BEGIN;
ALTER TABLE notification_items ADD COLUMN IF NOT EXISTS deduplication_key VARCHAR(180);
CREATE UNIQUE INDEX IF NOT EXISTS notification_items_deduplication_unique ON notification_items(deduplication_key) WHERE deduplication_key IS NOT NULL;
CREATE TABLE IF NOT EXISTS schedule_replanning_runs(
 id BIGSERIAL PRIMARY KEY,
 schedule_version_id BIGINT NOT NULL REFERENCES schedule_versions(id) ON DELETE RESTRICT,
 trigger_type VARCHAR(40) NOT NULL,
 trigger_id VARCHAR(120) NOT NULL,
 modes JSONB NOT NULL,
 result_snapshot JSONB NOT NULL,
 created_by VARCHAR(80) NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 CONSTRAINT schedule_replanning_modes_check CHECK(jsonb_typeof(modes)='array'),
 CONSTRAINT schedule_replanning_result_check CHECK(jsonb_typeof(result_snapshot)='object'),
 CONSTRAINT schedule_replanning_unique UNIQUE(schedule_version_id,trigger_type,trigger_id,modes)
);
COMMIT;
