\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE employees
    DROP CONSTRAINT IF EXISTS employees_identification_number_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_employees_functional_key
    ON employees (identification_type, identification_number);

CREATE UNIQUE INDEX IF NOT EXISTS uq_employee_salary_open_period
    ON employee_salary_history (employee_id)
    WHERE effective_to IS NULL;

ALTER TABLE import_batches
    DROP CONSTRAINT IF EXISTS import_batches_status_check;

ALTER TABLE import_batches
    ADD CONSTRAINT import_batches_status_check
    CHECK (status IN ('PREVALIDANDO', 'PREVALIDADA', 'CON_ERRORES', 'RECHAZADA', 'IMPORTADA', 'CANCELADA'));

CREATE TABLE IF NOT EXISTS import_column_mappings (
    id                  BIGSERIAL PRIMARY KEY,
    import_batch_id     BIGINT NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
    source_header       VARCHAR(180) NOT NULL,
    target_field        VARCHAR(80),
    mapping_status      VARCHAR(20) NOT NULL CHECK (mapping_status IN ('MAPPED', 'UNMAPPED', 'IGNORED')),
    source_position     INTEGER NOT NULL CHECK (source_position >= 0),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (import_batch_id, source_position)
);

CREATE TABLE IF NOT EXISTS import_batch_rows (
    id                      BIGSERIAL PRIMARY KEY,
    import_batch_id         BIGINT NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
    row_number              INTEGER NOT NULL CHECK (row_number >= 2),
    classification          VARCHAR(20) NOT NULL CHECK (classification IN ('VALIDO', 'INCOMPLETO', 'DUPLICADO', 'ERRONEO')),
    identification_type     VARCHAR(10) NOT NULL DEFAULT 'CC' CHECK (identification_type IN ('CC', 'CE')),
    identification_number   VARCHAR(30),
    normalized_payload      JSONB NOT NULL DEFAULT '{}'::jsonb,
    source_payload          JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (import_batch_id, row_number)
);

ALTER TABLE import_batch_rows
    DROP CONSTRAINT IF EXISTS import_batch_rows_identification_type_check;

ALTER TABLE import_batch_errors
    ADD COLUMN IF NOT EXISTS import_batch_row_id BIGINT REFERENCES import_batch_rows(id) ON DELETE CASCADE;

ALTER TABLE import_batch_errors
    DROP CONSTRAINT IF EXISTS import_batch_errors_error_type_check;

ALTER TABLE import_batch_errors
    ADD CONSTRAINT import_batch_errors_error_type_check
    CHECK (error_type IN ('INCOMPLETO', 'DUPLICADO', 'FORMATO_INVALIDO', 'VALOR_NO_RECONOCIDO', 'FECHA_INCONSISTENTE'));

CREATE INDEX IF NOT EXISTS idx_import_column_mappings_batch
    ON import_column_mappings (import_batch_id, source_position);

CREATE INDEX IF NOT EXISTS idx_import_batch_rows_batch_classification
    ON import_batch_rows (import_batch_id, classification, row_number);

CREATE INDEX IF NOT EXISTS idx_import_batch_rows_identification
    ON import_batch_rows (identification_type, identification_number);

COMMIT;
