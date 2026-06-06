\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE IF NOT EXISTS training_requirement_types (
    id                  BIGSERIAL PRIMARY KEY,
    code                VARCHAR(50) UNIQUE,
    name                VARCHAR(160) NOT NULL,
    category            VARCHAR(20) NOT NULL CHECK (category IN ('CURSO', 'ACREDITACION')),
    validity_days       INTEGER CHECK (validity_days IS NULL OR validity_days > 0),
    is_service_required BOOLEAN NOT NULL DEFAULT TRUE,
    status              VARCHAR(20) NOT NULL DEFAULT 'ACTIVO' CHECK (status IN ('ACTIVO', 'INACTIVO')),
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_training_requirement_types_code_not_blank CHECK (code IS NULL OR length(btrim(code)) > 0),
    CONSTRAINT ck_training_requirement_types_name_not_blank CHECK (length(btrim(name)) > 0)
);

CREATE TABLE IF NOT EXISTS employee_training_records (
    id                      BIGSERIAL PRIMARY KEY,
    employee_id             BIGINT NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    requirement_type_id     BIGINT NOT NULL REFERENCES training_requirement_types(id) ON DELETE RESTRICT,
    completed_at            DATE NOT NULL,
    expires_at              DATE NOT NULL,
    support_path            VARCHAR(500),
    notes                   TEXT,
    status                  VARCHAR(20) NOT NULL DEFAULT 'ACTIVO' CHECK (status IN ('ACTIVO', 'INACTIVO')),
    created_by              VARCHAR(80) NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_employee_training_records_dates CHECK (expires_at >= completed_at),
    CONSTRAINT ck_employee_training_records_created_by_not_blank CHECK (length(btrim(created_by)) > 0),
    CONSTRAINT ck_employee_training_records_support_not_blank CHECK (support_path IS NULL OR length(btrim(support_path)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_training_requirement_types_status_category
    ON training_requirement_types (status, category, name);

CREATE INDEX IF NOT EXISTS idx_employee_training_records_employee
    ON employee_training_records (employee_id, requirement_type_id, expires_at DESC);

CREATE INDEX IF NOT EXISTS idx_employee_training_records_type
    ON employee_training_records (requirement_type_id, status, expires_at DESC);

CREATE INDEX IF NOT EXISTS idx_employee_training_records_expiry
    ON employee_training_records (status, expires_at);

COMMIT;
