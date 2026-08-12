\set ON_ERROR_STOP on
BEGIN;

CREATE TABLE IF NOT EXISTS schedules (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL REFERENCES service_projects(id) ON DELETE RESTRICT,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    created_by VARCHAR(80) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT schedules_period_check CHECK (period_end >= period_start),
    CONSTRAINT schedules_project_period_unique UNIQUE (project_id, period_start, period_end)
);

CREATE TABLE IF NOT EXISTS schedule_versions (
    id BIGSERIAL PRIMARY KEY,
    schedule_id BIGINT NOT NULL REFERENCES schedules(id) ON DELETE RESTRICT,
    version_number INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'BORRADOR',
    source_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    rules_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    parameters_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    coverage_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
    vacancy_count INTEGER NOT NULL DEFAULT 0,
    exception_count INTEGER NOT NULL DEFAULT 0,
    created_by VARCHAR(80) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    approved_by VARCHAR(80),
    approved_at TIMESTAMPTZ,
    published_by VARCHAR(80),
    published_at TIMESTAMPTZ,
    CONSTRAINT schedule_versions_number_check CHECK (version_number > 0),
    CONSTRAINT schedule_versions_status_check CHECK (status IN ('BORRADOR','PROPUESTA','APROBADA','PUBLICADA','REEMPLAZADA','CANCELADA')),
    CONSTRAINT schedule_versions_snapshots_check CHECK (
        jsonb_typeof(source_snapshot) = 'object'
        AND jsonb_typeof(rules_snapshot) = 'object'
        AND jsonb_typeof(parameters_snapshot) = 'object'
    ),
    CONSTRAINT schedule_versions_metrics_check CHECK (
        coverage_percent BETWEEN 0 AND 100
        AND vacancy_count >= 0
        AND exception_count >= 0
    ),
    CONSTRAINT schedule_versions_approval_check CHECK (
        (approved_by IS NULL AND approved_at IS NULL)
        OR (approved_by IS NOT NULL AND approved_at IS NOT NULL)
    ),
    CONSTRAINT schedule_versions_publication_check CHECK (
        (published_by IS NULL AND published_at IS NULL)
        OR (published_by IS NOT NULL AND published_at IS NOT NULL)
    ),
    CONSTRAINT schedule_versions_schedule_number_unique UNIQUE (schedule_id, version_number)
);

CREATE UNIQUE INDEX IF NOT EXISTS schedule_versions_one_published_per_schedule
    ON schedule_versions(schedule_id)
    WHERE status = 'PUBLICADA';

CREATE TABLE IF NOT EXISTS required_shifts (
    id BIGSERIAL PRIMARY KEY,
    schedule_version_id BIGINT NOT NULL REFERENCES schedule_versions(id) ON DELETE CASCADE,
    position_id BIGINT NOT NULL REFERENCES service_positions(id) ON DELETE RESTRICT,
    shift_date DATE NOT NULL,
    starts_at TIME NOT NULL,
    ends_at TIME NOT NULL,
    required_quantity INTEGER NOT NULL DEFAULT 1,
    source_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT required_shifts_quantity_check CHECK (required_quantity > 0),
    CONSTRAINT required_shifts_source_snapshot_check CHECK (jsonb_typeof(source_snapshot) = 'object'),
    CONSTRAINT required_shifts_natural_key UNIQUE (schedule_version_id, position_id, shift_date, starts_at, ends_at)
);

CREATE TABLE IF NOT EXISTS schedule_assignments (
    id BIGSERIAL PRIMARY KEY,
    schedule_version_id BIGINT NOT NULL REFERENCES schedule_versions(id) ON DELETE CASCADE,
    required_shift_id BIGINT NOT NULL REFERENCES required_shifts(id) ON DELETE CASCADE,
    employee_id BIGINT REFERENCES employees(id) ON DELETE RESTRICT,
    status VARCHAR(20) NOT NULL,
    score NUMERIC(12,4),
    reasons JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT schedule_assignments_status_check CHECK (status IN ('ASIGNADA','VACANTE')),
    CONSTRAINT schedule_assignments_employee_status_check CHECK (
        (status = 'VACANTE' AND employee_id IS NULL)
        OR (status = 'ASIGNADA' AND employee_id IS NOT NULL)
    ),
    CONSTRAINT schedule_assignments_reasons_check CHECK (jsonb_typeof(reasons) = 'array'),
    CONSTRAINT schedule_assignments_employee_unique UNIQUE (schedule_version_id, required_shift_id, employee_id)
);

CREATE TABLE IF NOT EXISTS schedule_exceptions (
    id BIGSERIAL PRIMARY KEY,
    schedule_version_id BIGINT NOT NULL REFERENCES schedule_versions(id) ON DELETE CASCADE,
    assignment_id BIGINT REFERENCES schedule_assignments(id) ON DELETE RESTRICT,
    exception_type VARCHAR(50) NOT NULL,
    reason VARCHAR(500) NOT NULL,
    responsible VARCHAR(80) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'REGISTRADA',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT schedule_exceptions_text_check CHECK (
        btrim(exception_type) <> '' AND btrim(reason) <> '' AND btrim(responsible) <> ''
    ),
    CONSTRAINT schedule_exceptions_status_check CHECK (status IN ('REGISTRADA','APROBADA','RECHAZADA','CANCELADA'))
);

CREATE TABLE IF NOT EXISTS schedule_generation_runs (
    id BIGSERIAL PRIMARY KEY,
    schedule_version_id BIGINT NOT NULL REFERENCES schedule_versions(id) ON DELETE CASCADE,
    idempotency_key VARCHAR(120) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'EN_COLA',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_message VARCHAR(1000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT schedule_generation_runs_status_check CHECK (status IN ('EN_COLA','PROCESANDO','COMPLETADO','COMPLETADO_CON_VACANTES','FALLIDO')),
    CONSTRAINT schedule_generation_runs_idempotency_unique UNIQUE (idempotency_key)
);

CREATE OR REPLACE FUNCTION reject_published_schedule_version_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.status = 'PUBLICADA' THEN
        RAISE EXCEPTION USING
            ERRCODE = '55000',
            MESSAGE = 'published schedule version is immutable';
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

DROP TRIGGER IF EXISTS schedule_versions_immutable_when_published ON schedule_versions;
CREATE TRIGGER schedule_versions_immutable_when_published
BEFORE UPDATE OR DELETE ON schedule_versions
FOR EACH ROW EXECUTE FUNCTION reject_published_schedule_version_change();

CREATE OR REPLACE FUNCTION reject_published_schedule_assignment_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM schedule_versions
        WHERE id = OLD.schedule_version_id AND status = 'PUBLICADA'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '55000',
            MESSAGE = 'published schedule version is immutable';
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

DROP TRIGGER IF EXISTS schedule_assignments_immutable_when_published ON schedule_assignments;
CREATE TRIGGER schedule_assignments_immutable_when_published
BEFORE UPDATE OR DELETE ON schedule_assignments
FOR EACH ROW EXECUTE FUNCTION reject_published_schedule_assignment_change();

COMMIT;
