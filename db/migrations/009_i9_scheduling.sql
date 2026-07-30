\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    required_column RECORD;
BEGIN
    FOR required_column IN
        SELECT *
        FROM (VALUES
            ('clients','id'), ('clients','code'), ('clients','name'), ('clients','status'),
            ('service_projects','id'), ('service_projects','client_id'), ('service_projects','code'), ('service_projects','name'), ('service_projects','effective_from'), ('service_projects','effective_to'), ('service_projects','status'),
            ('shift_templates','id'), ('shift_templates','code'), ('shift_templates','name'), ('shift_templates','version'), ('shift_templates','effective_from'), ('shift_templates','effective_to'), ('shift_templates','mandatory_by_default'), ('shift_templates','status'),
            ('shift_template_steps','id'), ('shift_template_steps','template_id'), ('shift_template_steps','step_order'), ('shift_template_steps','shift_code'),
            ('position_coverage_rules','id'), ('position_coverage_rules','position_id'), ('position_coverage_rules','template_id'), ('position_coverage_rules','required_quantity'), ('position_coverage_rules','effective_from'), ('position_coverage_rules','effective_to'), ('position_coverage_rules','status'),
            ('scheduling_rules','id'), ('scheduling_rules','source_level'), ('scheduling_rules','scope_type'), ('scheduling_rules','scope_id'), ('scheduling_rules','severity'), ('scheduling_rules','effective_from'), ('scheduling_rules','effective_to'), ('scheduling_rules','parameters'), ('scheduling_rules','status'),
            ('employee_availability_exceptions','id'), ('employee_availability_exceptions','employee_id'), ('employee_availability_exceptions','starts_at'), ('employee_availability_exceptions','ends_at'), ('employee_availability_exceptions','reason'), ('employee_availability_exceptions','created_by'), ('employee_availability_exceptions','status')
        ) AS expected(table_name, column_name)
    LOOP
        IF to_regclass(required_column.table_name) IS NOT NULL
           AND NOT EXISTS (
               SELECT 1
               FROM information_schema.columns c
               WHERE c.table_schema = current_schema()
                 AND c.table_name = required_column.table_name
                 AND c.column_name = required_column.column_name
           ) THEN
            RAISE EXCEPTION 'I9_PARTIAL_SCHEMA_INCOMPATIBLE: missing %.%; repair and backfill the partial table before rerunning 009_i9_scheduling.sql',
                required_column.table_name, required_column.column_name;
        END IF;
    END LOOP;
END
$$;

CREATE TABLE IF NOT EXISTS clients (
    id          BIGSERIAL PRIMARY KEY,
    code        VARCHAR(50) NOT NULL UNIQUE,
    name        VARCHAR(180) NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'ACTIVO' CHECK (status IN ('ACTIVO', 'INACTIVO')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_clients_code_not_blank CHECK (length(btrim(code)) > 0),
    CONSTRAINT ck_clients_name_not_blank CHECK (length(btrim(name)) > 0)
);

CREATE TABLE IF NOT EXISTS service_projects (
    id              BIGSERIAL PRIMARY KEY,
    client_id       BIGINT NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
    code            VARCHAR(50) NOT NULL UNIQUE,
    name            VARCHAR(180) NOT NULL,
    effective_from  DATE NOT NULL,
    effective_to    DATE,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVO' CHECK (status IN ('ACTIVO', 'INACTIVO')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_service_projects_code_not_blank CHECK (length(btrim(code)) > 0),
    CONSTRAINT ck_service_projects_name_not_blank CHECK (length(btrim(name)) > 0),
    CONSTRAINT ck_service_projects_dates CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

ALTER TABLE service_positions
    ADD COLUMN IF NOT EXISTS project_id BIGINT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_service_positions_project'
          AND conrelid = 'service_positions'::regclass
    ) THEN
        ALTER TABLE service_positions
            ADD CONSTRAINT fk_service_positions_project
            FOREIGN KEY (project_id) REFERENCES service_projects(id) ON DELETE RESTRICT;
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS shift_templates (
    id                      BIGSERIAL PRIMARY KEY,
    code                    VARCHAR(50) NOT NULL,
    name                    VARCHAR(180) NOT NULL,
    version                 INTEGER NOT NULL CHECK (version > 0),
    effective_from          DATE NOT NULL,
    effective_to            DATE,
    mandatory_by_default    BOOLEAN NOT NULL DEFAULT TRUE,
    status                  VARCHAR(20) NOT NULL DEFAULT 'ACTIVO' CHECK (status IN ('ACTIVO', 'INACTIVO')),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_shift_templates_code_version UNIQUE (code, version),
    CONSTRAINT ck_shift_templates_code_not_blank CHECK (length(btrim(code)) > 0),
    CONSTRAINT ck_shift_templates_name_not_blank CHECK (length(btrim(name)) > 0),
    CONSTRAINT ck_shift_templates_dates CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE TABLE IF NOT EXISTS shift_template_steps (
    id          BIGSERIAL PRIMARY KEY,
    template_id BIGINT NOT NULL REFERENCES shift_templates(id) ON DELETE RESTRICT,
    step_order  INTEGER NOT NULL CHECK (step_order > 0),
    shift_code  CHAR(1) NOT NULL CHECK (shift_code IN ('D', 'N', 'X')),
    CONSTRAINT uq_shift_template_steps_order UNIQUE (template_id, step_order)
);

ALTER TABLE shift_templates
    ALTER COLUMN mandatory_by_default SET DEFAULT TRUE;

ALTER TABLE shift_template_steps
    DROP CONSTRAINT IF EXISTS shift_template_steps_template_id_fkey;

ALTER TABLE shift_template_steps
    ADD CONSTRAINT shift_template_steps_template_id_fkey
    FOREIGN KEY (template_id) REFERENCES shift_templates(id) ON DELETE RESTRICT;

CREATE TABLE IF NOT EXISTS position_coverage_rules (
    id                  BIGSERIAL PRIMARY KEY,
    position_id         BIGINT NOT NULL REFERENCES service_positions(id) ON DELETE RESTRICT,
    template_id         BIGINT NOT NULL REFERENCES shift_templates(id) ON DELETE RESTRICT,
    required_quantity   INTEGER NOT NULL CHECK (required_quantity > 0),
    effective_from      DATE NOT NULL,
    effective_to        DATE,
    status              VARCHAR(20) NOT NULL DEFAULT 'ACTIVO' CHECK (status IN ('ACTIVO', 'INACTIVO')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_position_coverage_rules_dates CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT uq_position_coverage_rules_period UNIQUE (position_id, template_id, effective_from)
);

CREATE TABLE IF NOT EXISTS scheduling_rules (
    id              BIGSERIAL PRIMARY KEY,
    source_level    VARCHAR(50) NOT NULL,
    scope_type      VARCHAR(50) NOT NULL,
    scope_id        BIGINT,
    severity        VARCHAR(30) NOT NULL,
    effective_from  DATE NOT NULL,
    effective_to    DATE,
    parameters      JSONB NOT NULL DEFAULT '{}'::jsonb,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVO' CHECK (status IN ('ACTIVO', 'INACTIVO')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_scheduling_rules_source_not_blank CHECK (length(btrim(source_level)) > 0),
    CONSTRAINT ck_scheduling_rules_scope_not_blank CHECK (length(btrim(scope_type)) > 0),
    CONSTRAINT ck_scheduling_rules_severity_not_blank CHECK (length(btrim(severity)) > 0),
    CONSTRAINT ck_scheduling_rules_dates CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT ck_scheduling_rules_parameters_object CHECK (jsonb_typeof(parameters) = 'object')
);

CREATE TABLE IF NOT EXISTS employee_availability_exceptions (
    id          BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    starts_at   TIMESTAMPTZ NOT NULL,
    ends_at     TIMESTAMPTZ NOT NULL,
    reason      VARCHAR(500) NOT NULL,
    created_by  VARCHAR(80) NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'ACTIVO' CHECK (status IN ('ACTIVO', 'INACTIVO')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_employee_availability_exception_range CHECK (ends_at > starts_at),
    CONSTRAINT ck_employee_availability_exception_reason CHECK (length(btrim(reason)) > 0),
    CONSTRAINT ck_employee_availability_exception_created_by CHECK (length(btrim(created_by)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_service_projects_client_status
    ON service_projects (client_id, status);
CREATE INDEX IF NOT EXISTS idx_service_positions_project
    ON service_positions (project_id);
CREATE INDEX IF NOT EXISTS idx_shift_templates_status_dates
    ON shift_templates (status, effective_from, effective_to);
CREATE INDEX IF NOT EXISTS idx_position_coverage_rules_position_dates
    ON position_coverage_rules (position_id, effective_from, effective_to);
CREATE INDEX IF NOT EXISTS idx_scheduling_rules_scope_dates
    ON scheduling_rules (scope_type, scope_id, effective_from, effective_to);
CREATE INDEX IF NOT EXISTS idx_employee_availability_employee_dates
    ON employee_availability_exceptions (employee_id, starts_at, ends_at);

DO $$
DECLARE
    required_column RECORD;
    required_constraint TEXT;
    required_index TEXT;
BEGIN
    FOR required_column IN
        SELECT *
        FROM (VALUES
            ('clients','id'), ('clients','code'), ('clients','name'), ('clients','status'),
            ('service_projects','id'), ('service_projects','client_id'), ('service_projects','code'), ('service_projects','name'), ('service_projects','effective_from'), ('service_projects','effective_to'), ('service_projects','status'),
            ('service_positions','project_id'),
            ('shift_templates','id'), ('shift_templates','code'), ('shift_templates','name'), ('shift_templates','version'), ('shift_templates','effective_from'), ('shift_templates','effective_to'), ('shift_templates','mandatory_by_default'), ('shift_templates','status'),
            ('shift_template_steps','id'), ('shift_template_steps','template_id'), ('shift_template_steps','step_order'), ('shift_template_steps','shift_code'),
            ('position_coverage_rules','id'), ('position_coverage_rules','position_id'), ('position_coverage_rules','template_id'), ('position_coverage_rules','required_quantity'), ('position_coverage_rules','effective_from'), ('position_coverage_rules','effective_to'), ('position_coverage_rules','status'),
            ('scheduling_rules','id'), ('scheduling_rules','source_level'), ('scheduling_rules','scope_type'), ('scheduling_rules','scope_id'), ('scheduling_rules','severity'), ('scheduling_rules','effective_from'), ('scheduling_rules','effective_to'), ('scheduling_rules','parameters'), ('scheduling_rules','status'),
            ('employee_availability_exceptions','id'), ('employee_availability_exceptions','employee_id'), ('employee_availability_exceptions','starts_at'), ('employee_availability_exceptions','ends_at'), ('employee_availability_exceptions','reason'), ('employee_availability_exceptions','created_by'), ('employee_availability_exceptions','status')
        ) AS expected(table_name, column_name)
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns c
            WHERE c.table_schema = current_schema()
              AND c.table_name = required_column.table_name
              AND c.column_name = required_column.column_name
        ) THEN
            RAISE EXCEPTION 'I9 partial installation is incompatible: missing %.%. Add/backfill the column before rerunning 009_i9_scheduling.sql.',
                required_column.table_name, required_column.column_name;
        END IF;
    END LOOP;

    FOREACH required_constraint IN ARRAY ARRAY[
        'clients_code_key',
        'clients_status_check',
        'service_projects_client_id_fkey',
        'service_projects_code_key',
        'service_projects_status_check',
        'fk_service_positions_project',
        'uq_shift_templates_code_version',
        'shift_templates_status_check',
        'uq_shift_template_steps_order',
        'shift_template_steps_template_id_fkey',
        'shift_template_steps_shift_code_check',
        'uq_position_coverage_rules_period',
        'position_coverage_rules_position_id_fkey',
        'position_coverage_rules_template_id_fkey',
        'position_coverage_rules_required_quantity_check',
        'ck_position_coverage_rules_dates',
        'scheduling_rules_status_check',
        'ck_scheduling_rules_dates',
        'ck_scheduling_rules_parameters_object',
        'employee_availability_exceptions_employee_id_fkey',
        'employee_availability_exceptions_status_check',
        'ck_employee_availability_exception_range'
    ]
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE connamespace = current_schema()::regnamespace
              AND conname = required_constraint
        ) THEN
            RAISE EXCEPTION 'I9 partial installation is incompatible: missing constraint %. Repair the partial schema before rerunning 009_i9_scheduling.sql.',
                required_constraint;
        END IF;
    END LOOP;

    FOREACH required_index IN ARRAY ARRAY[
        'idx_service_projects_client_status',
        'idx_service_positions_project',
        'idx_shift_templates_status_dates',
        'idx_position_coverage_rules_position_dates',
        'idx_scheduling_rules_scope_dates',
        'idx_employee_availability_employee_dates'
    ]
    LOOP
        IF to_regclass(required_index) IS NULL THEN
            RAISE EXCEPTION 'I9 partial installation is incompatible: missing index %.', required_index;
        END IF;
    END LOOP;
END
$$;

COMMIT;
