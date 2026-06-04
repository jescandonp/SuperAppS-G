\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE IF NOT EXISTS employees (
    id                              BIGSERIAL PRIMARY KEY,
    identification_type             VARCHAR(10) NOT NULL DEFAULT 'CC' CHECK (identification_type IN ('CC', 'CE')),
    identification_number           VARCHAR(30) NOT NULL UNIQUE,
    full_name                       VARCHAR(180) NOT NULL,
    employment_status               VARCHAR(20) NOT NULL CHECK (employment_status IN ('ACTIVO', 'RETIRADO')),
    job_title                       VARCHAR(120) NOT NULL,
    hire_date                       DATE,
    termination_date                DATE,
    termination_reason              VARCHAR(180),
    contract_type                   VARCHAR(80),
    current_service_position_text   VARCHAR(180),
    notes                           TEXT,
    record_status                   VARCHAR(20) NOT NULL DEFAULT 'ACTIVO' CHECK (record_status IN ('ACTIVO', 'INCOMPLETO', 'INACTIVO')),
    source                          VARCHAR(40) NOT NULL DEFAULT 'MANUAL',
    created_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_employees_dates CHECK (
        (employment_status = 'ACTIVO' AND hire_date IS NOT NULL)
        OR (employment_status = 'RETIRADO' AND hire_date IS NOT NULL AND termination_date IS NOT NULL)
    ),
    CONSTRAINT ck_employees_retirement_order CHECK (
        termination_date IS NULL OR hire_date IS NULL OR termination_date >= hire_date
    )
);

CREATE TABLE IF NOT EXISTS employee_salary_history (
    id                  BIGSERIAL PRIMARY KEY,
    employee_id         BIGINT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    base_salary_amount  NUMERIC(14, 2) NOT NULL CHECK (base_salary_amount >= 0),
    effective_from      DATE NOT NULL,
    effective_to        DATE,
    source              VARCHAR(40) NOT NULL DEFAULT 'MANUAL',
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_employee_salary_range CHECK (
        effective_to IS NULL OR effective_to >= effective_from
    )
);

CREATE TABLE IF NOT EXISTS import_batches (
    id                  BIGSERIAL PRIMARY KEY,
    load_type           VARCHAR(40) NOT NULL,
    file_name           VARCHAR(255) NOT NULL,
    uploaded_by         VARCHAR(80) NOT NULL,
    status              VARCHAR(20) NOT NULL CHECK (status IN ('PREVALIDADA', 'IMPORTADA', 'RECHAZADA', 'CON_ERRORES')),
    total_records       INTEGER NOT NULL DEFAULT 0,
    valid_records       INTEGER NOT NULL DEFAULT 0,
    incomplete_records  INTEGER NOT NULL DEFAULT 0,
    duplicate_records   INTEGER NOT NULL DEFAULT 0,
    invalid_records     INTEGER NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    imported_at         TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS import_batch_errors (
    id                  BIGSERIAL PRIMARY KEY,
    import_batch_id     BIGINT NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
    row_number          INTEGER NOT NULL,
    field_name          VARCHAR(80) NOT NULL,
    error_type          VARCHAR(30) NOT NULL CHECK (error_type IN ('INCOMPLETO', 'DUPLICADO', 'FORMATO_INVALIDO', 'VALOR_NO_RECONOCIDO')),
    message             TEXT NOT NULL,
    original_value      TEXT
);

CREATE TABLE IF NOT EXISTS employee_change_log (
    id                  BIGSERIAL PRIMARY KEY,
    employee_id         BIGINT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    actor_username      VARCHAR(80) NOT NULL,
    field_name          VARCHAR(80) NOT NULL,
    previous_value      TEXT,
    new_value           TEXT,
    changed_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_employees_identification_number ON employees (identification_number);
CREATE INDEX IF NOT EXISTS idx_employees_employment_status ON employees (employment_status);
CREATE INDEX IF NOT EXISTS idx_employees_job_title ON employees (job_title);
CREATE INDEX IF NOT EXISTS idx_employee_salary_history_employee_id ON employee_salary_history (employee_id, effective_from DESC);
CREATE INDEX IF NOT EXISTS idx_import_batches_status ON import_batches (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_import_batch_errors_import_batch_id ON import_batch_errors (import_batch_id);
CREATE INDEX IF NOT EXISTS idx_employee_change_log_employee_id ON employee_change_log (employee_id, changed_at DESC);

COMMIT;
